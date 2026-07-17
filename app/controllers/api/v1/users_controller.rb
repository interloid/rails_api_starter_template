module Api
  module V1
    class UsersController < BaseController
      def index
        authorize User                                   # -> UserPolicy#index?
        scope = policy_scope(User).includes(:roles).order(created_at: :desc)
        pagy, users = paginate(scope)
        render_success(UserSerializer.many(users), message: "Users retrieved successfully",
                       pagination_meta: pagination_meta(pagy))
      end

      def show
        user = User.kept.includes(:roles).find(params[:id])
        authorize user                                   # -> UserPolicy#show?
        render_success(UserSerializer.one(user), message: "User retrieved successfully")
      end

      def update
        user = User.kept.find(params[:id])
        authorize user                                   # -> UserPolicy#update? (record-level!)
        user.update!(user_params)
        render_success(UserSerializer.one(user), message: "User updated successfully")
      end

      def destroy
        user = User.kept.find(params[:id])
        authorize user                                   # -> UserPolicy#destroy? (admin only)
        user.discard!                                     # soft delete
        render_success(nil, message: "User deleted successfully")
      end

      private

      def user_params = params.permit(:first_name, :last_name)
    end
  end
end
