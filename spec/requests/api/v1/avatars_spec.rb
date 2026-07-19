require "swagger_helper"

RSpec.describe "Avatars API", type: :request do
  path "/api/v1/users/{id}/avatar" do
    parameter name: :id, in: :path, schema: { type: :string }

    put "Upload an avatar (multipart)" do
      tags "Avatars"
      consumes "multipart/form-data"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :avatar, in: :formData, schema: { type: :string, format: :binary }

      response "200", "avatar uploaded (own record, PNG)" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:user) { create(:user, :member) }
        let(:id) { user.id }
        let(:Authorization) { auth_header_for(user) }
        let(:avatar) { avatar_upload }
        run_test! do |response|
          expect(JSON.parse(response.body)["data"]["avatar_url"]).to be_present
        end
      end

      response "422", "invalid content type" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:user) { create(:user, :member) }
        let(:id) { user.id }
        let(:Authorization) { auth_header_for(user) }
        let(:avatar) { non_image_upload }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("validation_failed")
        end
      end

      response "403", "forbidden (another user's avatar)" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:user) { create(:user, :member) }
        let(:other) { create(:user) }
        let(:id) { other.id }
        let(:Authorization) { auth_header_for(user) }
        let(:avatar) { avatar_upload }
        run_test! do |response|
          expect(JSON.parse(response.body)["error_code"]).to eq("forbidden")
        end
      end
    end

    delete "Remove the avatar" do
      tags "Avatars"
      produces "application/json"
      security [ bearerAuth: [] ]

      response "200", "avatar removed" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:user) { create(:user, :member) }
        let(:id) { user.id }
        let(:Authorization) { auth_header_for(user) }
        before { user.avatar.attach(avatar_upload) }

        run_test! { |resp| expect(JSON.parse(resp.body)["success"]).to be true }
      end
    end
  end

  path "/api/v1/users/{id}/avatar_presign" do
    parameter name: :id, in: :path, schema: { type: :string }

    post "Create a presigned direct-upload URL" do
      tags "Avatars"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          filename: { type: :string }, byte_size: { type: :integer },
          checksum: { type: :string }, content_type: { type: :string }
        },
        required: %w[filename byte_size checksum content_type]
      }

      response "200", "presigned upload created" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:user) { create(:user, :member) }
        let(:id) { user.id }
        let(:Authorization) { auth_header_for(user) }
        let(:body) do
          { filename: "avatar.png", byte_size: 70, checksum: "dGVzdA==", content_type: "image/png" }
        end
        run_test! do |response|
          data = JSON.parse(response.body)["data"]
          expect(data).to include("signed_id", "direct_upload")
          expect(data["direct_upload"]).to include("url", "headers")
        end
      end
    end
  end
end
