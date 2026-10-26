class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :email, null: false
      t.timestamps
    end
    add_index :accounts, :email, unique: true
    add_reference :submissions, :account, foreign_key: true
    create_table :login_codes do |t|
      t.string :email, null: false
      t.string :request_ip, null: false
      t.string :digest, null: false
      t.datetime :expires_at, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :used_at
      t.timestamps
    end
    add_index :login_codes, [ :email, :created_at ]
    add_index :login_codes, [ :request_ip, :created_at ]
  end
end
