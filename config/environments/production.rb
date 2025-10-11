require "active_support/core_ext/integer/time"

# frozen_string_literal: true

Rails.application.configure do
  # Code is not reloaded between requests.
  config.cache_classes = true
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Use encrypted credentials if present.
  config.require_master_key = false

  # Static files and asset pipeline.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.assets.compile = false
  config.assets.digest = true

  # Logging
  config.log_level = :debug
  config.logger = ActiveSupport::Logger.new(STDOUT)
  config.log_tags = [:request_id]

  # Mailer
  config.action_mailer.perform_caching = false
  config.action_mailer.default_url_options = {
    host: ENV['HOST'],
    protocol: 'https',
    port: nil  # Explicitly remove port from URLs
  }

  # Active Storage
  config.active_storage.service = :amazon

  # Configure Active Storage to generate URLs without port numbers
  # This ensures URLs like https://doubleclick.systems/rails/active_storage/...
  # instead of https://doubleclick.systems:3000/rails/active_storage/...
  Rails.application.config.to_prepare do
    ActiveStorage::Current.url_options = {
      host: ENV['HOST'],
      protocol: 'https',
      port: nil  # Explicitly remove port from URLs
    }
  end

  # Set default URL options for Active Storage and action_controller
  Rails.application.routes.default_url_options = {
    host: ENV['HOST'],
    protocol: 'https',
    port: nil  # Explicitly remove port from URLs
  }

  config.action_controller.default_url_options = {
    host: ENV['HOST'],
    protocol: 'https',
    port: nil  # Explicitly remove port from URLs
  }

  # ------------------------------------------------------------------
  # âœ… SSL / HTTPS Enforcement
  # CloudFront terminates SSL, so Rails should not enforce SSL directly
  # We trust the X-Forwarded-Proto header from CloudFront/ALB
  # ------------------------------------------------------------------
  config.force_ssl = false
  config.assume_ssl = true  # For URL generation

  # ------------------------------------------------------------------
  # âœ… Allowed Hosts (fixes 403 Forbidden)
  # Disable host checking entirely for production since we're behind CloudFront/ALB
  # ------------------------------------------------------------------
  config.hosts.clear

  # Option 1: Allow all hosts (simplest for CloudFront/ALB setup)
  # This is safe because traffic is already filtered by CloudFront and ALB
  config.host_authorization = { exclude: ->(request) { true } }

  # ------------------------------------------------------------------
  # âœ… Session and Cookie Configuration for CloudFront/ALB
  # ------------------------------------------------------------------
  # Configure session store with proper cookie settings for HTTPS behind proxy
  config.session_store :cookie_store,
    key: '_spree_starter_session',
    same_site: :lax,
    httponly: true,
    secure: true,  # Set secure flag since users access via HTTPS
    domain: :all  # Allow cookies to work across subdomains and CloudFront

  # ------------------------------------------------------------------
  # I18n, Deprecation, and Logging
  # ------------------------------------------------------------------
  config.i18n.fallbacks = true
  config.active_support.deprecation = :notify
  config.log_formatter = ::Logger::Formatter.new
end
#
# Rails.application.configure do
#   config.enable_reloading = false
#   config.eager_load = true
#   config.consider_all_requests_local = false
#   config.action_controller.perform_caching = true
#   config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }
#   config.active_storage.service = :amazon
#
#   # SSL Configuration
#   config.force_ssl = true  # CloudFront terminates SSL, not Rails
#   config.assume_ssl = true  # But assume the connection is HTTPS for URL generation
#
#   # Allow requests from CloudFront and ALB origins in production
#   if ENV['HOST'].present?
#     config.hosts << ENV['HOST']                        # your Route 53 domain
#   end
#
#   # Allow ALB DNS (internal AWS traffic)
#   config.hosts << "spree-production-alb-XXXXXX.us-east-1.elb.amazonaws.com"
#
#   # Allow CloudFront domain (check your CloudFront Distribution â†’ Domain name)
#   config.hosts << "dXXXXXX.cloudfront.net"
#
#   # Allow local requests for health checks or debugging
#   config.hosts << "localhost"
#   config.hosts << "127.0.0.1"
#
#   # Email configuration
#   config.action_mailer.default_url_options = {
#     host: ENV["HOST"] || "doubleclick.systems",
#     protocol: 'https'
#   }
#
#   # Trust proxy headers from CloudFront/ALB
#   config.action_dispatch.trusted_proxies = [
#     '10.0.0.0/8',
#     '172.16.0.0/12',
#     '192.168.0.0/16'
#   ]
#
#   # Allow all hosts
#   config.hosts.clear
#   config.hosts << /./
#
#   config.log_tags = [ :request_id ]
#   config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
#   config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
#   config.silence_healthcheck_path = "/up"
#   config.active_support.report_deprecations = false
#
#   # Redis Cache Configuration
#   if ENV['REDIS_URL'].present?
#     config.cache_store = :redis_cache_store, {
#       url: ENV['REDIS_URL'],
#       connect_timeout: 30,
#       read_timeout: 0.2,
#       write_timeout: 0.2,
#       reconnect_attempts: 2,
#     }
#   else
#     config.cache_store = :memory_store
#   end
#
#   # Session Configuration
#   config.session_store :cache_store,
#     key: '_spree_session',
#     expire_after: 90.minutes
#
#   # URL Generation Configuration
#   if ENV["HOST"].present?
#     Rails.application.routes.default_url_options = {
#       host: ENV["HOST"],
#       protocol: "https"
#     }
#     config.action_controller.default_url_options = {
#       host: ENV["HOST"],
#       protocol: "https"
#     }
#     config.action_mailer.default_url_options = {
#       host: ENV["HOST"],
#       protocol: "https"
#     }
#   end
#
#   # SendGrid Configuration
#   if ENV['SENDGRID_API_KEY'].present?
#     config.action_mailer.smtp_settings = {
#       user_name: 'apikey',
#       password: ENV['SENDGRID_API_KEY'],
#       domain: ENV.fetch('SENDGRID_DOMAIN', ENV['HOST']),
#       address: 'smtp.sendgrid.net',
#       port: 587,
#       authentication: :plain,
#       enable_starttls_auto: true
#     }
#   end
#
#   config.i18n.fallbacks = true
#   config.active_record.dump_schema_after_migration = false
#   config.active_record.attributes_for_inspect = [ :id ]
# end