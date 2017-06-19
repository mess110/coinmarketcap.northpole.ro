require 'ki'

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  def present?
    !blank?
  end
end

class Api < Ki::Model
  forbid :create, :update, :delete

  def after_all
    json = JSON.parse(File.read(File.join('public', 'api', 'v6', 'all.json')))
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
