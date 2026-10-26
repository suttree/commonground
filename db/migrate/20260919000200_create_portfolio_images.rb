class CreatePortfolioImages < ActiveRecord::Migration[8.1]
  def change
    create_table :portfolio_images do |t|
      t.references :submission, foreign_key: true
      t.string :upload_owner, null: false
      t.string :content_type, null: false
      t.binary :data, null: false
      t.timestamps
    end
    add_index :portfolio_images, [ :upload_owner, :created_at ]
  end
end
