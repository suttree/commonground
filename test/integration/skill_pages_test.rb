require "test_helper"

class SkillPagesTest < ActionDispatch::IntegrationTest
  def profile
    Submission.create!(kind: "person", profile_version: 2, name: "Example", email: "private@example.test",
      purpose: "Useful work", experience: "Projects", consent: "1", published: true, notes: "Private review",
      skills: [ { "skill" => "Delivery", "organisation" => "Co-op", "time" => "2026", "results" => "A detailed account. " * 20 },
                { "skill" => "Research", "organisation" => "Studio", "time" => "2025", "results" => "Interviewed people." } ])
  end

  test "previews link to full skill pages with working navigation" do
    entry = profile
    get profile_path(entry.public_slug)
    assert_response :success
    assert_select ".skill-carousel.has-many .skill-card", count: 2
    assert_select "a[href='#skill-2'][aria-label='Next skill']"
    assert_select ".skill-preview" do |elements|
      assert_operator elements.first.text.length, :<=, 140
    end
    get profile_skill_path(entry.public_slug, 1)
    assert_response :success
    assert_select "h1", text: "Delivery"
    assert_select ".prose", text: /#{Regexp.escape(entry.skills.first['results'].strip)}/
    assert_select "a[href='#{profile_skill_path(entry.public_slug, 2)}']"
    assert_select "a[href='#{profile_path(entry.public_slug)}#skill-1']"
    [ entry.email, entry.notes ].each { |value| assert_no_match value, response.body }
    assert_equal "no-store", response.headers["Cache-Control"]
    entry.update!(published: false)
    get profile_skill_path(entry.public_slug, 1)
    assert_response :not_found
  end

  test "missing skills return 404 and a single card has no carousel controls" do
    entry = profile
    entry.update!(skills: entry.skills.first(1))
    get profile_path(entry.public_slug)
    assert_select ".skill-card", count: 1
    assert_select ".skill-controls", count: 0
    [ "0", "-1", "2", "nope" ].each do |position|
      get "/profiles/#{entry.public_slug}/skills/#{position}"
      assert_response :not_found
    end
  end
end
