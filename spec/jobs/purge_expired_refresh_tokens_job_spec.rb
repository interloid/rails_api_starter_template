require "rails_helper"

RSpec.describe PurgeExpiredRefreshTokensJob do
  let(:user) { create(:user) }

  it "deletes expired tokens and long-revoked tokens, keeping active and recently-revoked ones" do
    active          = create(:refresh_token, user: user)
    expired         = create(:refresh_token, :expired, user: user)
    long_revoked    = create(:refresh_token, user: user, revoked_at: 8.days.ago)
    recently_revoked = create(:refresh_token, :revoked, user: user)

    expect { described_class.perform_now }.to change(RefreshToken, :count).by(-2)

    expect(RefreshToken.exists?(active.id)).to be(true)
    expect(RefreshToken.exists?(recently_revoked.id)).to be(true)
    expect(RefreshToken.exists?(expired.id)).to be(false)
    expect(RefreshToken.exists?(long_revoked.id)).to be(false)
  end
end
