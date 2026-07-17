module Api
  module V1
    class BaseController < ApplicationController
      include Paginatable
      include Authenticatable   # every v1 endpoint requires auth by default
      include Pundit::Authorization

      before_action :set_active_storage_url_options

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
