# IMPORTANT: This file is generated by cucumber-rails - edit at your own peril.
# It is recommended to regenerate this file in the future when you upgrade to a
# newer version of cucumber-rails. Consider adding your own code to a new file
# instead of editing this one. Cucumber will automatically load all features/**/*.rb
# files.

require 'cucumber/rails'

require 'capybara/cucumber'
require 'capybara/poltergeist'
require 'capybara/accessible'

Mongoid.logger.level = Logger::INFO
Mongo::Logger.logger.level = Logger::INFO

if ENV['IN_BROWSER']
  # On demand: non-headless tests via Selenium/WebDriver
  # To run the scenarios in browser (default: Firefox), use the following command line:
  # IN_BROWSER=true bundle exec cucumber
  # or (to have a pause of 1 second between each step):
  # IN_BROWSER=true PAUSE=1 bundle exec cucumber
  # FIXME this doesn't work yet
  Capybara.default_driver = :selenium
  AfterStep do
    sleep(ENV['PAUSE'] || 0).to_i
  end
else
  Capybara.default_driver    = :accessible_poltergeist
  Capybara.javascript_driver = :accessible_poltergeist
end

Capybara.default_max_wait_time = 5
Capybara.ignore_hidden_elements = false

# Capybara defaults to CSS3 selectors rather than XPath.
# If you'd prefer to use XPath, just uncomment this line and adjust any
# selectors in your step definitions to use the XPath syntax.
# Capybara.default_selector = :xpath

# By default, any exception happening in your Rails application will bubble up
# to Cucumber so that your scenario will fail. This is a different from how
# your application behaves in the production environment, where an error page will
# be rendered instead.
#
# Sometimes we want to override this default behaviour and allow Rails to rescue
# exceptions and display an error page (just like when the app is running in production).
# Typical scenarios where you want to do this is when you test your error pages.
# There are two ways to allow Rails to rescue exceptions:
#
# 1) Tag your scenario (or feature) with @allow-rescue
#
# 2) Set the value below to true. Beware that doing this globally is not
# recommended as it will mask a lot of errors for you!
#
ActionController::Base.allow_rescue = false

# Remove/comment out the lines below if your app doesn't have a database.
# For some databases (like MongoDB and CouchDB) you may need to use :truncation instead.
begin
  DatabaseCleaner[:mongoid].strategy = :truncation
rescue NameError
  raise 'You need to add database_cleaner to your Gemfile (in the :test group) if you wish to use it.'
end

# You may also want to configure DatabaseCleaner to use different strategies for certain features and scenarios.
# See the DatabaseCleaner documentation for details. Example:
#
#   Before('@no-txn,@selenium,@culerity,@celerity,@javascript') do
#     # { :except => [:widgets] } may not do what you expect here
#     # as Cucumber::Rails::Database.javascript_strategy overrides
#     # this setting.
#     DatabaseCleaner.strategy = :truncation
#   end
#
#   Before('~@no-txn', '~@selenium', '~@culerity', '~@celerity', '~@javascript') do
#     DatabaseCleaner.strategy = :transaction
#   end
#

# Possible values are :truncation and :transaction
# The :transaction strategy is faster, but might give you threading problems.
# See https://github.com/cucumber/cucumber-rails/blob/master/features/choose_javascript_database_strategy.feature
Cucumber::Rails::Database.javascript_strategy = :truncation

# Make these rules throw errors instead of warnings.
# Rules list: https://github.com/GoogleChrome/accessibility-developer-tools/wiki/Audit-Rules
Capybara::Accessible::Auditor.severe_rules = %w(
  'AX_COLOR_01',
  'AX_FOCUS_01',
  'AX_FOCUS_02',
  'AX_FOCUS_03',
  'AX_VIDEO_01',
  'AX_ARIA_06',
  'AX_ARIA_07',
  'AX_ARIA_11',
  'AX_ARIA_13',
  'AX_HTML_01',
  'AX_TITLE_01',
  'AX_TEXT_04'
)

# to allow CSS and Javascript to be loaded when we use save_and_open_page, the
# development server must be running at localhost:3000 as specified below or
# wherever you want. See original issue here:
# https://github.com/jnicklas/capybara/pull/609
# and final resolution here:
# https://github.com/jnicklas/capybara/pull/958
Capybara.asset_host = 'http://localhost:3000'

# # # # # # # # # # #
#   H E L P E R S   #
# # # # # # # # # # #

def collection_fixtures(*collections)
  collections.each do |collection|
    Mongoid.default_client[collection].drop
    Dir.glob(File.join(Rails.root, 'test', 'fixtures', collection, '*.json')).each do |json_fixture_file|
      fixture_json = JSON.parse(File.read(json_fixture_file), max_nesting: 250)
      map_bson_ids(fixture_json)
      Mongoid.default_client[collection].insert_one(fixture_json)
    end
  end
end

def value_or_bson(v)
  if v.is_a? Hash
    if v['$oid']
      BSON::ObjectId.from_string(v['$oid'])
    else
      map_bson_ids(v)
    end
  else
    v
  end
end

def map_bson_ids(json)
  json.each_pair do |k, v|
    if v.is_a? Hash
      json[k] = value_or_bson(v)
    elsif k == 'create_at' || k == 'updated_at'
      json[k] = Time.at.utc(v)
      # json[k] = v
    end
  end
  json
end

Before do
  Mongoid.default_client['users'].drop
  Mongoid.default_client['vendors'].drop
  Mongoid.default_client['products'].drop
  Mongoid.default_client['product_tests'].drop

  collection_fixtures('patient_cache', 'records', 'bundles', 'measures')
end
