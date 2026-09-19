require "test_helper"

class PublicProfilesTest < ActionDispatch::IntegrationTest
  def profile
    Submission.create!(kind: "person", profile_version: 2, name: "Duncan Gough",
      email: "private@example.test", purpose: "People overlooked at work.", experience: "Building useful products.",
      consent: "1", notes: "Private review details", pay_expectations: "Private pay details",
      website: "https://example.test", target_ids: [ "1.1" ], sectors_future: [ ProfileOptions::SECTORS.first ],
      skills: [ { "skill" => "Delivery", "results" => "Launched a service", "organisation" => "Example", "time" => "2025" } ])
  end

  test "only explicitly published profiles are public and slugs stay stable" do
    entry = profile
    assert_nil entry.public_slug
    get profile_path(entry.id)
    assert_response :not_found
    entry.update!(published: true)
    assert_match(/\Aduncan-gough-[a-f0-9]{12}\z/, entry.public_slug)
    slug = entry.public_slug
    get profile_path(slug)
    assert_response :success
    assert_select "h1", text: "Duncan Gough"
    assert_select "h3", text: "Delivery"
    assert_select "details li", text: /#{Regexp.escape(ProfileOptions::TARGETS.fetch("1.1").fetch("text"))}/
    assert_select "a[href='https://example.test']"
    [ entry.email, entry.notes, entry.pay_expectations, entry.status ].each { |value| assert_no_match value, response.body }
    entry.update!(name: "Different Name", published: false)
    get profile_path(slug)
    assert_response :not_found
    entry.update!(published: true)
    assert_equal slug, entry.public_slug
    other = profile
    other.update!(published: true)
    assert_not_equal slug, other.public_slug
  end

  test "public applicants cannot publish themselves" do
    post people_path, params: { submission: { name: "Test", email: "test@example.test", purpose: "Useful work",
      experience: "A project", consent: "1", published: true, public_slug: "injected" } }
    assert_redirected_to thanks_path
    assert_not Submission.last.published?
    assert_nil Submission.last.public_slug
  end

  test "publication requires authenticated admin access" do
    entry = profile
    patch admin_submission_path(entry), params: { submission: { published: true } }
    assert_includes [ 401, 503 ], response.status
    assert_not entry.reload.published?
  end

  test "public profile escapes submitted markup and rejects unsafe website links" do
    entry = profile
    entry.update_columns(published: true, public_slug: "unsafe-test", website: "javascript:alert(1)", purpose: '<script>alert(1)</script><img src=x onerror="alert(1)">')
    get profile_path(entry.public_slug)
    assert_response :success
    assert_select "script, [onerror], a[href^='javascript:']", count: 0
  end
end
