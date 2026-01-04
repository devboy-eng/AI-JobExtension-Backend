class AddProfileDataToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :profile_data, :json, default: {}
  end
end
