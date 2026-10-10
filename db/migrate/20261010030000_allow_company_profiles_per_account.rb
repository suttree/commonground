class AllowCompanyProfilesPerAccount < ActiveRecord::Migration[8.1]
  def up
    remove_index :submissions, :account_id
    add_index :submissions, :account_id
    add_index :submissions, :account_id, unique: true, where: "kind = 'person'", name: "one_person_profile_per_account"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Accounts may now own several company profiles."
  end
end
