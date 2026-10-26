require "test_helper"
require "base64"

class SideProjectsTest < ActionDispatch::IntegrationTest
  def setup
    @profile = Submission.create!(kind: "person", profile_version: 2, name: "Alex", email: "side@example.test", purpose: "Community", experience: "Making things", consent: "1")
    post login_path, params: { email: @profile.email }
    code = ActionMailer::Base.deliveries.last.body.decoded[/^(\d{6})$/, 1]
    post verify_login_path, params: { code: code }
  end

  def upload(bytes: nil)
    file = Tempfile.new([ "side", ".png" ])
    file.binmode
    file.write(bytes || Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6AAAAAElFTkSuQmCC"))
    file.rewind
    Rack::Test::UploadedFile.new(file.path, "image/png")
  end

  test "side projects have a separate tab and gallery with editable cover and removals" do
    get edit_account_profile_path(section: "side_projects")
    assert_response :success
    assert_select "a[aria-current=page]", text: "Side projects"
    assert_select "#side-projects", count: 0
    post side_projects_path, params: { profile_id: @profile.id, side_project: { name: "Pottery", description: "Learning to make bowls", purpose: "Make useful things", joy: "Sharing gifts", url: "https://example.test" }, photos: [ upload, upload ] }
    assert_response :see_other
    project = @profile.side_projects.sole
    assert_equal 2, project.photos.count
    photos = project.photos.to_a
    assert_equal @profile.id, photos.first.submission_id
    patch side_project_path(project), params: { side_project: { name: "Pottery evenings" }, cover_image_id: photos.last.id }
    assert_response :see_other
    assert_equal photos.last.id, project.reload.cover_photo.id
    get profile_path(@profile.public_slug)
    assert_select "#side-projects h3", text: "Pottery evenings"
    assert_select ".side-project-gallery img", count: 2
    assert_select ".side-project-cover[src='#{portfolio_image_path(photos.last)}']"
    patch account_profile_path, params: { section: "portfolio", submission: { projects: [] } }
    assert_response :see_other
    assert_equal 2, project.photos.count, "Saving portfolio must preserve side-project photos"
    patch side_project_path(project), params: { side_project: { name: "Pottery" }, remove_photo_ids: [ photos.last.id ] }
    assert_equal photos.first.id, project.reload.cover_photo.id
    get portfolio_image_path(photos.last)
    assert_response :not_found
    delete side_project_path(project)
    assert_response :see_other
    assert_not SideProject.exists?(project.id)
    assert_not PortfolioImage.exists?(photos.first.id)
  end

  test "photos follow publication access and projects cannot be edited by others" do
    post side_projects_path, params: { side_project: { name: "A hobby" }, photos: [ upload ] }
    project = @profile.side_projects.sole
    photo = project.photos.sole
    @profile.update!(published: false)
    visitor = open_session
    visitor.get portfolio_image_path(photo)
    assert_equal 404, visitor.response.status
    visitor.get profile_path(@profile.public_slug)
    assert_equal 404, visitor.response.status
    get portfolio_image_path(photo)
    assert_response :success
    other = Submission.create!(kind: "person", profile_version: 2, name: "Other", email: "other-side@example.test", purpose: "Community", experience: "Making", consent: "1")
    foreign_project = other.side_projects.create!(name: "Private")
    patch side_project_path(foreign_project), params: { side_project: { name: "Stolen" } }
    assert_response :not_found
    delete side_project_path(foreign_project)
    assert_response :not_found
    patch side_project_path(project), params: { profile_id: other.id, side_project: { name: "Wrong profile" } }
    assert_response :not_found
  end

  test "invalid photos and links save nothing and galleries are bounded" do
    assert_no_difference [ "SideProject.count", "PortfolioImage.count" ] do
      post side_projects_path, params: { side_project: { name: "Sketches" }, photos: [ upload, upload(bytes: "not an image") ] }
    end
    assert_response :unprocessable_entity
    assert_select "input[name='side_project[name]'][value=Sketches]"
    post side_projects_path, params: { side_project: { name: "Sketches", url: "javascript:alert(1)" } }
    assert_response :unprocessable_entity
    post side_projects_path, params: { side_project: { name: "Sketches" }, photos: Array.new(6) { upload } }
    assert_response :unprocessable_entity
    assert_equal 0, @profile.side_projects.count
    post side_projects_path, params: { side_project: { name: "Only a name", submission_id: 999 } }
    assert_response :see_other
    assert_equal @profile.id, SideProject.last.submission_id
  end
  test "company profiles cannot use side projects and personal collections have a limit" do
    10.times { |index| @profile.side_projects.create!(name: "Project #{index}") }
    post side_projects_path, params: { side_project: { name: "One too many" } }
    assert_response :unprocessable_entity
    assert_equal 10, @profile.side_projects.count
    company = Submission.create!(account: @profile.reload.account, kind: "organisation", profile_version: 2,
      name: "Alex", email: @profile.email, organisation_name: "Company", mission: "Help", purpose: "Community",
      offering: "Services", challenge_kind: "Goals", challenge: "Grow", consent: "1")
    patch switch_profile_path, params: { selected_profile_id: company.id }
    get new_side_project_path
    assert_response :not_found
    post side_projects_path, params: { side_project: { name: "Not personal" } }
    assert_response :not_found
    get edit_account_profile_path(section: "side_projects")
    assert_response :not_found
  end

  test "failed replacement keeps existing photos and another projects photos cannot be selected" do
    post side_projects_path, params: { side_project: { name: "First" }, photos: [ upload ] }
    first = @profile.side_projects.sole
    photo = first.photos.sole
    post side_projects_path, params: { side_project: { name: "Second" }, photos: [ upload ] }
    other_photo = @profile.side_projects.find_by!(name: "Second").photos.sole
    patch side_project_path(first), params: { side_project: { name: "Changed" }, remove_photo_ids: [ photo.id ], photos: [ upload(bytes: "bad") ] }
    assert_response :unprocessable_entity
    assert_equal "First", first.reload.name
    assert PortfolioImage.exists?(photo.id)
    patch side_project_path(first), params: { side_project: { name: "Changed" }, cover_image_id: other_photo.id }
    assert_response :not_found
    patch side_project_path(first), params: { side_project: { name: "Changed" }, remove_photo_ids: [ other_photo.id ] }
    assert_response :not_found
    assert PortfolioImage.exists?(other_photo.id)
  end
end
