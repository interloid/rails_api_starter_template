module ExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError,                      with: :handle_internal_error
    rescue_from ActiveRecord::RecordNotFound,       with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid,        with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  end

  private

  def handle_not_found(exception)
    render_error(message: "Record not found", error_code: "not_found",
                 errors: [ { message: exception.message } ], status: :not_found)
  end

  def handle_record_invalid(exception)
    errors = exception.record.errors.map { |e| { field: e.attribute.to_s, message: e.message } }
    render_error(message: "Validation failed", error_code: "validation_failed",
                 errors: errors, status: :unprocessable_entity)
  end

  def handle_parameter_missing(exception)
    render_error(message: "Required parameter missing", error_code: "parameter_missing",
                 errors: [ { field: exception.param.to_s, message: "is required" } ], status: :bad_request)
  end

  def handle_internal_error(exception)
    raise exception unless Rails.env.production?   # let dev see the full error/backtrace

    Rails.logger.error("#{exception.class}: #{exception.message}")
    Rails.logger.error(Array(exception.backtrace).first(20).join("\n"))
    NewRelic::Agent.notice_error(exception) if defined?(NewRelic)

    render_error(message: "Something went wrong", error_code: "internal_server_error",
                 status: :internal_server_error)
  end
end
