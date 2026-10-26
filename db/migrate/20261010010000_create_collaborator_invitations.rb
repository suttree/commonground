class CreateCollaboratorInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :collaborator_invitations do |t|
      t.references :challenge, null: false, foreign_key: true
      t.string :email, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.datetime :sent_at
      t.timestamps
    end
    add_index :collaborator_invitations, [ :challenge_id, :email ]
  end
end
