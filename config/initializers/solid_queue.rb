# In-flight jobs get up to this long to finish on SIGTERM before release + re-run.
Rails.application.config.solid_queue.shutdown_timeout = 15 if Rails.application.config.respond_to?(:solid_queue)
