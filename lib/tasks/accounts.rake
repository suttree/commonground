namespace :accounts do
  desc "Remove login code records older than one day"
  task prune_codes: :environment do
    LoginCode.where("created_at < ?", 1.day.ago).delete_all
  end
end
