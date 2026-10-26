class LimitAccountsToOneProfile < ActiveRecord::Migration[8.1]
  def up
    remove_index :submissions, :account_id
    add_index :submissions, :account_id, unique: true

    profiles = Class.new(ActiveRecord::Base) { self.table_name = "submissions" }
    profiles.where(public_slug: nil).find_each do |profile|
      profile.update_columns(public_slug: "profile-#{profile.id}-#{SecureRandom.hex(6)}")
    end
  end

  def down
    remove_index :submissions, :account_id
    add_index :submissions, :account_id
  end
end
