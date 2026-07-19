FactoryBot.define do
  factory :role do
    sequence(:name) { |n| "role_#{n}" }
    description { "A role" }

    trait :admin do
      name { "admin" }
      after(:create) do |role|
        %w[users roles permissions].each do |resource|
          %w[read write delete].each do |action|
            role.permissions << Permission.find_or_create_by!(resource: resource, action: action)
          end
        end
      end
    end

    trait :member do
      name { "member" }
      after(:create) do |role|
        %w[read write].each do |action|
          role.permissions << Permission.find_or_create_by!(resource: "users", action: action)
        end
      end
    end
  end
end
