class AddOnboardingToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :onboarding, :json, default: {}, null: false
  end
end
