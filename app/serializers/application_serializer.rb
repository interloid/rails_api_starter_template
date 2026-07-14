class ApplicationSerializer
  def self.one(record, **opts)
    record.nil? ? nil : new(record, **opts).serialize
  end

  def self.many(records, **opts)
    records.map { |r| new(r, **opts).serialize }
  end

  def initialize(record, **opts)
    @record = record
    @opts = opts
  end

  def serialize
    raise NotImplementedError, "#{self.class} must implement #serialize"
  end

  private

  attr_reader :record, :opts
end
