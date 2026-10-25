require "test_helper"
require "base64"

class ProfilePhotosTest < ActionDispatch::IntegrationTest
  def answers
    { name: "Alex", email: "photo@example.test", purpose: "Help neighbours", experience: "Design", consent: "1" }
  end

  def upload(bytes: nil, type: "image/png")
    file = Tempfile.new([ "profile-photo", ".png" ])
    file.binmode
    file.write(bytes || Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6AAAAAElFTkSuQmCC"))
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type)
  end

  def create_owned_profile
    account = Account.create!(email: answers[:email])
    profile = account.submissions.create!(answers.merge(kind: "person", profile_version: 2))
    sign_in_account(account)
    profile
  end

  def token_from_form
    css_select("input[name=profile_photo_token]").sole["value"]
  end

  test "personal profiles have a default and photo fields are optional" do
    profile = create_owned_profile
    get edit_account_profile_path
    assert_select "form[enctype='multipart/form-data']"
    assert_select "input[type=file][name=profile_photo]:not([required])"
    assert_select ".profile-avatar[src*='default-profile']"
    patch account_profile_path, params: { section: "basics", submission: { name: "Alex Taylor" } }
    assert_response :see_other
    assert_nil profile.reload.profile_photo
    get profile_path(profile.public_slug)
    assert_select ".profile-opening .profile-avatar[src*='default-profile']"
  end

  test "signup preserves a private photo across validation and attaches it on save" do
    account = Account.create!(email: answers[:email])
    sign_in_account(account)
    get onboarding_profile_path
    assert_select "input[type=file][name=profile_photo]:not([required])"
    assert_no_difference "Submission.count" do
      post onboarding_profile_path, params: { submission: answers.merge(purpose: ""), profile_photo: upload }
    end
    assert_response :unprocessable_entity
    token = token_from_form
    photo = ProfilePhoto.last
    assert_nil photo.submission_id
    get draft_profile_photo_path(token: token)
    assert_response :success
    assert_equal "image/png", response.media_type
    stranger = open_session
    stranger.get draft_profile_photo_path(token: token)
    assert_equal 404, stranger.response.status
    post onboarding_profile_path, params: { submission: answers, profile_photo_token: token }
    assert_response :see_other
    profile = account.submissions.sole
    assert_equal profile.id, photo.reload.submission_id
    get draft_profile_photo_path(token: token)
    assert_response :not_found
    get profile_path(profile.public_slug)
    assert_select "img.profile-avatar[src='#{profile_photo_path(photo)}']"
    stranger.get profile_photo_path(photo)
    assert_equal 200, stranger.response.status
    assert_equal "no-store", stranger.response.headers["Cache-Control"]
    assert_equal "nosniff", stranger.response.headers["X-Content-Type-Options"]
    profile.update!(published: false)
    stranger.get profile_photo_path(photo)
    assert_equal 404, stranger.response.status
    get profile_photo_path(photo)
    assert_response :success
    delete logout_path
    get profile_photo_path(photo)
    assert_response :not_found
  end

  test "replacement and removal only change the saved photo after valid basics saves" do
    profile = create_owned_profile
    patch account_profile_path, params: { section: "basics", submission: { name: "Alex" }, profile_photo: upload }
    assert_response :see_other
    original = profile.reload.profile_photo
    assert original
    patch account_profile_path, params: { section: "basics", submission: { name: "" }, profile_photo: upload }
    assert_response :unprocessable_entity
    token = token_from_form
    assert_equal original, profile.reload.profile_photo
    patch account_profile_path, params: { section: "basics", submission: { name: "Alex" }, profile_photo_token: token }
    assert_response :see_other
    replacement = profile.reload.profile_photo
    assert_not_equal original.id, replacement.id
    assert_not ProfilePhoto.exists?(original.id)
    patch account_profile_path, params: { section: "basics", submission: { name: "" }, remove_profile_photo: "1" }
    assert_response :unprocessable_entity
    assert_select "input[name=remove_profile_photo][checked]"
    assert_select ".profile-avatar[src*='default-profile']"
    assert_select "[data-profile-photo][data-retained-src='#{profile_photo_path(replacement)}']"
    assert_equal replacement, profile.reload.profile_photo
    patch account_profile_path, params: { section: "basics", submission: { name: "Alex" }, remove_profile_photo: "1" }
    assert_response :see_other
    assert_nil profile.reload.profile_photo
    get profile_photo_path(replacement)
    assert_response :not_found
  end

  test "photo survives portfolio saves and cannot change from another section or profile" do
    profile = create_owned_profile
    patch account_profile_path, params: { section: "basics", submission: { name: "Alex" }, profile_photo: upload }
    photo = profile.reload.profile_photo
    patch account_profile_path, params: { section: "portfolio", submission: { projects: [ { title: "" } ] }, remove_profile_photo: "1", profile_photo: upload }
    assert_response :see_other
    assert_equal photo, profile.reload.profile_photo
    patch account_profile_path, params: { section: "basics", profile_id: profile.id + 1, submission: { name: "Alex" }, remove_profile_photo: "1" }
    assert_response :not_found
    assert_equal photo, profile.reload.profile_photo
    profile.destroy!
    assert_not ProfilePhoto.exists?(photo.id)
  end

  test "legacy signup keeps the photo through repeaters and isolates draft tokens by session" do
    post people_path, params: { submission: answers, add_section: "skills", profile_photo: upload }
    assert_response :success
    token = token_from_form
    photo = ProfilePhoto.last
    stranger = open_session
    stranger.post people_path, params: { submission: answers, profile_photo_token: token }
    assert_equal 422, stranger.response.status
    assert_nil photo.reload.submission_id
    post people_path, params: { submission: answers, profile_photo_token: token }
    assert_response :see_other
    assert_equal Submission.find_by!(email: answers[:email]).id, photo.reload.submission_id
    post people_path, params: { submission: answers.merge(email: "another@example.test"), profile_photo_token: token }
    assert_response :unprocessable_entity
    assert_equal 1, Submission.where(name: "Alex").count
  end

  test "failed replacement keeps a staged photo and removing the draft discards it" do
    post people_path, params: { submission: answers.merge(name: ""), profile_photo: upload }
    assert_response :unprocessable_entity
    token = token_from_form
    photo = ProfilePhoto.last
    post people_path, params: { submission: answers, profile_photo_token: token, profile_photo: upload(bytes: "not an image") }
    assert_response :unprocessable_entity
    assert_select "input[name=profile_photo_token]"
    assert_nil photo.reload.submission_id
    post people_path, params: { submission: answers, profile_photo_token: token_from_form, remove_profile_photo: "1" }
    assert_response :see_other
    assert_not ProfilePhoto.exists?(photo.id)
    assert_nil Submission.find_by!(email: answers[:email]).profile_photo
  end

  test "expired drafts can be replaced and cannot be published" do
    post people_path, params: { submission: answers.merge(name: ""), profile_photo: upload }
    assert_response :unprocessable_entity
    token = token_from_form
    travel 25.hours do
      get draft_profile_photo_path(token: token)
      assert_response :not_found
      post people_path, params: { submission: answers, profile_photo_token: token }
      assert_response :unprocessable_entity
      assert_select ".field-error", text: /expired/
      assert_select "input[name=profile_photo_token]", count: 0
      post people_path, params: { submission: answers, profile_photo: upload }
      assert_response :see_other
      assert_equal 1, ProfilePhoto.count
    end
  end

  test "invalid oversized and empty uploads do not replace an existing photo" do
    profile = create_owned_profile
    patch account_profile_path, params: { section: "basics", submission: { name: "Alex" }, profile_photo: upload }
    photo = profile.reload.profile_photo
    [ "<svg onload='alert(1)'></svg>", "x" * (2.megabytes + 1), "" ].each do |bytes|
      patch account_profile_path, params: { section: "basics", submission: { name: "Alex" }, profile_photo: upload(bytes: bytes) }
      assert_response :unprocessable_entity
      assert_select "input[name=profile_photo][aria-invalid=true]"
      assert_select "#profile_photo-error", text: /JPEG, PNG or WebP/
      assert_equal photo, profile.reload.profile_photo
    end
  end

  test "company forms and profiles do not show personal photo controls or defaults" do
    get new_organisation_path
    assert_select "input[name=profile_photo]", count: 0
    company = Submission.create!(kind: "organisation", profile_version: 2, name: "Owner", email: "company@example.test",
      organisation_name: "Orchard", mission: "Food", purpose: "Community", offering: "Fruit", challenge_kind: "Goals", challenge: "Grow", consent: "1")
    get profile_path(company.public_slug)
    assert_select ".profile-avatar", count: 0
  end
end
