class AddShortTokenToCollaboratorInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :collaborator_invitations, :short_token, :string
    add_index :collaborator_invitations, :short_token, unique: true
  end
end
