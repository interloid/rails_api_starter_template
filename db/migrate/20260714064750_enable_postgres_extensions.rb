class EnablePostgresExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto"  # gen_random_uuid()
    enable_extension "citext"    # case-insensitive email

    # UUID strategy: primary keys default to gen_random_uuid() (UUID v4). V4 is random,
    # which fragments B-tree index inserts at high volume. On PostgreSQL 18+, switch the
    # column default to uuidv7() (time-ordered) for better insert locality/performance.
    # No app code changes are needed for that swap.
  end
end
