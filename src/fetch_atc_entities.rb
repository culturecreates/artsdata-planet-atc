#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'uri'
require 'date'
require 'base64'
require 'logger'
require_relative 'add_attributes'
require_relative 'filter_tour_bookings'

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

# Configuration
# The API_BASE_URL can be overridden with environment variable
API_BASE_URL = 'https://arts-tc.ca/'
OUTPUT_DIR = 'json'


# Source to filename mapping
SOURCE_MAP = {
  'artist' => 'artists',
  'network' => 'networks',
  'presenter' => 'presenters',
  'performance-space' => 'performance-spaces',
  'representative' => 'representatives',
  'show' => 'shows',
  'tour-booking' => 'tour-bookings',
  'genre' => 'genres',
  'category' => 'categories'
}



def fetch_data(source, api_key)
  all_data = []
  offset = 0
  
  loop do
    url = URI("#{API_BASE_URL}#{source}?page%5Boffset%5D=#{offset}")
    LOGGER.info "Fetching #{source} with offset #{offset}"
    LOGGER.debug "URL: #{url}"
    
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(url)
    request['Authorization'] = "basic #{api_key}"
    
    response = http.request(request)
    
    unless response.is_a?(Net::HTTPSuccess)
      LOGGER.error "Error fetching #{source}: #{response.code} #{response.message}"
      LOGGER.debug "Response body: #{response.body}"
      break
    end
    
    begin
      data = JSON.parse(response.body)
    rescue JSON::ParserError => e
      LOGGER.error "Error parsing JSON for #{source}: #{e.message}"
      break
    end
    
    # Check if data is empty
    if data['data'].nil? || data['data'].empty?
      LOGGER.info "No more data for #{source}"
      break
    end
    
    all_data.concat(data['data'])
    offset += 50
  end
  
  all_data
end


def save_json(source, data)
  json_data = { 'data' => data }
  File.write("#{OUTPUT_DIR}/#{source}.json", JSON.pretty_generate(json_data))
  LOGGER.info "Saved #{data.length} records to #{OUTPUT_DIR}/#{source}.json"
end

def main
  # Parse command line arguments for token
  atc_event_token_arg = ARGV.find { |arg| arg.start_with?('--token=') }
  atc_event_token = atc_event_token_arg ? atc_event_token_arg.split('=', 2)[1] : nil
  
  unless atc_event_token
    LOGGER.fatal "Error: No ATC event token provided"
    LOGGER.fatal "Usage: ruby #{__FILE__} --token=your_base64_encoded_key"
    exit 1
  end
  
  LOGGER.info "Using API: #{API_BASE_URL}"
  LOGGER.debug "Output directory: #{OUTPUT_DIR}"
  
  # Create output directory
  Dir.mkdir(OUTPUT_DIR) unless Dir.exist?(OUTPUT_DIR)
  
  SOURCE_MAP.each do |source, file_name|
    LOGGER.info "=========================================="
    LOGGER.info "Processing #{file_name}"
    LOGGER.info "=========================================="
    
    # Fetch data from API
    data = fetch_data(source, atc_event_token)
    
    if data.empty?
      LOGGER.warn "Warning: No data fetched for #{source}"
      next
    end
    
    LOGGER.debug "Fetched #{data.length} records for #{source}"
    
    # Apply filter and add event status for tour-bookings
    if source == 'tour-booking'
      LOGGER.info "Applying filter to tour-bookings..."
      data = Artsdata::TourBookings.filter_tour_bookings(data, LOGGER)
      
      if data.empty?
        LOGGER.warn "Warning: All tour-bookings were filtered out!"
      else
        LOGGER.info "Adding event status URIs..."
        data = Artsdata::Attributes.add_event_status(data, LOGGER)
      end
    end
    
    # Save JSON file
    save_json(source, data)
    
    LOGGER.info "✓ Completed #{file_name}"
  end
  
  LOGGER.info "=========================================="
  LOGGER.info "All entities fetched successfully!"
  LOGGER.info "=========================================="
end

# Run the script only if executed directly (not when required for testing)
if __FILE__ == $PROGRAM_NAME
  main
end