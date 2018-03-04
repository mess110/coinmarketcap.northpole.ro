require 'ki'

require './app/util.rb'
require './app/cache/mongo_cache.rb'
require './app/cache/no_cache.rb'

class Ki::Model
  include MongoCache
  # include NoCache

  forbid :create, :update, :delete

  def allowed_versions
    %w(v8)
  end

  def validate_version
    if params['version'].present?
      params['version'] = "v#{params['version']}" unless params['version'].start_with?('v')
    else
      params['version'] = 'v8'
    end

    unless allowed_versions.include?(params['version'])
      raise Ki::ApiError.new("Version '#{params['version']}' not supported. Valid versions are #{allowed_versions.join(', ')}")
    end
  end

  def coin_symbols
    Dir[coin_symbols_dir].map { |e| e.split('/').last.split('.').first }.sort
  end

  def coin_symbols_dir
    "public/api/#{params['version']}/*.json"
  end
end

class KiCache < Ki::Model
  forbid :find, :create, :update, :delete
end

class ApiEndpoint < Ki::Model
  def find
    # overrwrite so we don't use mongo at all
  end
end

require './app/endpoints/ticker.rb'
require './app/endpoints/history.rb'
require './app/endpoints/coins.rb'
require './app/endpoints/saturn.rb'
