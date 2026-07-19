# Test uploads use a real fixture file so the image/png content-type validation
# (active_storage_validations) actually passes. spec/fixtures/files/avatar.png is a
# minimal valid 1x1 PNG.
module ActiveStorageHelpers
  AVATAR_FIXTURE = Rails.root.join("spec/fixtures/files/avatar.png")

  NOTE_FIXTURE = Rails.root.join("spec/fixtures/files/note.txt")

  # A multipart-style uploaded file for attaching in specs.
  def avatar_upload(content_type: "image/png")
    Rack::Test::UploadedFile.new(AVATAR_FIXTURE, content_type)
  end

  # A genuinely non-image upload — Active Storage identifies text/plain from the
  # real bytes, so it actually trips the content-type validation (a PNG renamed
  # to text/plain would be re-identified as image/png and slip through).
  def non_image_upload
    Rack::Test::UploadedFile.new(NOTE_FIXTURE, "text/plain")
  end
end

RSpec.configure do |config|
  config.include ActiveStorageHelpers

  # blob.url needs a host to build absolute URLs; in request specs this comes from
  # the controller, but unit specs have no request — provide one.
  config.before do
    ActiveStorage::Current.url_options = { host: "http://test.host" }
  end
end
