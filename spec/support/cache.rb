# Rate limits and sign-in protection use the cache, so each example starts with an empty cache.
RSpec.configure do |config|
  config.before(:each) { Rails.cache.clear }
end
