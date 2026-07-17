class CreateUserRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_roles, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :role, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end
    add_index :user_roles, %i[user_id role_id], unique: true
  end
end
