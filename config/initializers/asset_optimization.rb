# Asset and frontend performance optimizations

Rails.application.configure do
  if Rails.env.production?
    # Enable gzip compression
    config.middleware.use Rack::Deflater

    # Set far future expires for static assets
    config.static_cache_control = "public, max-age=#{1.year.to_i}"

    # Enable asset compression and minification
    config.assets.compress = true
    config.assets.js_compressor = :terser
    config.assets.css_compressor = :sass

    # Precompile additional assets
    config.assets.precompile += %w[
      dashboard.js
      dashboard.css
      charts.js
      admin/application.css
    ]
  end

  # Development optimizations
  if Rails.env.development?
    # Cache asset compilation in development
    config.assets.cache_store = :file_store, Rails.root.join('tmp', 'cache', 'assets')
  end
end

# Configure HTTP caching headers for better browser caching
# Rack::Cache has been removed as it's not compatible with Rails 8
# Rails already provides good caching via static_cache_control setting above
#
# If you need additional caching, consider using:
# - Rails' built-in HTTP caching headers (config.static_cache_control)
# - CDN for static assets
# - Redis or Memcached for application-level caching