module Renderable
  extend ActiveSupport::Concern

  def render_success(data = nil, message: "Success", status: :ok, pagination_meta: nil, meta_data: nil)
    payload = {
      success: true,
      status_code: Rack::Utils.status_code(status),
      message: message,
      data: data,
      pagination_meta: pagination_meta,
      meta_data: meta_data,
      timestamp: Time.now.utc.iso8601,
      path: request.path
    }.compact   # drops nil data/pagination_meta/meta_data; keeps the fixed keys
    render json: payload, status: status
  end

  def render_error(message:, error_code:, errors: [], status: :unprocessable_entity)
    payload = {
      success: false,
      status_code: Rack::Utils.status_code(status),
      error_code: error_code,
      message: message,
      errors: errors,
      timestamp: Time.now.utc.iso8601,
      path: request.path
    }
    render json: payload, status: status
  end
end
