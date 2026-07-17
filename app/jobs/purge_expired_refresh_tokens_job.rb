class PurgeExpiredRefreshTokensJob < ApplicationJob
  queue_as :default

  # Deletes refresh tokens that are expired OR were revoked more than 7 days ago.
  # Keeps the refresh_tokens table from growing unbounded (every login/rotation adds rows).
  def perform
    cutoff = 7.days.ago
    deleted = RefreshToken
              .where("expires_at < :now OR (revoked_at IS NOT NULL AND revoked_at < :cutoff)",
                     now: Time.current, cutoff: cutoff)
              .delete_all
    Rails.logger.info("PurgeExpiredRefreshTokensJob: deleted #{deleted} tokens")
  end
end
