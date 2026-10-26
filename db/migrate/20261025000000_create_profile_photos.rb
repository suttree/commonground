class CreateProfilePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :profile_photos do |t|
      t.references :submission, foreign_key: true, index: { unique: true }
      t.string :upload_owner, null: false
      t.string :content_type, null: false
      t.binary :data, null: false
      t.timestamps
    end
    add_index :profile_photos, [ :upload_owner, :created_at ]
  end
end
