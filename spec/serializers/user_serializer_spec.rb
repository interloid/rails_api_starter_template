require "rails_helper"

RSpec.describe UserSerializer do
  subject(:payload) { described_class.one(user) }

  let(:user) { create(:user, :member, first_name: "Ada", last_name: "Lovelace") }


  it "includes id, email, names, roles, and created_at" do
    expect(payload).to include(
      id: user.id,
      email: user.email,
      first_name: "Ada",
      last_name: "Lovelace",
      full_name: "Ada Lovelace",
      roles: %w[member],
      created_at: user.created_at.utc.iso8601
    )
  end

  it "never exposes password_digest" do
    expect(payload).not_to have_key(:password_digest)
    expect(payload.values).not_to include(user.password_digest)
  end

  describe "avatar_url" do
    it "is nil without an attachment" do
      expect(payload[:avatar_url]).to be_nil
    end

    it "is a URL when an avatar is attached" do
      user.avatar.attach(avatar_upload)
      expect(described_class.one(user)[:avatar_url]).to be_present
    end
  end
end
