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
end
