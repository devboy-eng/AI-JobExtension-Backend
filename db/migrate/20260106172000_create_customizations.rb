class CreateCustomizations < ActiveRecord::Migration[7.1]
  def change
    create_table :customizations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :job_title, null: false
      t.string :company, null: false
      t.string :posting_url
      t.string :platform
      t.integer :ats_score, default: 0
      t.text :keywords_matched
      t.text :keywords_missing
      t.text :resume_content
      t.json :profile_snapshot

      t.timestamps
    end

    add_index :customizations, :job_title
    add_index :customizations, :company
    add_index :customizations, :created_at
  end
end