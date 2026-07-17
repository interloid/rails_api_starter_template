class CreateRefreshTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :refresh_tokens, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      # SHA-256 of the opaque token — the raw token is NEVER stored.
      t.string :token_digest, null: false
      # Groups a lineage of rotated tokens; reuse revokes the whole family.
      t.uuid :family_id, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.string :user_agent
      t.string :ip_address
      t.timestamps
    end
    add_index :refresh_tokens, :token_digest, unique: true
    add_index :refresh_tokens, :family_id
    add_index :refresh_tokens, %i[user_id revoked_at]
  end
end
