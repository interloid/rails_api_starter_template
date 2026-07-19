require "rails_helper"

RSpec.describe RoleSerializer do
  it "includes id, name, description, and permission names" do
    role = create(:role, :member, description: "Standard member")
    payload = described_class.one(role)

    expect(payload[:id]).to eq(role.id)
    expect(payload[:name]).to eq("member")
    expect(payload[:description]).to eq("Standard member")
    expect(payload[:permissions]).to contain_exactly("users:read", "users:write")
  end
end
