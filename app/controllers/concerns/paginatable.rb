module Paginatable
  extend ActiveSupport::Concern
  include Pagy::Method   # pagy 43+ renamed the classic `Pagy::Backend` mixin to `Pagy::Method`

  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 100

  private

  # Paginate a scope; per_page is clamped to [1, MAX_PER_PAGE].
  def paginate(scope)
    per_page = params[:per_page].present? ? params[:per_page].to_i.clamp(1, MAX_PER_PAGE) : DEFAULT_PER_PAGE
    pagy(scope, limit: per_page)   # pagy reads page from params[:page]. Older pagy: use items:
  end

  # Maps a pagy object to the { total, page, records_per_page, total_pages } envelope meta.
  def pagination_meta(pagy)
    {
      total: pagy.count,
      page: pagy.page,
      records_per_page: (pagy.respond_to?(:limit) ? pagy.limit : pagy.vars[:items]),
      total_pages: pagy.pages
    }
  end
end
