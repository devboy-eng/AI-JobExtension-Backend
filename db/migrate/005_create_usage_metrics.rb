class CreateUsageMetrics < ActiveRecord::Migration[7.0]
  def change
    create_table :usage_metrics do |t|
      t.references :user, null: false, foreign_key: true
      t.string :metric_type, null: false
      t.integer :count, default: 1
      t.timestamps
    end
    
    add_index :usage_metrics, [:user_id, :metric_type, :created_at]
  end
end