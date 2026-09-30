require "test_helper"

class PublicProfilesTest < ActionDispatch::IntegrationTest
  test "organisation profiles show their work and collaboration needs without contact details" do
    entry = Submission.create!(kind: "organisation", profile_version: 2, name: "Private contact",
      organisation_name: "Ara the Songbird", email: "private@example.test", consent: "1",
      purpose: "People adjacent to loneliness", mission: "Provide companionship", offering: "A robot songbird",
      challenge_kind: "Challenges", challenge: "Local production", help_needed: "Product design and research",
      notes: "Private review",
      products: [ { "name" => "Ara", "special" => "Birdsong without surveillance", "impact" => "Reduce loneliness" } ])
    assert_match(/\Aara-the-songbird-[a-f0-9]{12}\z/, entry.public_slug)
    get profile_path(entry.public_slug)
    assert_response :success
    assert_select "h1", text: "Ara the Songbird"
    assert_select ".profile-main", text: /Provide companionship/
    assert_select ".profile-evidence h3", text: "Ara"
    assert_select ".profile-evidence", text: /Reduce loneliness/
    assert_select "aside", text: /Local production/
    assert_select "aside", text: /Product design and research/
    assert_select "h2", text: "Our current challenges"
    assert_select "h2", text: "Our impact", count: 0
    [ entry.name, entry.email, entry.notes, entry.status ].each { |value| assert_no_match value, response.body }
    entry.update!(challenge_kind: "Goals")
    get profile_path(entry.public_slug)
    assert_select "h2", text: "Our current goals"
    assert_select "h2", text: "Our current challenges", count: 0
  end

  def profile
    Submission.create!(kind: "person", profile_version: 2, name: "Duncan Gough",
      email: "private@example.test", purpose: "People overlooked at work.", experience: "Building useful products.",
      consent: "1", notes: "Private review details", pay_expectations: "Private pay details",
      website: "https://example.test", target_ids: [ "1.1" ], sectors_future: [ ProfileOptions::SECTORS.first ],
      skills: [ { "skill" => "Delivery", "results" => "Launched a service", "organisation" => "Example", "time" => "2025" } ])
  end

  test "profiles are public by default and slugs stay stable" do
    entry = profile
    assert entry.public_slug.present?
    assert entry.published?
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

  test "new profiles are public and clients cannot override visibility or slug" do
    post people_path, params: { submission: { name: "Test", email: "test@example.test", purpose: "Useful work",
      experience: "A project", consent: "1", published: false, public_slug: "injected" } }
    assert_redirected_to create_account_path
    assert Submission.last.published?
    assert_not_equal "injected", Submission.last.public_slug
    get profile_path(Submission.last.public_slug)
    assert_response :success
  end

  test "publication requires authenticated admin access" do
    entry = profile
    patch admin_submission_path(entry), params: { submission: { published: false } }
    assert_includes [ 401, 503 ], response.status
    assert entry.reload.published?
  end

  test "public profile escapes submitted markup and rejects unsafe website links" do
    entry = profile
    entry.update_columns(published: true, public_slug: "unsafe-test", website: "javascript:alert(1)", purpose: '<script>alert(1)</script><img src=x onerror="alert(1)">')
    get profile_path(entry.public_slug)
    assert_response :success
    assert_select "script, [onerror], a[href^='javascript:']", count: 0
  end
end
