require "rails_helper"

RSpec.describe User do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to allow_value("a@b.com").for(:email) }
    it { is_expected.not_to allow_value("not-an-email").for(:email) }

    it "validates case-insensitive uniqueness of email" do
      create(:user, email: "taken@example.com")
      dup = build(:user, email: "TAKEN@example.com")
      expect(dup).not_to be_valid
      expect(dup.errors[:email]).to be_present
    end

    it "rejects passwords shorter than 8 characters" do
      user = build(:user, password: "short")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
  end

  describe "email normalization" do
    it "strips surrounding whitespace and downcases" do
      user = create(:user, email: "  MixedCase@Example.COM  ")
      expect(user.email).to eq("mixedcase@example.com")
    end
  end

  describe "#full_name" do
    it "joins first and last name" do
      expect(build(:user, first_name: "Ada", last_name: "Lovelace").full_name).to eq("Ada Lovelace")
    end

    it "returns nil when both names are blank" do
      expect(build(:user, first_name: nil, last_name: nil).full_name).to be_nil
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:user_roles).dependent(:destroy) }
    it { is_expected.to have_many(:roles).through(:user_roles) }
    it { is_expected.to have_many(:permissions).through(:roles) }
  end

  describe "RBAC" do
    let(:admin)  { create(:user, :admin) }
    let(:member) { create(:user, :member) }

    it "reports role membership" do
      expect(admin.role?("admin")).to be(true)
      expect(member.role?("admin")).to be(false)
    end

    it "grants users:write to admin and member, users:delete only to admin" do
      expect(admin.permission?("users:write")).to be(true)
      expect(member.permission?("users:write")).to be(true)
      expect(admin.permission?("users:delete")).to be(true)
      expect(member.permission?("users:delete")).to be(false)
    end

    it "memoizes permission_names so the DB is queried once" do
      member.reload
      queries = count_queries { 3.times { member.permission_names } }
      expect(queries).to eq(1)
    end
  end

  describe "Lockable" do
    it "increments failed_attempts and locks at MAX_FAILED_ATTEMPTS" do
      user = create(:user)
      (User::MAX_FAILED_ATTEMPTS - 1).times { user.register_failed_attempt! }
      expect(user).not_to be_locked
      user.register_failed_attempt!
      expect(user.failed_attempts).to eq(User::MAX_FAILED_ATTEMPTS)
      expect(user).to be_locked
    end

    it "is locked within LOCK_DURATION and unlocked afterwards" do
      user = create(:user, :locked)
      expect(user).to be_locked
      travel_to(User::LOCK_DURATION.from_now + 1.second) do
        expect(user).not_to be_locked
      end
    end

    it "clears failed_attempts and locked_at on reset" do
      user = create(:user, :locked)
      user.reset_failed_attempts!
      expect(user.failed_attempts).to eq(0)
      expect(user.locked_at).to be_nil
      expect(user).not_to be_locked
    end

    it "does not extend an active lock on repeated failures (no indefinite lock)" do
      user = create(:user, :locked)
      locked_at = user.locked_at
      travel_to(5.minutes.from_now) do
        user.register_failed_attempt!
        user.register_failed_attempt!
      end
      expect(user.reload.locked_at).to eq(locked_at)
      expect(user.failed_attempts).to eq(User::MAX_FAILED_ATTEMPTS)
    end

    it "starts a fresh window after the lock expires instead of re-locking immediately" do
      user = create(:user, :locked)
      travel_to(User::LOCK_DURATION.from_now + 1.second) do
        user.register_failed_attempt!
        expect(user).not_to be_locked
        expect(user.failed_attempts).to eq(1)
        expect(user.locked_at).to be_nil
      end
    end
  end

  describe "Trackable" do
    it "increments the count and shifts current sign-in into last" do
      user = create(:user)
      first_time = 2.days.ago.change(usec: 0)
      user.update!(current_sign_in_at: first_time, current_sign_in_ip: "1.1.1.1")

      user.track_sign_in!("2.2.2.2")

      expect(user.sign_in_count).to eq(1)
      expect(user.last_sign_in_at).to eq(first_time)
      expect(user.last_sign_in_ip).to eq("1.1.1.1")
      expect(user.current_sign_in_ip).to eq("2.2.2.2")
    end
  end

  describe "soft delete" do
    it "removes the user from .kept but keeps the row" do
      user = create(:user)
      user.discard!
      expect(described_class.kept).not_to include(user)
      expect(described_class.find(user.id)).to eq(user)
    end
  end

  describe "Confirmable" do
    it "reports and sets confirmation" do
      user = create(:user)
      expect(user).not_to be_confirmed
      user.confirm!
      expect(user).to be_confirmed
    end
  end

  describe "token invalidation" do
    it "invalidates the password_reset token once the password changes" do
      user = create(:user)
      token = user.generate_token_for(:password_reset)
      expect(described_class.find_by_token_for(:password_reset, token)).to eq(user)

      user.update!(password: "NewPassword123!")
      expect(described_class.find_by_token_for(:password_reset, token)).to be_nil
    end

    it "invalidates the email_confirmation token once confirmed" do
      user = create(:user)
      token = user.generate_token_for(:email_confirmation)
      expect(described_class.find_by_token_for(:email_confirmation, token)).to eq(user)

      user.confirm!
      expect(described_class.find_by_token_for(:email_confirmation, token)).to be_nil
    end
  end

  describe "avatar validations" do
    it "rejects a non-image content type" do
      user = create(:user)
      user.avatar.attach(
        io: StringIO.new("not an image"),
        filename: "note.txt",
        content_type: "text/plain"
      )
      expect(user).not_to be_valid
      expect(user.errors[:avatar]).to be_present
    end

    it "rejects a file larger than 5MB" do
      user = create(:user)
      user.avatar.attach(
        io: StringIO.new("x" * 6.megabytes),
        filename: "huge.png",
        content_type: "image/png"
      )
      expect(user).not_to be_valid
      expect(user.errors[:avatar]).to be_present
    end
  end
end
