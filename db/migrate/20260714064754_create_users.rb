class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :first_name
      t.string :last_name
      t.datetime :discarded_at
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :discarded_at
  end
end
