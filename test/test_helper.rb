require 'json'
require 'yaml'

module FixtureHelper
  def load_fixture(name)
    path = File.join(__dir__, 'fixtures', name)
    JSON.parse(File.read(path))
  end
end
