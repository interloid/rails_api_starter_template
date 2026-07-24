class AddIndexToRefreshTokensExpiresAt < ActiveRecord::Migration[8.1]
  # PurgeExpiredRefreshTokensJob filters on expires_at; index it so the daily sweep
  # doesn't seq-scan the table.
  def change
    add_index :refresh_tokens, :expires_at
  end
end
