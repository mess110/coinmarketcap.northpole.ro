require 'spec_helper'

describe 'script' do
  let(:v8) { 'public/api/v8' }

  describe 'single file' do
    let(:path) { "#{v8}/bitcoin.json" }
    let(:keys) { ['availableSupply', 'category', 'change1h', 'change24h',
                  'change7d', 'identifier', 'marketCap', 'name', 'position',
                  'price', 'symbol', 'timestamp', 'volume24'].sort }

    it 'has v8 bitcoin' do
      expect(File.exist?(path)).to be true
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

    it 'has the correct types' do
      expect(coin['position']).to be_a Integer
      expect(coin['name']).to be_a String
      expect(coin['symbol']).to be_a String
      expect(coin['identifier']).to be_a String
      expect(coin['category']).to be_a String
      expect(coin['marketCap']).to be_a Hash
      expect(coin['marketCap']['usd']).to be_a Float
      expect(coin['marketCap']['btc']).to be_a Float
      expect(coin['price']).to be_a Hash
      expect(coin['price']['usd']).to be_a Float
      expect(coin['price']['btc']).to be_a Float
      expect(coin['availableSupply']).to be_a Integer
      expect(coin['volume24']).to be_a Hash
      expect(coin['volume24']['usd']).to be_a Float
      expect(coin['volume24']['btc']).to be_a Float
      expect(coin['change1h']).to be_a Float
      expect(coin['change24h']).to be_a Float
      expect(coin['change7d']).to be_a Float
      expect(coin['timestamp']).to be_a Integer
    end
  end

  describe 'history' do
    let(:path) { "#{v8}/history/bitcoin_#{Time.now.year}.json" }
    let(:keys) { ['symbol', 'identifier', 'history'].sort }

    it 'has v8 bitcoin history' do
      expect(File.exist?(path)).to be true
    end

    it 'has all the keys' do
      expect(coin_history.keys.sort).to eq keys
    end

    it 'has the correct types' do
      expect(coin_history['symbol']).to eq 'BTC'
      expect(coin_history['identifier']).to eq 'bitcoin'
      expect(coin_history['history']).to be_a Hash
    end
  end
end
