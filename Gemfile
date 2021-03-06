source 'https://rubygems.org'

gem 'sinatra'
gem 'sinatra-contrib', require: false
gem 'sinatra-activerecord', '~> 2.0'
gem 'rack-contrib'

# Remove this git reference after version > 1.5.2 is released
gem 'rack-protection', :git => 'git://github.com/rkh/rack-protection.git'

gem 'activerecord', '~> 4.0', :require => 'active_record'
gem 'activesupport', '~> 4.0'
gem 'rails-observers', '~> 0.1', require: false
gem 'pg', '~> 0.17'
gem 'omniauth', '~> 1.1.4'
gem 'omniauth-twitter', :git => 'git://github.com/arunagw/omniauth-twitter.git'
gem 'omniauth-facebook', '~> 1.4.1'
gem 'omniauth-contrib', '~> 1.0.0', :git => 'git://github.com/intridea/omniauth-contrib.git'
gem 'omniauth-oauth', '~> 1.0.1', :git => 'git://github.com/intridea/omniauth-oauth.git'
gem 'omniauth-oauth2', '~> 1.1.0', :git => 'git://github.com/intridea/omniauth-oauth2.git'
gem 'omniauth-origo', '~> 1.0.0.rc3', :git => 'git://github.com/bengler/omniauth-origo.git'
gem 'omniauth-vanilla', :git => 'git://github.com/bengler/omniauth-vanilla.git'
gem 'omniauth-evernote'
gem 'omniauth-google-oauth2', '~> 0.1.10'
gem 'pebblebed', ">=0.2.0"
gem 'pebbles-uid'
gem 'pebbles-cors', :git => 'git://github.com/bengler/pebbles-cors.git'
gem 'pebbles-path', '>=0.0.3'
gem 'yajl-ruby', :require => 'yajl'
gem 'dalli', '~> 2.1.0'
gem 'thor'
gem 'petroglyph'
gem 'rake'
gem 'queryparams'
gem 'simpleidn', '~> 0.0.4'
gem 'rest-client', :require => false  # Used by origo.thor
gem 'ar-tsvectors', '~> 1.0', :require => 'activerecord_tsvectors'
gem 'curb', '>= 0.7.14'

group :development, :test do
  gem 'simplecov'
  gem 'rspec', '~> 2.8'
  gem 'webmock', '~> 1.8.11'
  gem 'vcr'
  gem 'timecop', '~> 0.3.5'
  gem 'rack-test'
  gem "memcache_mock"
end

group :production do
  gem 'airbrake', '~> 3.1.4', :require => false
  gem 'unicorn'
end
