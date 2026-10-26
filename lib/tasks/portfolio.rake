namespace :portfolio do
  desc "Remove unattached portfolio images older than 24 hours"
  task prune_drafts: :environment do
    puts "Removed #{PortfolioImage.where(submission_id: nil).where('created_at < ?', 24.hours.ago).delete_all} expired draft images."
  end
end
