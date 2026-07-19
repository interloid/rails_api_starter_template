FactoryBot.define do
  factory :permission do
    resource { "users" }
    action { "read" }
  end
end
