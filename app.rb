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
      raise Ki::ApiError.new("Version #{params['version']} does not support this API call")
    end
  end
end

class Api < Ki::Model
  def after_all
    validate_version

    json = JSON.parse(File.read(File.join('public', 'api', params['version'], 'all.json')))

    if params['select'].present?
      coins = params['select'].is_a?(Array) ? params['select'] : params['select'].split(',')
      coins.uniq!
      json['markets'] = json['markets'].select { |coin| coins.include? coin['symbol'] }
    elsif params['page'].present?
      page = params['page'].to_i
      page = 0 if page <= 0

      size = params['size'].to_i
      size = 20 if size <= 0

      json['total_pages'] = json['markets'].size / size
      json['markets'] = json['markets'].reverse.slice(page * size, size) || []
      json['current_page'] = page
      json['current_size'] = size
    else
      raise Ki::ApiError.new("Params missing. Either use ('select') OR ('page' " \
                             "and 'size'). Default page = 0, default size = 20, " \
                             "select accepts a comma separated list of coin " \
                             "symbols.")
    end

    @result = json
  end
end

class Ticker < Api
end

# Used to list all coins
class Coins < Ki::Model
  def after_all
    validate_version
    @result = Dir["public/api/#{params['version']}/*.json"].map { |e| e.split('/').last.split('.').first }.sort
  end
end
