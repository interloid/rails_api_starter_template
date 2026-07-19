require "swagger_helper"

RSpec.describe "Users API", type: :request do
  path "/api/v1/users" do
    get "List users" do
      tags "Users"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :page, in: :query, schema: { type: :integer }, required: false
      parameter name: :per_page, in: :query, schema: { type: :integer }, required: false

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
end
