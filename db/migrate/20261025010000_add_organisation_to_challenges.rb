class AddOrganisationToChallenges < ActiveRecord::Migration[8.1]
  def change
    add_reference :challenges, :organisation, foreign_key: { to_table: :submissions, on_delete: :nullify }
  end
end
