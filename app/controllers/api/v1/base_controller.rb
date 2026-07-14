module Api
  module V1
    class BaseController < ApplicationController
      include Paginatable
    end
  end
end
