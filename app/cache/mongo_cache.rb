module MongoCache
  # If the filesystem timestamp changes we override the item in the cache
  def cache_fs_read path
    key = digest(path)

    new_mtime = File.mtime(path).to_i

    item = KiCache.find(key: key).first

    if item.nil? || item['ts'] != new_mtime
      KiCache.delete(key: key)
      item = KiCache.create(key: key, ts: new_mtime, item: JSON.parse(File.read(path)))
    end

    item['item'] || item[:item]
  end

  def add_to_cache path, item
    key = digest(path)
    KiCache.delete(key: key)
    KiCache.create(key: key, item: item, ts: Time.now.to_i)
  end

  def get_from_cache path, hours
    key = digest(path)
    item = KiCache.find(key: key).first
    return if item.nil?
    return if item['ts'] + hours * 60 * 60 < Time.now.to_i
    item['item']
  end

  private

  def digest key
    Digest::SHA1.hexdigest key
  end
end
