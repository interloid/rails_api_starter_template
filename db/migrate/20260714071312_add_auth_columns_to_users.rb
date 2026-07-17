class AddAuthColumnsToUsers < ActiveRecord::Migration[8.1]
  def change
    # Trackable
    add_column :users, :sign_in_count, :integer, default: 0, null: false
    add_column :users, :current_sign_in_at, :datetime
    add_column :users, :last_sign_in_at, :datetime
    add_column :users, :current_sign_in_ip, :string
    add_column :users, :last_sign_in_ip, :string
    # Lockable
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime
    # Confirmable (used in 8B; column added now to avoid a second migration)
    add_column :users, :confirmed_at, :datetime
    add_index :users, :locked_at
  end
end
