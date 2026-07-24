module ExceptionHandler
  extend ActiveSupport::Concern

  included do
    rescue_from StandardError,                      with: :handle_internal_error
    rescue_from ActiveRecord::RecordNotFound,       with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid,        with: :handle_record_invalid
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
    rescue_from Pundit::NotAuthorizedError,         with: :handle_forbidden

    # A forgotten authorize/policy_scope is a security bug, not a 500. Registered
    # after StandardError (rescue_from is last-registered-wins) so it takes precedence.
    rescue_from Pundit::AuthorizationNotPerformedError, with: :handle_authorization_missing
    rescue_from Pundit::PolicyScopingNotPerformedError, with: :handle_authorization_missing

    # Malformed JSON body (or other unparseable params) — keep the JSON envelope
    # instead of leaking Rails' default 400 HTML/error page.
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_parse_error

    # An unrecognised sort/filter field is a client error (400), not a 500. Registered
    # after StandardError (last-registered-wins) so it takes precedence.
    rescue_from ApplicationQuery::InvalidQueryParameter, with: :handle_invalid_query
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

  def handle_forbidden(_exception)
    render_error(message: "You are not authorized to perform this action",
                 error_code: "forbidden", status: :forbidden)
  end

  def handle_authorization_missing(exception)
    Rails.logger.error("Authorization not performed: #{exception.class}")
    render_error(message: "Authorization not performed", error_code: "authorization_missing",
                 status: :forbidden)
  end

  def handle_parse_error(_exception)
    render_error(message: "Malformed request body", error_code: "malformed_json",
                 status: :bad_request)
  end

  def handle_invalid_query(exception)
    render_error(message: exception.message, error_code: "invalid_query_parameter",
                 status: :bad_request)
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
