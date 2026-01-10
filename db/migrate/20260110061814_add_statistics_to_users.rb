class AddStatisticsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :total_resumes, :integer, default: 0
    add_column :users, :average_ats_score, :float, default: 0.0
    add_column :users, :total_companies, :integer, default: 0
  end
end
