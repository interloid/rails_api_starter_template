module Filterable
  extend ActiveSupport::Concern

  private

  # Applies an allowlisted query object. The query object — not strong params — is the
  # security boundary: it rejects any field not explicitly declared.
  def apply_query(scope, query_class)
    query_class.call(scope, query_params)
  end

  def query_params
    params.permit(:q, :sort, filter: {})
  end
end
