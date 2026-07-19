FactoryBot.define do
  factory :refresh_token do
    user
    token_digest { RefreshToken.digest(SecureRandom.urlsafe_base64(48)) }
    family_id { SecureRandom.uuid }
    expires_at { RefreshToken::EXPIRY.from_now }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :revoked do
      revoked_at { 1.hour.ago }
    end
  end
end
