class CreatePermissions < ActiveRecord::Migration[7.1]
  def change
    create_table :permissions do |t|
      t.string :name, null: false
      t.string :resource, null: false
      t.string :action, null: false
      t.text :description, null: false
      t.timestamps
    end
    
    add_index :permissions, :name, unique: true
    add_index :permissions, :resource
    add_index :permissions, :action
    add_index :permissions, [:resource, :action], unique: true
  end
end