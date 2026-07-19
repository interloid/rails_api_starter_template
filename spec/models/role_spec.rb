require "rails_helper"

RSpec.describe Role do
  describe "validations" do
    subject { build(:role) }

    it { is_expected.to validate_presence_of(:name) }

    it "validates case-insensitive uniqueness of name" do
      create(:role, name: "editor")
      dup = build(:role, name: "EDITOR")
      expect(dup).not_to be_valid
      expect(dup.errors[:name]).to be_present
    end

    it "normalizes name (strip + downcase)" do
      expect(create(:role, name: "  Manager  ").name).to eq("manager")
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:role_permissions).dependent(:destroy) }
    it { is_expected.to have_many(:permissions).through(:role_permissions) }
    it { is_expected.to have_many(:user_roles).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:user_roles) }
  end
end
