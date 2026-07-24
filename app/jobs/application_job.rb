class ApplicationJob < ActiveJob::Base
  # Transient DB contention is worth retrying; a job referencing a deleted record
  # never will be, so discard it instead of retrying forever.
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  # Report failures to APM before re-raising so the queue still marks the job failed.
  rescue_from(StandardError) do |exception|
    Rails.logger.error("Job failed: #{self.class.name} — #{exception.class}: #{exception.message}")
    NewRelic::Agent.notice_error(exception) if defined?(::NewRelic)
    raise exception
  end
end
