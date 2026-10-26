# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# This versioned catalogue is also used by the expansion migration. Do not edit its wording.
JSON.parse(File.read(Rails.root.join("db/data/provocations_v1.json"))).each do |attributes|
  Provocation.find_or_create_by!(key: attributes.fetch("key")) do |provocation|
    provocation.assign_attributes(attributes)
  end
end
