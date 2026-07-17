class CreateRolePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :role_permissions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :role, null: false, foreign_key: true, type: :uuid
      t.references :permission, null: false, foreign_key: true, type: :uuid
      t.timestamps
    end
    add_index :role_permissions, %i[role_id permission_id], unique: true
  end
end
