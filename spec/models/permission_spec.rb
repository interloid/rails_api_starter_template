require "rails_helper"

RSpec.describe Permission do
  describe "validations" do
    it { is_expected.to validate_presence_of(:resource) }
    it { is_expected.to validate_presence_of(:action) }

    it "validates uniqueness of the derived name" do
      create(:permission, resource: "users", action: "read")
      dup = build(:permission, resource: "users", action: "read")
      expect(dup).not_to be_valid
      expect(dup.errors[:name]).to be_present
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:role_permissions).dependent(:destroy) }
    it { is_expected.to have_many(:roles).through(:role_permissions) }
  end

  describe "auto-derived name" do
    it "sets name to \"resource:action\"" do
      permission = create(:permission, resource: "users", action: "read")
      # ⚠️ INTENTIONAL FAILURE — CI smoke test only. Real value is "users:read".
      # REVERT this to eq("users:read") once the failing build has been verified.
      expect(permission.name).to eq("users:write")
    end
  end
end
