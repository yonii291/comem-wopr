require 'json'
require 'paint'
require 'redis'

module WOPR
  def self.env
    ENV.fetch 'WOPR_ENV', 'development'
  end

  def self.development?
    self.env === 'production'
  end

  def self.production?
    self.env === 'production'
  end

  def self.ensure_database_connection!
    begin
      self.redis.get self.redis_key(:foo)

      redis_uri = URI.parse self.redis_url
      redis_uri.userinfo = nil
      self.logger.info Paint["Connected to Redis database at #{redis_uri}", :green]

      redis
    rescue StandardError => e
      self.logger.error Paint["Could not connect to Redis at #{redis_url} (configure with $WOPR_REDIS_URL): #{e}", :red]
      exit 2
    end
  end

  def self.javascript_bundle
    if self.production?
      @javascript_bundle ||= get_javascript_bundle
    else
      get_javascript_bundle
    end
  end

  def self.logger
    @logger ||= Logger.new STDOUT
  end

  def self.port
    return @port if @port
    p = ENV.fetch('WOPR_PORT', ENV.fetch('PORT', 4567)).to_i
    raise "$WOPR_PORT or $PORT must be a valid port number between 1 and 65,535" unless p >= 1 && p <= 65535
    @port = p
  end

  def self.redis
    @redis ||= Redis.new url: self.redis_url
  end

  def self.redis_key key
    "#{self.redis_prefix}#{key}"
  end

  def self.redis_prefix
    @redis_prefix ||= ENV.fetch 'WOPR_REDIS_PREFIX', 'wopr:'
  end

  def self.redis_url
    @redis_url ||= ENV.fetch 'WOPR_REDIS_URL', ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
  end

  def self.root_dir
    @root_dir ||= File.expand_path File.join(File.dirname(__FILE__), '..')
  end

  def self.public_dir
    @public_dir ||= File.join self.root_dir, 'public'
  end

  def self.version
    self::VERSION
  end

  private

  VERSION = JSON.parse(File.read(File.join(File.dirname(__FILE__), '..', 'package.json')))['version']

  def self.get_javascript_bundle
    unless File.directory? self.public_dir
      self.logger.error "Public directory #{self.public_dir} does not exist; use `npm run build` to build this project's web assets"
      exit 2
    end

    javascript_bundles = (Dir.entries(self.public_dir) - [ '.', '..' ]).select{ |f| f.match /\Abundle[^\s]*\.js\z/ }
    if javascript_bundles.length >= 2
      self.logger.error "Found multiple JavaScript bundles in the public directory: #{javascript_bundles.join ', '}; use `npm run build` to clean and rebuild"
      exit 2
    elsif javascript_bundles.empty?
      self.logger.error "No JavaScript bundle found in public directory #{self.public_dir}; use `npm run build` to build this project's web assets"
      exit 2
    else
      javascript_bundles.first
    end
  end
end

Dir[File.join File.dirname(__FILE__), File.basename(__FILE__, '.*'), '*.rb'].each{ |lib| require lib }