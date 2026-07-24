require "swagger_helper"

RSpec.describe "Users API", type: :request do
  path "/api/v1/users" do
    get "List users" do
      tags "Users"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :page, in: :query, schema: { type: :integer }, required: false
      parameter name: :per_page, in: :query, schema: { type: :integer }, required: false
      # Allowlisted sort: "-" prefix = DESC, comma-separated for multiple fields
      # (e.g. "-created_at,email"). Unknown fields return 400 invalid_query_parameter.
      parameter name: :sort, in: :query, required: false, schema: { type: :string },
                description: 'Sort by allowlisted field(s). Prefix "-" for DESC, comma-separated. e.g. "-created_at,email"'
      parameter name: :q, in: :query, required: false, schema: { type: :string },
                description: "Case-insensitive search across email, first_name, last_name."
      # Allowlisted filters as filter[field]=value (deepObject). Partial fields match
      # case-insensitively; *_from / *_to bound a date range on a date field.
      parameter name: :filter, in: :query, required: false, style: :deepObject, explode: true,
                schema: {
                  type: :object,
                  properties: {
                    email: { type: :string }, first_name: { type: :string }, last_name: { type: :string },
                    created_at_from: { type: :string, format: :date }, created_at_to: { type: :string, format: :date },
                    confirmed_at_from: { type: :string, format: :date }, confirmed_at_to: { type: :string, format: :date }
                  }
                }

      response "200", "users listed" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:user) { create(:user, :admin) }
        let(:Authorization) { auth_header_for(user) }
        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body["success"]).to be true
          expect(body["pagination_meta"]).to include("total", "page", "records_per_page", "total_pages")
        end
      end

      response "400", "unknown sort or filter field" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:user) { create(:user, :admin) }
        let(:Authorization) { auth_header_for(user) }
        let(:sort) { "nope" }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("invalid_query_parameter")
        end
      end

      response "401", "unauthenticated" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path "/api/v1/users/{id}" do
    parameter name: :id, in: :path, schema: { type: :string }

    get "Fetch a user" do
      tags "Users"
      produces "application/json"
      security [ bearerAuth: [] ]

      response "200", "user found" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:user) { create(:user, :member) }
        let(:id) { user.id }
        let(:Authorization) { auth_header_for(user) }
        run_test!
      end

      response "404", "user not found" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:user) { create(:user, :member) }
        let(:id) { SecureRandom.uuid }
        let(:Authorization) { auth_header_for(user) }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("not_found")
        end
      end

      response "401", "unauthenticated" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:id) { SecureRandom.uuid }
        let(:Authorization) { nil }
        run_test!
      end
    end

    patch "Update a user" do
      tags "Users"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :changes, in: :body, schema: {
        type: :object,
        properties: { first_name: { type: :string }, last_name: { type: :string } }
      }

      response "200", "updated own record" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:user) { create(:user, :member) }
        let(:id) { user.id }
        let(:Authorization) { auth_header_for(user) }
        let(:changes) { { first_name: "Renamed" } }
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["first_name"]).to eq("Renamed")
        end
      end

      response "403", "forbidden (updating another user as member)" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:user) { create(:user, :member) }
        let(:other) { create(:user) }
        let(:id) { other.id }
        let(:Authorization) { auth_header_for(user) }
        let(:changes) { { first_name: "Nope" } }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("forbidden")
        end
      end
    end

    delete "Delete a user" do
      tags "Users"
      produces "application/json"
      security [ bearerAuth: [] ]

      response "200", "deleted (admin)" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:admin) { create(:user, :admin) }
        let(:target) { create(:user) }
        let(:id) { target.id }
        let(:Authorization) { auth_header_for(admin) }
        run_test!
      end

      response "403", "forbidden (member cannot delete)" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:member) { create(:user, :member) }
        let(:target) { create(:user) }
        let(:id) { target.id }
        let(:Authorization) { auth_header_for(member) }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("forbidden")
        end
      end
    end
  end

  # Regression (plain request specs — Bullet.raise = true makes an N+1 fail the request).
  # UserSerializer reads avatar_url AND roles, so index MUST eager-load both. With
  # multiple populated records these would N+1 without the includes in the controller.
  describe "GET /api/v1/users with attached avatars" do
    it "eager-loads avatars (no N+1) and returns every avatar_url" do
      create_list(:user, 3, :with_avatar)
      admin = create(:user, :admin, :with_avatar)

      get "/api/v1/users", headers: { "Authorization" => auth_header_for(admin) }

      expect(response).to have_http_status(:ok)
      avatar_urls = JSON.parse(response.body)["data"].map { |u| u["avatar_url"] }
      expect(avatar_urls).to all(be_present)
    end
  end

  describe "GET /api/v1/users with roles populated" do
    it "eager-loads roles (no N+1) and returns role names" do
      create_list(:user, 3, :member)
      admin = create(:user, :admin)

      get "/api/v1/users", headers: { "Authorization" => auth_header_for(admin) }

      expect(response).to have_http_status(:ok)
      roles = JSON.parse(response.body)["data"].map { |u| u["roles"] }
      expect(roles).to all(be_an(Array))
      expect(roles.flatten).to include("member")
    end
  end

  describe "GET /api/v1/users query layer" do
    let(:admin) { create(:user, :admin, email: "zadmin@example.com", first_name: "Zadmin") }

    def emails(response) = JSON.parse(response.body)["data"].map { |u| u["email"] }

    it "sorts ascending by email" do
      create(:user, email: "bravo@example.com")
      create(:user, email: "alpha@example.com")

      get "/api/v1/users?sort=email", headers: { "Authorization" => auth_header_for(admin) }

      expect(response).to have_http_status(:ok)
      returned = emails(response)
      expect(returned).to eq(returned.sort)
      expect(returned.first).to eq("alpha@example.com")
    end

    it "filters by exact email, returning just that user" do
      target = create(:user, email: "needle@example.com")
      create(:user, email: "haystack@example.com")

      get "/api/v1/users?filter[email]=needle@example.com",
          headers: { "Authorization" => auth_header_for(admin) }

      expect(response).to have_http_status(:ok)
      expect(emails(response)).to contain_exactly(target.email)
    end

    it "searches across searchable fields with ?q" do
      create(:user, email: "unrelated@example.com", first_name: "Bob")
      match = create(:user, email: "someone@example.com", first_name: "Ravindra")

      get "/api/v1/users?q=ravind", headers: { "Authorization" => auth_header_for(admin) }

      expect(response).to have_http_status(:ok)
      expect(emails(response)).to include(match.email)
      expect(emails(response)).not_to include("unrelated@example.com")
    end

    it "returns 400 invalid_query_parameter for an unknown sort field" do
      get "/api/v1/users?sort=nope", headers: { "Authorization" => auth_header_for(admin) }

      expect(response).to have_http_status(:bad_request)
      expect(JSON.parse(response.body)["error_code"]).to eq("invalid_query_parameter")
    end

    it "composes filtering with pagination — total reflects the FILTERED count" do
      create_list(:user, 3, first_name: "Filtered")
      create_list(:user, 2, first_name: "Other")

      get "/api/v1/users?filter[first_name]=Filtered&per_page=2",
          headers: { "Authorization" => auth_header_for(admin) }

      expect(response).to have_http_status(:ok)
      meta = JSON.parse(response.body)["pagination_meta"]
      expect(meta["total"]).to eq(3)           # filtered count, not the whole table
      expect(meta["records_per_page"]).to eq(2)
      expect(JSON.parse(response.body)["data"].size).to eq(2)
    end

    it "raises no Bullet N+1 with filters + search applied" do
      create_list(:user, 3, :with_avatar, first_name: "Searchable")

      get "/api/v1/users?filter[first_name]=Searchable&sort=-created_at",
          headers: { "Authorization" => auth_header_for(admin) }

      # Bullet.raise = true in test — an N+1 or unused eager-load would 500 this request.
      expect(response).to have_http_status(:ok)
    end
  end
end
