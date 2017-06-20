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

  def allowed_versions
    %w(v5 v6)
  end

  def validate_version
    if params['version'].present?
      params['version'] = "v#{params['version']}" unless params['version'].start_with?('v')
    else
      params['version'] = 'v6'
    end

    unless allowed_versions.include?(params['version'])
      raise Ki::ApiError.new("Version '#{params['version']}' not supported. Valid versions are #{allowed_versions.join(', ')}")
    end
  end

  def coin_symbols
    Dir["public/api/#{params['version']}/*.json"].map { |e| e.split('/').last.split('.').first }.sort
  end
end

class Ticker < Ki::Model
  def after_all
    validate_version

    json = JSON.parse(File.read(File.join('public', 'api', params['version'], 'all.json')))
    json['markets'] = json['markets'].reverse

    if params['select'].present?
      coins = params['select'].is_a?(Array) ? params['select'] : params['select'].split(',')
      coins.uniq!
      json['markets'] = json['markets'].select { |coin| coins.include? coin['symbol'] }
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
end

class History < Ki::Model
  def after_all
    validate_version

    unless coin_symbols.include?(params['coin'])
      raise Ki::ApiError.new("Invalid coin '#{params['coin']}'. See '/coins.json' for valid coins")
    end

    if params['year'].blank?
      params['year'] = Time.new.year
    else
      if params['year'].to_s.size != 4 || params['year'].to_s != params['year'].to_i.to_s
        raise Ki::ApiError.new("Invalid year #{params['year']}")
      end
    end

    begin
      json = JSON.parse(File.read(File.join('public', 'api', params['version'], 'history', "#{params['coin']}_#{params['year']}.json")))
    rescue Errno::ENOENT
      raise Ki::ApiError.new("No history for #{params['coin']} in year #{params['year']}")
    end

    @result = json
  end
end

class Coins < Ki::Model
  def after_all
    validate_version
    @result = coin_symbols.map { |coin_symbol|
      {
        symbol: coin_symbol,
        ticker: "/ticker.json?select=#{coin_symbol}&version=#{params['version']}",
        history: "/history.json?coin=#{coin_symbol}&year=2017"
      }
    }
  end
end
