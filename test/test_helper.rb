require 'json'
require 'yaml'

module TestHelper
  def with_date(date)
    original_today = Date.method(:today)
    
    Date.define_singleton_method(:today) { date }
    
    yield
  ensure
    Date.define_singleton_method(:today) { original_today.call }
  end


  def load_fixture(name)
    path = File.join(__dir__, 'fixtures', name)
    JSON.parse(File.read(path))
  end
end
