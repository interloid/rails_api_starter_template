require "rails_helper"

RSpec.describe JwtService do
  let(:user) { create(:user) }

  describe ".encode_access / .decode" do
    it "produces a token that decodes to the user's id in sub" do
      token = described_class.encode_access(user)
      payload = described_class.decode(token)
      expect(payload["sub"]).to eq(user.id)
      expect(payload["type"]).to eq("access")
    end
  end

  describe ".decode failure modes" do
    it "raises InvalidToken for an expired token" do
      token = described_class.encode_access(user)
      travel_to(described_class::ACCESS_TTL.from_now + 1.second) do
        expect { described_class.decode(token) }.to raise_error(described_class::InvalidToken)
      end
    end

    it "raises InvalidToken for a tampered signature" do
      token = described_class.encode_access(user)
      tampered = "#{token}tamper"
      expect { described_class.decode(tampered) }.to raise_error(described_class::InvalidToken)
    end

    it "raises InvalidToken when the token type is not \"access\"" do
      refresh_like = JWT.encode(
        { sub: user.id, exp: 1.hour.from_now.to_i, type: "refresh" },
        described_class.secret,
        described_class::ALGORITHM
      )
      expect { described_class.decode(refresh_like) }.to raise_error(described_class::InvalidToken, /token type/)
    end
  end

  describe "access-token denylist (opt-in)" do
    # The test env uses :null_store, which silently drops writes, so the denylist can't
    # work there. Swap in a real memory store for these examples only.
    around do |example|
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
      Rails.cache = original
    end

    def payload_for(token) = JWT.decode(token, described_class.secret, true, algorithm: described_class::ALGORITHM).first

    context "when the flag is OFF (default)" do
      it "decodes a token whose jti was 'revoked' — behaviour stays stateless" do
        token = described_class.encode_access(user)
        described_class.revoke_jti!(payload_for(token)["jti"], payload_for(token)["exp"])
        expect { described_class.decode(token) }.not_to raise_error
      end
    end

    context "when the flag is ON" do
      before { stub_const("JwtService::DENYLIST_ENABLED", -> { true }) }

      it "rejects a token whose jti has been revoked" do
        token = described_class.encode_access(user)
        p = payload_for(token)
        described_class.revoke_jti!(p["jti"], p["exp"])
        expect { described_class.decode(token) }.to raise_error(described_class::InvalidToken, /revoked/)
      end

      it "rejects all tokens issued before a user-wide cutoff" do
        token = described_class.encode_access(user)
        travel_to(1.second.from_now) { described_class.revoke_all_for!(user.id) }
        expect { described_class.decode(token) }.to raise_error(described_class::InvalidToken, /revoked/)
      end

      it "still accepts a token issued AFTER the cutoff" do
        described_class.revoke_all_for!(user.id)
        later_token = travel_to(1.second.from_now) { described_class.encode_access(user) }
        expect { described_class.decode(later_token) }.not_to raise_error
      end
    end
  end
end
