require "test_helper"

class ProjectPagesTest < ActionDispatch::IntegrationTest
  test "project previews link to complete case studies and respect publication" do
    project = { "title" => "Community's garden", "role" => "Designer", "problem" => "Too little growing space. " * 15,
      "context" => "A shared courtyard", "approach" => "Designed with residents", "results" => "A garden for everyone", "url" => "https://example.test/garden" }
    entry = Submission.create!(kind: "person", profile_version: 2, name: "Example", email: "private@example.test",
      purpose: "Useful work", experience: "Projects", consent: "1", published: true, notes: "Private review",
      projects: [ project, project.merge("title" => "Second project") ])
    get profile_path(entry.public_slug)
    assert_response :success
    assert_select ".project-card", count: 2
    assert_select "a[href='#project-2'][aria-label='Next project']"
    assert_select ".project-card .skill-preview" do |elements|
      assert_operator elements.first.text.length, :<=, 140
    end
    assert_select "details.project-story", count: 0
    get profile_project_path(entry.public_slug, 1)
    assert_response :success
    assert_select "h1", text: "Community's garden"
    assert_select "title", text: "Community's garden · Example · Commonbound"
    assert_select ".prose", text: /#{Regexp.escape(project['problem'].strip)}/
    assert_select "h2", text: "Results"
    assert_select "a[href='https://example.test/garden']"
    assert_select "a[href='#{profile_path(entry.public_slug)}#project-1']"
    assert_select "a[href='#{profile_project_path(entry.public_slug, 2)}']"
    [ entry.email, entry.notes ].each { |value| assert_no_match value, response.body }
    [ "0", "-1", "3", "unknown" ].each do |position|
      get "/profiles/#{entry.public_slug}/projects/#{position}"
      assert_response :not_found
    end
    entry.update!(projects: [ project ])
    get profile_path(entry.public_slug)
    assert_select ".project-card .skill-controls", count: 0
    entry.update!(published: false)
    get profile_project_path(entry.public_slug, 1)
    assert_response :not_found
  end
end
