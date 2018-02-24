require 'spec_helper'

describe 'script' do
  let(:keys) { ['availableSupply', 'category', 'change1h', 'change24h', 'change7d', 'identifier', 'marketCap', 'name', 'position', 'price', 'symbol', 'timestamp', 'volume24'].sort }
  let(:v8) { 'public/api/v8' }
  let(:bitcoin_path) { "#{v8}/bitcoin.json" }
  let(:bitcoin_history_path) { "#{v8}/history/bitcoin_#{Time.now.year}.json" }

  it 'has v8 bitcoin' do
    expect(File.exist?(bitcoin_path)).to be true
  end

  it 'has v8 bitcoin history' do
    expect(File.exist?(bitcoin_history_path)).to be true
  end

  it 'has all the keys' do
    expect(coin.keys.sort).to eq keys
  end

  it 'has values for keys' do
    coin.keys.each do |key|
      expect(coin[key]).to_not be_nil
    end
    expect(coin['identifier']).to eq 'bitcoin'
  end
end
