module AuthHelpers
  def access_token_for(user) = JwtService.encode_access(user)
  def auth_header_for(user) = "Bearer #{access_token_for(user)}"
end

RSpec.configure { |c| c.include AuthHelpers }
