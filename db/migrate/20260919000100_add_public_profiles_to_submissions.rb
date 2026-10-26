class AddPublicProfilesToSubmissions < ActiveRecord::Migration[8.1]
  def change
    add_column :submissions, :public_slug, :string
    add_column :submissions, :published, :boolean, default: false, null: false
    add_index :submissions, :public_slug, unique: true
  end
end
