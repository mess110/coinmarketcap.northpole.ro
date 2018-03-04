require 'ki'

# root = ::File.dirname(__FILE__)
# logfile = ::File.join(root,'logs','requests.log')
# $logger  = ::Logger.new(logfile,'weekly')

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  def present?
    !blank?
  end
end

module CacheManagement
  def digest key
    Digest::SHA1.hexdigest key
  end

  # If the filesystem timestamp changes we override the item in the cache
  def cache_fs_read path
    # return JSON.parse(File.read(path))
    key = digest(path)

    new_mtime = File.mtime(path).to_i

    item = MongoCache.find(key: key).first

    if item.nil? || item['ts'] != new_mtime
      MongoCache.delete(key: key)
      item = MongoCache.create(key: key, path: path, ts: new_mtime, item: JSON.parse(File.read(path)))
    end

    item['item'] || item[:item]
  end

  def add_to_cache path, item
    key = digest(path)
    MongoCache.delete(key: key)
    MongoCache.create(key: key, path: path, item: item, ts: Time.now.to_i)
  end

  def get_from_cache path, hours
    key = digest(path)
    item = MongoCache.find(key: key).first
    return if item.nil?
    return if item['ts'] + hours * 60 * 60 < Time.now.to_i
    item['item']
  end
end

class Ki::Model
  include CacheManagement

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

class MongoCache < Ki::Model
  forbid :find, :create, :update, :delete
end

class ApiEndpoint < Ki::Model
  def find
    # overrwrite so we don't use mongo at all
  end
end

class Ticker < ApiEndpoint
  def after_all
    validate_version
    t_version = params['version']

    json = cache_fs_read(File.join('public', 'api', t_version, 'all', 'all.json'))
    json['markets'] = json['markets'].reverse

    if params['select'].present?
      coins = params['select'].is_a?(Array) ? params['select'] : params['select'].split(',')
      coins.uniq!
      json['markets'] = json['markets'].select { |coin| coins.include? coin['symbol'] }
    end

    if params['symbol'].present?
      coins = params['symbol'].is_a?(Array) ? params['symbol'] : params['symbol'].split(',')
      coins.uniq!
      json['markets'] = json['markets'].select { |coin| coins.include? coin['symbol'] }
    end

    if params['identifier'].present?
      coins = params['identifier'].is_a?(Array) ? params['identifier'] : params['identifier'].split(',')
      coins.uniq!
      json['markets'] = json['markets'].select { |coin| coins.include? coin['identifier'] }
    end

    if params['page'].present?
      page = params['page'].to_i
      page = 0 if page <= 0

      size = params['size'].to_i
      size = 20 if size <= 0

      json['total_pages'] = json['markets'].size / size
      json['markets'] = json['markets'].slice(page * size, size) || []
      json['prev_page'] = page >= 1 ? "/ticker.json?version=#{params['version']}&page=#{page - 1}&size=#{size}" : nil
      json['next_page'] = page < json['total_pages'] ? "/ticker.json?version=#{params['version']}&page=#{page + 1}&size=#{size}" : nil
      json['current_page'] = page
      json['current_size'] = size
    end

    @result = json
  end
end

class History < ApiEndpoint
  def self.allowed_versions
    %w(v8)
  end

  def allowed_versions
    History::allowed_versions
  end

  def valid_formats
    %w(array hash)
  end

  def coin_symbols_dir
    "public/api/#{params['version']}/*.json"
  end

  def validate_format
    if params['format'].present?
      unless valid_formats.include?(params['format'])
        raise Ki::ApiError.new("Invalid format. Valid formats are #{valid_formats.join(', ')}")
      end
    else
      params['format'] = 'array'
    end
  end

  def validate_year
    params['year'] = params['period']
    if params['year'].blank?
      params['year'] = Time.new.year
    else
      if params['year'] != '14days'
        if params['year'].to_s.size != 4 || params['year'].to_s != params['year'].to_i.to_s
          raise Ki::ApiError.new("Invalid year #{params['year']}")
        end
      end
    end
  end

  def validate_symbols
    unless coin_symbols.include?(params['coin'])
      raise Ki::ApiError.new("Invalid coin '#{params['coin']}'. See '/coins.json' for valid coins")
    end
  end

  def after_all
    validate_version
    validate_format
    validate_symbols
    validate_year

    begin
      t_version = params['version']
      json = cache_fs_read(File.join('public', 'api', t_version, 'history', "#{params['coin']}_#{params['year']}.json"))

      if params['format'] == 'array' && params['year'] != '14days'
        history = []

        json['history'].keys.each do |day|
          json['history'][day]['date'] = day
          history.push json['history'][day]
        end

        json['history'] = history
      end

    rescue Errno::ENOENT
      raise Ki::ApiError.new("No history for #{params['coin']} in year #{params['year']}")
    end

    @result = json
  end
end

class Coins < ApiEndpoint
  CACHE_KEY = 'coins.json'

  def after_all
    validate_version

    from_cache = get_from_cache CACHE_KEY, 12 # hour

    if from_cache.nil?
      all_history = Dir["public/api/#{params['version']}/history/*.json"]

      coins = coin_symbols.map do |coin_symbol|
        {
          ticker: "/ticker.json?identifier=#{coin_symbol}&version=#{params['version']}",
          history: "/history.json?coin=#{coin_symbol}&period=2017",
          last14Days: "/history.json?coin=#{coin_symbol}&period=14days",
          identifier: coin_symbol,
          periods: all_history.select { |e| e.include?("/history/#{coin_symbol}_") }.map { |e| e.split('_').last.split('.').first }
        }
      end

      @result = {
        coins: coins,
        tickerVersions: allowed_versions,
        historyVersions: History::allowed_versions
      }

      add_to_cache(CACHE_KEY, @result)
    else
      @result = from_cache
    end
  end
end

class Saturn < ApiEndpoint
  def after_all
    @result = cache_fs_read('public/api/v8/history/saturn.json')
  rescue => e
    @result = { error: e.class, text: e.to_s }
  end
end
