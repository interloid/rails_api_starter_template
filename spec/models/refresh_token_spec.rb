require "rails_helper"

RSpec.describe RefreshToken do
  let(:user) { create(:user) }

  describe ".issue!" do
    it "returns [record, raw] and stores only the SHA-256 digest" do
      record, raw = described_class.issue!(user: user)

      expect(record).to be_persisted
      expect(raw).to be_a(String).and be_present
      # Raw token is never stored; only its digest is.
      expect(record.token_digest).to eq(described_class.digest(raw))
      expect(record.token_digest).not_to eq(raw)
      expect(described_class.where(token_digest: raw)).to be_empty
    end
  end

  describe ".find_by_raw" do
    it "locates a token by its raw value via the digest" do
      record, raw = described_class.issue!(user: user)
      expect(described_class.find_by_raw(raw)).to eq(record)
    end
  end

  describe "#active?" do
    it "is true for a fresh token" do
      expect(create(:refresh_token, user: user)).to be_active
    end

    it "is false when expired" do
      expect(create(:refresh_token, :expired, user: user)).not_to be_active
    end

    it "is false when revoked" do
      expect(create(:refresh_token, :revoked, user: user)).not_to be_active
    end
  end

  describe "#revoke!" do
    it "sets revoked_at" do
      token = create(:refresh_token, user: user)
      expect { token.revoke! }.to change(token, :revoked_at).from(nil)
    end
  end

  describe "#revoke_family!" do
    it "revokes all unrevoked tokens in the family, leaving other families untouched" do
      family = SecureRandom.uuid
      a = create(:refresh_token, user: user, family_id: family)
      b = create(:refresh_token, user: user, family_id: family)
      other = create(:refresh_token, user: user, family_id: SecureRandom.uuid)

      a.revoke_family!

      expect(a.reload.revoked_at).to be_present
      expect(b.reload.revoked_at).to be_present
      expect(other.reload.revoked_at).to be_nil
    end
  end

  describe ".active scope" do
    it "excludes expired and revoked tokens" do
      fresh   = create(:refresh_token, user: user)
      create(:refresh_token, :expired, user: user)
      create(:refresh_token, :revoked, user: user)

      expect(described_class.active).to contain_exactly(fresh)
    end
  end
end
