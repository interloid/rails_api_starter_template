require "rails_helper"

# A1: a newly registered user must receive the default role so their own permission
# checks pass (previously they got zero roles and 403'd on their own profile).
RSpec.describe "Registration default role", type: :request do
  it "assigns the member role and lets the new user fetch their own profile" do
    create(:role, :member) # the role register looks up must exist in the DB

    post_json "/api/v1/auth/register",
              params: { email: "fresh@example.com", password: "Password123!",
                        first_name: "Fresh", last_name: "User" }
    expect(response).to have_http_status(:created)

    new_user = User.find_by(email: "fresh@example.com")
    expect(new_user.role?("member")).to be(true)

    get "/api/v1/users/#{new_user.id}",
        headers: { "Authorization" => auth_header_for(new_user) }
    expect(response).to have_http_status(:ok)
    expect(json_body["data"]["id"]).to eq(new_user.id)
  end
end
