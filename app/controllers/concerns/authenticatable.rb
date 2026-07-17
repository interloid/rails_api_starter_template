module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  class_methods do
    # Public endpoints opt OUT of auth (the @Public() decorator equivalent).
    def allow_unauthenticated(**options)
      skip_before_action :authenticate_user!, **options
    end
  end

  private

  def authenticate_user!
    payload = JwtService.decode(bearer_token.to_s)
    @current_user = User.kept.find_by(id: payload["sub"])
    raise JwtService::InvalidToken, "user not found" if @current_user.nil?
  rescue JwtService::InvalidToken => e
    render_error(message: "Unauthorized", error_code: "unauthorized",
                 errors: [ { message: e.message } ], status: :unauthorized)
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    header.start_with?("Bearer ") ? header.split(" ", 2).last : nil
  end

  def current_user = @current_user
end
