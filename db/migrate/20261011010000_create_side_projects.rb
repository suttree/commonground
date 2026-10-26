class CreateSideProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :side_projects do |t|
      t.references :submission, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.text :purpose
      t.text :joy
      t.string :url
      t.integer :cover_image_id
      t.timestamps
    end
    add_reference :portfolio_images, :side_project, foreign_key: true
  end
end
