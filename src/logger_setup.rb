require 'logger'

# Logger setup
LOGGER = Logger.new($stdout)
if ENV['LOG_LEVEL']
  case ENV['LOG_LEVEL'].downcase
  when 'debug'
    LOGGER.level = Logger::DEBUG
  when 'info'
    LOGGER.level = Logger::INFO
  when 'warn'
    LOGGER.level = Logger::WARN
  when 'error'
    LOGGER.level = Logger::ERROR
  when 'fatal'
    LOGGER.level = Logger::FATAL
  else
    LOGGER.level = Logger::INFO
  end
else
  LOGGER.level = Logger::INFO
end
