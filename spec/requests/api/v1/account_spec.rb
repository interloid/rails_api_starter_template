require "swagger_helper"

RSpec.describe "Account API", type: :request do
  path "/api/v1/account/forgot_password" do
    post "Request a password reset" do
      tags "Account"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object, properties: { email: { type: :string } }, required: %w[email]
      }

      response "200", "generic message (existing email)" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        before { create(:user, email: "known@example.com") }

        let(:body) { { email: "known@example.com" } }
        run_test! { |resp| expect(JSON.parse(resp.body)["success"]).to be true }
      end

      response "200", "generic message (nonexistent email — no enumeration)" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:body) { { email: "nobody@example.com" } }
        run_test! { |resp| expect(JSON.parse(resp.body)["success"]).to be true }
      end
    end
  end

  path "/api/v1/account/reset_password" do
    post "Reset the password with a token" do
      tags "Account"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { token: { type: :string }, password: { type: :string } },
        required: %w[token password]
      }

      response "200", "password reset" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:user) { create(:user) }
        let(:body) { { token: user.generate_token_for(:password_reset), password: "NewPassword123!" } }
        run_test! { |resp| expect(JSON.parse(resp.body)["success"]).to be true }
      end

      response "422", "invalid token" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:body) { { token: "bad-token", password: "NewPassword123!" } }
        run_test! { |resp| expect(JSON.parse(resp.body)["error_code"]).to eq("invalid_token") }
      end
    end
  end

  path "/api/v1/account/confirm_email" do
    post "Confirm the email with a token" do
      tags "Account"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object, properties: { token: { type: :string } }, required: %w[token]
      }

      response "200", "email confirmed" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:user) { create(:user) }
        let(:body) { { token: user.generate_token_for(:email_confirmation) } }
        run_test! { |resp| expect(JSON.parse(resp.body)["success"]).to be true }
      end

      response "422", "invalid token" do
        schema "$ref" => "#/components/schemas/ErrorResponse"
        let(:body) { { token: "bad-token" } }
        run_test! { |resp| expect(JSON.parse(resp.body)["error_code"]).to eq("invalid_token") }
      end
    end
  end

  path "/api/v1/account/resend_confirmation" do
    post "Resend the confirmation email" do
      tags "Account"
      consumes "application/json"
      produces "application/json"
      parameter name: :body, in: :body, schema: {
        type: :object, properties: { email: { type: :string } }, required: %w[email]
      }

      response "200", "generic message" do
        schema "$ref" => "#/components/schemas/SuccessResponse"
        let(:body) { { email: "someone@example.com" } }
        run_test! { |resp| expect(JSON.parse(resp.body)["success"]).to be true }
      end
    end
  end
end
