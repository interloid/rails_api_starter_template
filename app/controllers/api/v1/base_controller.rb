module Api
  module V1
    class BaseController < ApplicationController
      include Paginatable
      include Authenticatable   # every v1 endpoint requires auth by default
      include Pundit::Authorization

      before_action :set_active_storage_url_options

      # Fail loudly if an action forgets to authorize / scope, instead of silently
      # serving data. Individual public/self-scoped controllers skip verify_authorized.
      #
      # NOTE: guarded with action_name rather than only:/except: :index on purpose —
      # this app sets raise_on_missing_callback_actions = true, and naming :index in
      # only:/except: raises ActionNotFound on the controllers that legitimately have
      # no index action (Avatars, Auth, Account, Status). The :if/:unless form carries
      # the same semantics without validating action names.
      after_action :verify_authorized,    unless: -> { action_name == "index" }
      after_action :verify_policy_scoped, if: -> { action_name == "index" }

      # Pundit needs to know who the user is.
      def pundit_user = current_user

      private

      # Lets blob.url build absolute URLs for both S3 and local disk (the disk service
      # needs a host to point its /rails/active_storage/... redirect links at).
      def set_active_storage_url_options
        ActiveStorage::Current.url_options = { host: request.base_url }
      end
    end
  end
end
