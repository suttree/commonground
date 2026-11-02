require "test_helper"

class GoalProjectsTest < ActionDispatch::IntegrationTest
  test "goal and target pages show only matching published projects in publication order" do
    owner = Submission.create!(kind: "person", profile_version: 2, name: "Alex", email: "goals@example.test", purpose: "Useful work", experience: "Community work", consent: "1")
    attrs = { description: "Reduce waste", location: "Bristol", objectives: "Useful work", status: "active", target_ids: [ "12.3" ] }
    older = owner.challenges.create!(**attrs.merge(title: "Older project"))
    older.update_columns(status: "completed", published_at: 2.days.ago)
    newer = owner.challenges.create!(**attrs.merge(title: "Newer project"))
    newer.update_columns(published_at: 1.day.ago)
    draft = owner.challenges.create!(**attrs.merge(title: "Private draft", status: "draft"))
    get sdg_goal_path("12")
    assert_response :success
    assert_select ".sdg-projects .challenge-card h3", text: "Newer project"
    assert_operator response.body.index("Newer project"), :<, response.body.index("Older project")
    assert_select ".sdg-projects a[href='#{challenge_path(draft)}']", count: 0
    get sdg_target_path("12.3")
    assert_select ".sdg-projects .challenge-card", count: 2
    get sdg_target_path("12.2")
    assert_select ".sdg-projects .challenge-card", count: 0
    assert_select ".sdg-projects", text: /No published projects/
    owner.update!(published: false)
    get sdg_goal_path("12")
    assert_select ".sdg-projects .challenge-card", count: 0
  end
end
