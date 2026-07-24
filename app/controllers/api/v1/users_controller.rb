module Api
  module V1
    class UsersController < BaseController
      def index
        authorize User                                   # -> UserPolicy#index?
        # ORDER MATTERS: policy_scope first (a filter must never widen authorization),
        # then the allowlisted query layer, then pagination.
        scope = policy_scope(User).for_serialization
        scope = apply_query(scope, UserQuery)
        pagy, users = paginate(scope)
        render_success(UserSerializer.many(users), message: "Users retrieved successfully",
                       pagination_meta: pagination_meta(pagy))
      end

      def show
        user = User.kept.for_serialization.find(params[:id])
        authorize user                                   # -> UserPolicy#show?
        render_success(UserSerializer.one(user), message: "User retrieved successfully")
      end

      def update
        # Plain find (NOT for_serialization): authorize can deny (403) before we ever
        # serialize, which would make the eager load an unused one that Bullet rejects.
        # On success only ONE record is serialized, so roles/avatar are single-row reads.
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
