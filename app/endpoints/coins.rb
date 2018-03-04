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
