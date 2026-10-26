class AddProfilesToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :profile, :json, null: false, default: {}
    add_column :submissions, :profile_version, :integer, null: false, default: 1
  end
end
