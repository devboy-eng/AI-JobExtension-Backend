class CreateRoles < ActiveRecord::Migration[7.1]
  def change
    create_table :roles do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.string :color, null: false
      t.integer :priority, null: false
      t.boolean :active, default: true
      t.timestamps
    end
    
    add_index :roles, :name, unique: true
    add_index :roles, :priority, unique: true
    add_index :roles, :active
  end
end