class Saturn < ApiEndpoint
  def after_all
    @result = cache_fs_read('public/api/v8/history/saturn.json')
  rescue => e
    @result = { error: e.class, text: e.to_s }
  end
end
