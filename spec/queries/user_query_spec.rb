require "rails_helper"

RSpec.describe UserQuery do
  # Helper: run the query and materialise the resulting users.
  def query(params) = described_class.call(User.all, params).to_a

  describe "filtering" do
    it "matches an exact filter" do
      match = create(:user, email: "exact@example.com")
      create(:user, email: "other@example.com")

      expect(query(filter: { email: "exact@example.com" })).to contain_exactly(match)
    end

    it "matches a partial filter case-insensitively (substring)" do
      match = create(:user, first_name: "Ravindra")
      create(:user, first_name: "Bob")

      expect(query(filter: { first_name: "ravIND" })).to contain_exactly(match)
    end

    it "casts a boolean-style value for a boolean filter" do
      # No boolean column exists on users, so declare one inline and assert the generated
      # SQL binds a real boolean — proving "true"/"false" strings are cast, not interpolated.
      klass = Class.new(ApplicationQuery) { filterable(active: :boolean) }

      expect(klass.call(User.all, { filter: { active: "true" } }).to_sql).to match(/"active" = TRUE/i)
      expect(klass.call(User.all, { filter: { active: "false" } }).to_sql).to match(/"active" = FALSE/i)
    end

    it "bounds a date range inclusively with _from / _to" do
      old     = create(:user).tap { |u| u.update_column(:created_at, Time.zone.parse("2026-01-01")) }
      middle  = create(:user).tap { |u| u.update_column(:created_at, Time.zone.parse("2026-01-15")) }
      recent  = create(:user).tap { |u| u.update_column(:created_at, Time.zone.parse("2026-02-01")) }

      from_only = query(filter: { created_at_from: "2026-01-10" })
      expect(from_only).to contain_exactly(middle, recent)

      to_only = query(filter: { created_at_to: "2026-01-20" })
      expect(to_only).to contain_exactly(old, middle)

      ranged = query(filter: { created_at_from: "2026-01-10", created_at_to: "2026-01-20" })
      expect(ranged).to contain_exactly(middle)
    end

    it "raises InvalidQueryParameter for an invalid date" do
      expect { query(filter: { created_at_from: "not-a-date" }) }
        .to raise_error(ApplicationQuery::InvalidQueryParameter, /Invalid date/)
    end

    it "raises InvalidQueryParameter for an unknown filter field" do
      expect { query(filter: { nickname: "x" }) }
        .to raise_error(ApplicationQuery::InvalidQueryParameter, /Unknown filter field/)
    end
  end

  describe "search" do
    it "matches across every searchable field (OR)" do
      by_email = create(:user, email: "target@example.com", first_name: "AA", last_name: "BB")
      by_first = create(:user, email: "a@example.com", first_name: "Targetson", last_name: "CC")
      by_last  = create(:user, email: "b@example.com", first_name: "DD", last_name: "Targetsen")
      create(:user, email: "z@example.com", first_name: "None", last_name: "Nope")

      expect(query(q: "target")).to contain_exactly(by_email, by_first, by_last)
    end
  end

  describe "sorting" do
    it "sorts ascending by a bare field" do
      b = create(:user, email: "b@example.com")
      a = create(:user, email: "a@example.com")
      expect(query(sort: "email")).to eq([ a, b ])
    end

    it "sorts descending with a leading '-'" do
      a = create(:user, email: "a@example.com")
      b = create(:user, email: "b@example.com")
      expect(query(sort: "-email")).to eq([ b, a ])
    end

    it "applies multiple sort fields in order" do
      first_a = create(:user, first_name: "Amy",  email: "z@example.com")
      first_b = create(:user, first_name: "Amy",  email: "a@example.com")
      other   = create(:user, first_name: "Zed",  email: "m@example.com")

      # first_name asc, then email desc within the same first_name
      expect(query(sort: "first_name,-email")).to eq([ first_a, first_b, other ])
    end

    it "defaults to created_at desc with no sort param" do
      older  = create(:user).tap { |u| u.update_column(:created_at, 2.days.ago) }
      newer  = create(:user).tap { |u| u.update_column(:created_at, 1.hour.ago) }
      expect(query({})).to eq([ newer, older ])
    end

    it "raises InvalidQueryParameter for an unknown sort field" do
      expect { query(sort: "nope") }
        .to raise_error(ApplicationQuery::InvalidQueryParameter, /Unknown sort field/)
    end
  end

  describe "SQL injection resistance" do
    it "rejects a sort payload and leaves the users table intact" do
      create(:user)

      expect { query(sort: "created_at; DROP TABLE users") }
        .to raise_error(ApplicationQuery::InvalidQueryParameter)

      expect(ActiveRecord::Base.connection.table_exists?(:users)).to be(true)
      expect(User.count).to be >= 1
    end

    it "treats an injection payload in an exact filter as a literal value (no rows)" do
      create(:user, email: "real@example.com")

      expect(query(filter: { email: "' OR 1=1--" })).to be_empty
    end

    it "escapes LIKE metacharacters in a partial filter" do
      literal  = create(:user, first_name: "100%pure")
      create(:user, first_name: "ordinary")

      # "%" must match a literal percent, NOT act as a wildcard that returns everyone.
      result = query(filter: { first_name: "100%" })
      expect(result).to contain_exactly(literal)

      # "_" is also a LIKE metacharacter (single-char wildcard) and must be escaped.
      only_underscore = create(:user, first_name: "a_b")
      create(:user, first_name: "axb")
      expect(query(filter: { first_name: "a_b" })).to contain_exactly(only_underscore)
    end
  end
end
