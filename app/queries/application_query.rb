class ApplicationQuery
  # Raised for any sort/filter field not on the allowlist. Mapped to 400 by
  # ExceptionHandler — never interpolate an unrecognised field into SQL.
  class InvalidQueryParameter < StandardError; end

  class_attribute :filterable_fields,  default: {}
  class_attribute :sortable_fields,    default: [].freeze
  class_attribute :searchable_fields,  default: [].freeze
  class_attribute :default_sort,       default: { created_at: :desc }

  class << self
    def filterable(mapping)  = self.filterable_fields = mapping.symbolize_keys
    def sortable(*fields)    = self.sortable_fields   = fields.map(&:to_s).freeze
    def searchable(*fields)  = self.searchable_fields = fields.map(&:to_sym).freeze
    def sort_default(field, direction) = self.default_sort = { field.to_sym => direction.to_sym }

    def call(scope, params) = new(scope, params).call
  end

  def initialize(scope, params)
    @scope  = scope
    @params = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
  end

  def call
    s = apply_filters(@scope)
    s = apply_search(s)
    apply_sort(s)
  end

  private

  attr_reader :params

  def filters = (params[:filter] || params["filter"] || {}).to_h.symbolize_keys

  def apply_filters(scope)
    filters.reduce(scope) do |acc, (key, value)|
      next acc if value.blank?

      # Date-range suffixes map back to a declared date_range field.
      base, bound = split_range_key(key)
      type = filterable_fields[base]
      raise InvalidQueryParameter, "Unknown filter field: #{key}" if type.nil?
      raise InvalidQueryParameter, "Unknown filter field: #{key}" if bound && type != :date_range

      apply_filter(acc, base, type, value, bound)
    end
  end

  def split_range_key(key)
    k = key.to_s
    return [ k.sub(/_from\z/, "").to_sym, :from ] if k.end_with?("_from")
    return [ k.sub(/_to\z/, "").to_sym,   :to ]   if k.end_with?("_to")
    [ key, nil ]
  end

  def apply_filter(scope, field, type, value, bound)
    case type
    when :exact
      scope.where(field => value)
    when :partial
      # Arel builds the predicate: the identifier is quoted and the value bound, so there is
      # no interpolation. matches(..., case_sensitive: false) renders ILIKE on PostgreSQL.
      # sanitize_like escapes % and _ so a user can't turn a filter into a wildcard scan.
      scope.where(scope.arel_table[field].matches("%#{sanitize_like(value)}%"))
    when :boolean
      scope.where(field => ActiveModel::Type::Boolean.new.cast(value))
    when :date_range
      parsed = parse_time(value)
      raise InvalidQueryParameter, "Invalid date for #{field}: #{value}" if parsed.nil?
      bound == :to ? scope.where(field => ..parsed) : scope.where(field => parsed..)
    else
      raise InvalidQueryParameter, "Unsupported filter type: #{type}"
    end
  end

  def apply_search(scope)
    term = params[:q] || params["q"]
    return scope if term.blank? || searchable_fields.empty?

    pattern = "%#{sanitize_like(term)}%"
    table   = scope.arel_table
    clause  = searchable_fields.map { |f| table[f].matches(pattern) }.reduce(:or)
    scope.where(clause)
  end

  def apply_sort(scope)
    raw = params[:sort] || params["sort"]
    return scope.order(default_sort) if raw.blank?

    ordering = raw.to_s.split(",").each_with_object({}) do |token, acc|
      token = token.strip
      next if token.empty?
      direction = token.start_with?("-") ? :desc : :asc
      field = token.delete_prefix("-")
      unless sortable_fields.include?(field)
        raise InvalidQueryParameter, "Unknown sort field: #{field}"
      end
      acc[field.to_sym] = direction
    end

    ordering.empty? ? scope.order(default_sort) : scope.order(ordering)
  end

  def sanitize_like(value) = ActiveRecord::Base.sanitize_sql_like(value.to_s)

  # Endless-method form can't carry a rescue clause, so this stays a normal def.
  def parse_time(value)
    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end
