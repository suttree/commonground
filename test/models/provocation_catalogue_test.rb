require "test_helper"
require Rails.root.join("db/migrate/20261018010000_expand_provocations")

class ProvocationCatalogueTest < ActiveSupport::TestCase
  test "expansion covers every goal and preserves existing questions and answers on reruns" do
    load Rails.root.join("db/seeds.rb")
    catalogue = JSON.parse(File.read(Rails.root.join("db/data/provocations_v1.json")))
    assert_equal 30, catalogue.size
    assert_equal 30, catalogue.map { |entry| entry.fetch("key") }.uniq.size
    assert_equal (1..17).map(&:to_s).sort, catalogue.map { |entry| entry.fetch("goal_id") }.uniq.sort
    assert_equal (1..30).to_a, catalogue.map { |entry| entry.fetch("position") }

    profile = Submission.create!(kind: "person", profile_version: 2, name: "Catalogue test",
      email: "catalogue@example.test", purpose: "Useful work", experience: "Making things", consent: "1")
    original = Provocation.find_by!(key: "repairable-products-v1")
    answer = profile.provocation_answers.create!(provocation: original, choice: "yes")
    snapshot = original.attributes
    # Simulate an installation that only has the three starter questions.
    Provocation.where(key: catalogue.drop(3).map { |entry| entry.fetch("key") }).destroy_all
    migration = ExpandProvocations.new
    assert_difference "Provocation.count", 27 do
      migration.suppress_messages { migration.up }
    end
    assert_no_difference "Provocation.count" do
      migration.suppress_messages { migration.up }
      load Rails.root.join("db/seeds.rb")
    end
    assert_equal snapshot, original.reload.attributes
    assert_equal original.id, answer.reload.provocation_id
    assert_equal "yes", answer.choice
    catalogue.each do |entry|
      assert_equal entry, Provocation.find_by!(key: entry.fetch("key")).attributes.slice(*entry.keys)
    end
  end
end
