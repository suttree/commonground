# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Keep these versioned questions consistent with the initial migration. Changed wording needs a new key.
[
  [ "repairable-products-v1", "Should companies be required to make their products repairable, even if that makes them more expensive to buy?", "12" ],
  [ "public-transport-v1", "Should cities give more road space to public transport, even if that leaves less room for private cars?", "11" ],
  [ "paid-training-v1", "Should employers provide paid time for staff to learn new skills, even if that reduces the time spent on their usual work?", "8" ]
].each_with_index do |(key, question, goal_id), index|
  Provocation.find_or_create_by!(key: key) do |provocation|
    provocation.question = question
    provocation.goal_id = goal_id
    provocation.position = index + 1
  end
end
