require 'ki'

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  def present?
    !blank?
  end
end

class Ki::Model
  forbid :create, :update, :delete

  def self.annotations
    {}
  end

  def allowed_versions
    %w(v5 v6 v8)
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

class Ticker < Ki::Model
  def self.annotations
    {
      params: ['version']
    }
  end

  def after_all
    validate_version
    t_version = params['version'] == 'v8' ? 'v6' : params['version']

    json = JSON.parse(File.read(File.join('public', 'api', t_version, 'all.json')))
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

class Api < Ticker
  def self.annotations
    nil
  end
end

class History < Ki::Model
  def self.allowed_versions
    %w(v6 v7 v8)
  end

  def allowed_versions
    History::allowed_versions
  end

  def valid_formats
    %w(array hash)
  end

  def coin_symbols_dir
    if params['version'] == 'v7'
      'public/api/v6/*.json'
    else
      "public/api/#{params['version']}/*.json"
    end
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
      t_version = params['version'] == 'v7' ? 'v6' : params['version']
      json = JSON.parse(File.read(File.join('public', 'api', t_version, 'history', "#{params['coin']}_#{params['year']}.json")))

      if ['v7', 'v8'].include?(params['version'])
        if params['format'] == 'array'
          history = []

          json['history'].keys.each do |day|
            json['history'][day]['date'] = day
            history.push json['history'][day]
          end

          json['history'] = history
        end
      end

    rescue Errno::ENOENT
      raise Ki::ApiError.new("No history for #{params['coin']} in year #{params['year']}")
    end

    @result = json
  end
end

class Coins < Ki::Model
  def after_all
    validate_version

    coins = coin_symbols.map do |coin_symbol|
      coin_info = {
        ticker: "/ticker.json?select=#{coin_symbol}&version=#{params['version']}",
        history: "/history.json?coin=#{coin_symbol}&year=2017",
        last14Days: "/history.json?coin=#{coin_symbol}&period=14days"
      }
      if params['version'] == 'v8'
        coin_info[:identifier] = coin_symbol
      else
        coin_info[:symbol] = coin_symbol
      end

      coin_info
    end

    @result = {
      coins: coins,
      tickerVersions: allowed_versions,
      historyVersions: History::allowed_versions
    }
  end
end
