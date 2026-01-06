class CreateResumeVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :resume_versions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :job_title
      t.string :company
      t.text :posting_url
      t.integer :ats_score
      t.json :keywords_matched
      t.json :keywords_missing
      t.text :resume_content
      t.json :profile_snapshot

      t.timestamps
    end
  end
end
