require 'logger'
require 'redis'

redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
begin
  $redis = Redis.new(logger: Rails.logger, url: redis_url)
  $redis.get('wopr:foo')
rescue StandardError => e
  raise "Could not connect to Redis at #{redis_url} (configure with $REDIS_URL): #{e}"
end