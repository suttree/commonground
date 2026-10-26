class AddRemindedAtToCollaboratorInvitations < ActiveRecord::Migration[8.1]
  def change
    add_column :collaborator_invitations, :reminded_at, :datetime
  end
end
