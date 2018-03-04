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
