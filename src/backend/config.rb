require 'logger'
require 'ostruct'
require 'paint'
require 'redis'

env = ENV.fetch 'WOPR_ENV', 'development'
root_dir = File.expand_path File.join(File.dirname(__FILE__), '..', '..')
LOGGER = Logger.new STDOUT
REDIS_PREFIX = ENV.fetch 'WOPR_REDIS_PREFIX', 'wopr:'

CONFIG = OpenStruct.new

def connect_to_database
  redis_url = ENV.fetch 'WOPR_REDIS_URL', 'redis://localhost:6379/0'
  begin
    redis = Redis.new logger: LOGGER, url: redis_url
    redis.get redis_key(:foo)

    redis_uri = URI.parse redis_url
    redis_uri.userinfo = nil
    LOGGER.info Paint["Connected to Redis database at #{redis_uri}", :green]

    redis
  rescue StandardError => e
    LOGGER.error Paint["Could not connect to Redis at #{redis_url} (configure with $WOPR_REDIS_URL): #{e}", :red]
    exit 2
  end
end

def get_javascript_bundle
  unless File.directory? CONFIG.public_dir
    CONFIG.logger.error "Public directory #{CONFIG.public_dir} does not exist; use `npm run build` to build this project's web assets"
    exit 2
  end

  javascript_bundles = (Dir.entries(CONFIG.public_dir) - [ '.', '..' ]).select{ |f| f.match /\Abundle[^\s]*\.js\z/ }
  if javascript_bundles.length >= 2
    CONFIG.logger.error "Found multiple JavaScript bundles in the public directory: #{javascript_bundles.join ', '}; use `npm run build` to clean and rebuild"
    exit 2
  elsif javascript_bundles.empty?
    CONFIG.logger.error "No JavaScript bundle found in public directory #{CONFIG.public_dir}; use `npm run build` to build this project's web assets"
    exit 2
  else
    javascript_bundles.first
  end
end

def redis_key key
  "#{REDIS_PREFIX}#{key}"
end

$redis = connect_to_database

CONFIG.env = env
CONFIG.logger = LOGGER
CONFIG.public_dir = File.join root_dir, 'public'
CONFIG.redis_prefix = REDIS_PREFIX
CONFIG.root_dir = root_dir

CONFIG.cached_javascript_bundle = env === 'production' ? get_javascript_bundle : nil
