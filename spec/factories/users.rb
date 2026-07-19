FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password123!" }
    first_name { Faker::Name.first_name }
    last_name { Faker::Name.last_name }

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :discarded do
      discarded_at { Time.current }
    end

    trait :locked do
      failed_attempts { User::MAX_FAILED_ATTEMPTS }
      locked_at { Time.current }
    end

    trait :with_avatar do
      after(:create) do |user|
        user.avatar.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/avatar.png")),
          filename: "avatar.png",
          content_type: "image/png"
        )
      end
    end

    # find-or-create the role so multiple admins/members in one example don't collide
    # on the unique role name (roles :admin/:member traits also seed their permissions).
    trait :admin do
      after(:create) { |user| user.roles << (Role.find_by(name: "admin") || create(:role, :admin)) }
    end

    trait :member do
      after(:create) { |user| user.roles << (Role.find_by(name: "member") || create(:role, :member)) }
    end
  end
end
