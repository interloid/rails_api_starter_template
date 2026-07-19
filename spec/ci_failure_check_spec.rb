require "rails_helper"

# ⚠️ INTENTIONAL FAILURE — CI smoke test only.
# This spec exists solely to confirm the CI `test` job goes red when a spec fails.
# DELETE this file once the failing build has been verified.
RSpec.describe "CI failure smoke test" do # rubocop:disable RSpec/DescribeClass
  it "fails on purpose to prove CI catches failing specs" do
    expect(1 + 1).to eq(3)
  end
end
