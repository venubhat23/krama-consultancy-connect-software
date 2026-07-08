# Set URL options for ActiveStorage - loaded last (zz prefix ensures it runs after Rails initialization)
if Rails.env.development?
  Rails.application.config.to_prepare do
    ActiveStorage::Current.url_options = {
      host: 'localhost',
      port: 3000,
      protocol: 'http'
    }
  end
end