root = ::File.dirname(__FILE__)
logfile = ::File.join(root, '..', 'logs','requests.log')
$logger  = ::Logger.new(logfile, 'weekly')

class Object
  def blank?
    respond_to?(:empty?) ? !!empty? : !self
  end

  def present?
    !blank?
  end
end
