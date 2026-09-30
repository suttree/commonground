require "test_helper"

class SdgDirectoryTest < ActionDispatch::IntegrationTest
  test "directory links to every goal and every target resolves with full wording" do
    get sdgs_path
    assert_response :success
    assert_select ".sdg-goal-card", count: 17
    ProfileOptions::GOALS.each do |goal|
      get sdg_goal_path(goal.fetch("id"))
      assert_response :success
      assert_select ".sdg-target-card", count: goal.fetch("targets").size
      goal.fetch("targets").each do |target|
        get sdg_target_path(target.fetch("id"))
        assert_response :success
        assert_select ".sdg-full-target p", text: target.fetch("text")
        assert_select "h1", text: SdgDirectory::LABELS.fetch(target.fetch("id"))
      end
    end
  end

  test "search matches identifiers and text, with goal filtering and pagination" do
    get sdgs_path(q: "12.6")
    assert_select ".sdg-target-card h3 a[href=?]", sdg_target_path("12.6")
    get sdgs_path(q: "FOOD WASTE")
    assert_select ".sdg-target-card h3 a[href=?]", sdg_target_path("12.3")
    get sdgs_path(q: "water", goal: "6")
    assert_select ".sdg-target-card", minimum: 1
    assert_select ".sdg-target-card h3 a" do |links|
      assert links.all? { |link| link["href"].start_with?("/sustainable-development-goals/targets/6.") }
    end
    get sdgs_path(q: "2030")
    assert_select ".sdg-target-card", count: 18
    assert_select "a", text: "Next page"
    get sdgs_path(q: "2030", page: 2)
    assert_select "a", text: "Previous page"
    get sdgs_path(q: "nothing-matches-this")
    assert_select ".empty-state", text: /No targets match/
    get sdgs_path(q: "<script>alert(1)</script>")
    assert_select "script", count: 1
    assert_select "script[src='https://scripts.withcabin.com/hello.js'][async][defer]", count: 1
  end

  test "legacy URLs redirect to the new directory and preserve searches" do
    get "/sdgs", params: { q: "food waste", goal: "12" }
    assert_response :moved_permanently
    assert_equal sdgs_path, URI.parse(response.location).path
    assert_equal({ "q" => "food waste", "goal" => "12" }, Rack::Utils.parse_query(URI.parse(response.location).query))
    get "/sdgs/12"
    assert_redirected_to sdg_goal_path("12")
    get "/sdgs/targets/12.6"
    assert_redirected_to sdg_target_path("12.6")
    follow_redirect!
    assert_response :success
  end

  test "invalid reference pages return 404 and malformed search stays safe" do
    get sdg_goal_path("99")
    assert_response :not_found
    get sdg_target_path("99.9")
    assert_response :not_found
    get sdgs_path(q: { bad: "input" }, goal: [ "1" ], page: "bad")
    assert_response :success
    assert_select ".sdg-goal-card", count: 17
  end
end
