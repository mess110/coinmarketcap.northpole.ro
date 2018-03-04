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
