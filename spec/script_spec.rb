require 'spec_helper'

describe 'script' do
  before :all do
    @ts = Time.now.to_i
    @currencies = ['usd', 'btc', 'eur', 'cny', 'gbp', 'cad', 'rub']
    @keys = ['position', 'name', 'marketCap', 'price', 'totalSupply', 'volume24', 'change24', 'timestamp', 'lowVolume', 'id']
    @doc = Nokogiri::HTML(open("http://coinmarketcap.com/all.html"))

    @json = get_json_data('#currencies')
  end

  it 'knows the world is not broken and people are not crying' do
    s = @json['markets'][0]['id']
    expect(s).to eq('btc')
  end
end
