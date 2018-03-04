module NoCache
  def cache_fs_read path
    return JSON.parse(File.read(path))
  end

  def add_to_cache path, item
  end

  def get_from_cache path, hours
  end
end
