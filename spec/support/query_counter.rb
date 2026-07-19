# Counts real SQL queries executed inside the block (ignores schema/cache queries).
# Used to prove memoization actually hits the DB only once.
module QueryCounter
  IGNORED = /\A(?:PRAGMA|SHOW|BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|TRANSACTION)/i

  def count_queries
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached]
      next if payload[:sql].match?(IGNORED)

      count += 1
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end
end

RSpec.configure do |config|
  config.include QueryCounter
end
