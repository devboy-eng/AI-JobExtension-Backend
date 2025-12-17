class CreateLinks < ActiveRecord::Migration[7.1]
  def change
    create_table :links do |t|
      t.string :title, null: false
      t.string :url, null: false
      t.text :description
      t.integer :position, default: 0
      t.boolean :active, default: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :links, [:user_id, :position]
    add_index :links, [:user_id, :active]
  end
end
