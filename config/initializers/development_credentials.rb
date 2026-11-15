# Refuse to start the server in production while an account still has the development password.
# Skipped for rake tasks (for example asset precompilation in the image build), which run without a server.
Rails.application.config.after_initialize do
  DevelopmentCredentials.check_production! if defined?(Rails::Server)
end
