class CreatePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :permissions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :name, null: false
      t.string :resource, null: false
      t.string :action, null: false
      t.string :description
      t.timestamps
    end
    add_index :permissions, :name, unique: true
    add_index :permissions, %i[resource action]
  end
end
