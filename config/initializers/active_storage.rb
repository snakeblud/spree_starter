Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy
Rails.application.config.active_storage.variant_processor = :vips

# Configure URL options for Active Storage to prevent port numbers in URLs
# This runs after initialization to override default behavior
Rails.application.config.after_initialize do
  ActiveStorage::Current.url_options = {
    host: ENV['HOST'],
    protocol: 'https',
    port: nil
  }
end
