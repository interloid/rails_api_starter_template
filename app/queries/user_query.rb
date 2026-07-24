class UserQuery < ApplicationQuery
  filterable(
    email:      :exact,
    first_name: :partial,
    last_name:  :partial,
    confirmed_at: :date_range,
    created_at: :date_range
  )

  sortable :created_at, :updated_at, :email, :first_name, :last_name

  # NOTE: ILIKE across several columns does not use a btree index. At scale add
  # pg_trgm GIN indexes on these columns, or move search to a dedicated engine.
  searchable :email, :first_name, :last_name

  sort_default :created_at, :desc
end
