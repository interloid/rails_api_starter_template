require "rails_helper"

RSpec.describe UserPolicy do
  subject(:policy) { described_class.new(actor, record) }

  let(:record) { create(:user) }

  describe "admin" do
    let(:actor) { create(:user, :admin) }

    it "permits every action, including update on any record and destroy" do
      expect(policy.index?).to be(true)
      expect(policy.show?).to be(true)
      expect(policy.create?).to be(true)
      expect(policy.update?).to be(true)   # any record
      expect(policy.destroy?).to be(true)
    end
  end

  describe "member" do
    let(:actor) { create(:user, :member) }

    it "permits index and show" do
      expect(policy.index?).to be(true)
      expect(policy.show?).to be(true)
    end

    it "forbids destroy" do
      expect(policy.destroy?).to be(false)
    end

    context "when the record is the member's own account" do
      let(:record) { actor }

      it "permits update" do
        expect(policy.update?).to be(true)
      end
    end

    context "when the record is another user" do
      it "forbids update" do
        expect(policy.update?).to be(false)
      end
    end
  end

  describe "a user with no roles" do
    let(:actor) { create(:user) }

    it "denies everything by default" do
      expect(policy.index?).to be(false)
      expect(policy.show?).to be(false)
      expect(policy.create?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.destroy?).to be(false)
    end
  end

  describe "Scope" do
    subject(:resolved) { described_class::Scope.new(actor, User.all).resolve }

    let!(:kept)      { create(:user) }
    let!(:discarded) { create(:user, :discarded) }

    context "with users:read permission" do
      let(:actor) { create(:user, :member) }

      it "resolves to kept users only (excludes discarded)" do
        expect(resolved).to include(kept)
        expect(resolved).not_to include(discarded)
      end
    end

    context "without users:read permission" do
      let(:actor) { create(:user) }

      it "resolves to none" do
        expect(resolved).to be_empty
      end
    end
  end
end
