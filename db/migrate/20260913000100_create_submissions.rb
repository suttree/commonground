class CreateSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :submissions do |t|
      t.string :kind, null: false
      t.string :name, null: false
      t.string :email, null: false
      t.string :organisation_name
      t.string :website
      t.text :challenge
      t.text :purpose, null: false
      t.text :experience
      t.string :working_style, null: false
      t.string :engagement, null: false
      t.text :availability, null: false
      t.text :location, null: false
      t.text :pay_expectations, null: false
      t.string :status, null: false, default: "Received"
      t.text :notes
      t.datetime :consented_at, null: false
      t.timestamps
    end
    add_index :submissions, [ :kind, :created_at ]
    add_index :submissions, :status
  end
end
