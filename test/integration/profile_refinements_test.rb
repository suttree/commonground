require "test_helper"
require "base64"

class ProfileRefinementsTest < ActionDispatch::IntegrationTest
  def answers
    { name: "Example", email: "example@example.test", purpose: "Useful work", experience: "Delivery", consent: "1" }
  end

  def project
    { title: "Community garden", role: "Designer", organisation: "Local group", time: "2026", url: "https://example.test/project",
      problem: "No growing space", context: "A shared courtyard", approach: "Designed with neighbours", results: "A garden", caption: "Plan of the garden" }
  end

  def upload(type: "image/png", bytes: nil)
    file = Tempfile.new([ "portfolio", ".png" ])
    file.binmode
    file.write(bytes || Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6AAAAAElFTkSuQmCC"))
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type)
  end

  def draft_token
    css_select("input[name='submission[projects][][image_token]']").first["value"]
  end

  test "priorities have a maximum of three and exploring is exclusive" do
    ids = ProfileOptions::TARGETS.keys.first(4)
    post people_path, params: { submission: answers.merge(target_ids: ids) }
    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /three/
    assert_select ".target-choice", count: 0
    post people_path, params: { submission: answers.merge(target_ids: ids.first(3)) }
    assert_redirected_to create_account_path
    assert_equal ids.first(3), Submission.last.target_ids
    post people_path, params: { submission: answers.merge(exploring: "1", target_ids: ids.first(1)) }
    assert_response :unprocessable_entity
    post people_path, params: { submission: answers.merge(exploring: "1", target_ids: [ "" ]) }
    assert_redirected_to create_account_path
    entry = Submission.last
    entry.update!(published: true)
    get profile_path(entry.public_slug)
    assert_select "p", text: /I'm still exploring/
  end

  test "existing broad priorities stay private and review updates preserve them" do
    entry = Submission.create!(answers.merge(kind: "person", profile_version: 2))
    ids = ProfileOptions::TARGETS.keys.first(4)
    entry.update_columns(profile: { "target_ids" => ids })
    entry.reload.update!(published: true, notes: "Review still works")
    get profile_path(entry.public_slug)
    assert_response :success
    assert_select ".profile-targets", count: 0
    assert_equal ids, entry.reload.target_ids
    entry.update!(target_ids: ids.first(2))
    get profile_path(entry.public_slug)
    assert_select ".profile-goals li", count: 2
  end

  test "images survive add another and validation then follow publication access" do
    post people_path, params: { add_section: "projects", submission: answers.merge(projects: [ project ]), project_images: { "0" => upload } }
    assert_response :success
    token = draft_token
    image = PortfolioImage.last
    assert_nil image.submission_id
    get draft_portfolio_image_path(token: token)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    stranger = open_session
    stranger.get draft_portfolio_image_path(token: token)
    assert_equal 404, stranger.response.status
    stranger.post people_path, params: { submission: answers.merge(projects: [ project.merge(image_token: token) ]) }
    assert_equal 422, stranger.response.status
    post people_path, params: { submission: answers.merge(email: "bad", projects: [ project.merge(image_token: token) ]) }
    assert_response :unprocessable_entity
    assert_select "img.portfolio-image", count: 1
    post people_path, params: { submission: answers.merge(projects: [ project.merge(image_token: draft_token) ]) }
    assert_redirected_to create_account_path
    entry = Submission.last
    assert_equal entry.id, image.reload.submission_id
    assert_equal image.id, entry.projects.first["image_id"]
    assert_nil entry.projects.first["image_token"]
    assert entry.published?
    get portfolio_image_path(image)
    assert_response :success
    get profile_path(entry.public_slug)
    assert_select "h3", text: "Community garden"
    assert_select "img[alt='Plan of the garden']"
    get profile_project_path(entry.public_slug, 1)
    assert_response :success
    assert_select "a[href='https://example.test/project']"
    assert_select ".prose", text: /Designed with neighbours/
    get portfolio_image_path(image)
    assert_response :success
    entry.update!(published: false)
    get portfolio_image_path(image)
    assert_response :not_found
  end

  test "bad uploads and unsafe project links are rejected" do
    post people_path, params: { submission: answers.merge(projects: [ project ]), project_images: { "0" => upload(bytes: '<svg onload="alert(1)"></svg>') } }
    assert_response :unprocessable_entity
    assert_equal 0, PortfolioImage.count
    post people_path, params: { submission: answers.merge(projects: [ project ]), project_images: { "0" => upload(bytes: "x" * (2.megabytes + 1)) } }
    assert_response :unprocessable_entity
    post people_path, params: { submission: answers.merge(projects: [ project.merge(url: "javascript:alert(1)") ]) }
    assert_response :unprocessable_entity
    assert_select "#projects-error", text: /https/
  end

  test "removing a draft image deletes the upload and keeps the project" do
    post people_path, params: { add_section: "projects", submission: answers.merge(projects: [ project ]), project_images: { "0" => upload } }
    token = draft_token
    assert_difference "PortfolioImage.count", -1 do
      post people_path, params: { submission: answers.merge(projects: [ project.merge(image_token: token, remove_image: "1") ]) }
    end
    assert_redirected_to create_account_path
    assert_nil Submission.last.projects.first["image_id"]
  end
end
