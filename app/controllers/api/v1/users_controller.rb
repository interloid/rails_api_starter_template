module Api
  module V1
    class UsersController < BaseController
      # NOTE: unauthenticated for now — Section 8 adds JWT auth + RBAC to these actions.
      def index
        pagy, users = paginate(User.kept.includes(:roles).order(created_at: :desc))
        render_success(UserSerializer.many(users),
                       message: "Users retrieved successfully",
                       pagination_meta: pagination_meta(pagy))
      end

      def show
        user = User.kept.includes(:roles).find(params[:id])   # RecordNotFound -> 404 envelope
        render_success(UserSerializer.one(user), message: "User retrieved successfully")
      end
    end
  end
end
