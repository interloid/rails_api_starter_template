module Api
  module V1
    class BaseController < ApplicationController
      include Paginatable
      include Authenticatable   # every v1 endpoint requires auth by default
      include Pundit::Authorization

      # Pundit needs to know who the user is.
      def pundit_user = current_user
    end
  end
end
