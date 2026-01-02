#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'uri'
require 'date'
require 'base64'
require 'logger'
require_relative 'add_attributes'

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

def filter_tour_bookings(data)
  today = Date.today
  count_before = data.length
  LOGGER.info "Tour-bookings before filter: #{count_before}"
  LOGGER.info "Today's date: #{today}"
  
  status_counts = Hash.new(0)
  
  filtered_data = data.select do |booking|
    attributes = booking['attributes'] || {}
    
    # Get status
    status = attributes['status']
    status_counts[status] += 1
    
    # Skip if status is "in_progress"
    if status == 'in_progress'
      LOGGER.debug "  Filtering out booking (status: in_progress): #{attributes['nid']}"
      next false
    end
    
    # Get event_date and disclosure
    event_date_str = attributes['event_date']
    season = attributes["season"]
    
    disclosure_days = case season
                      when Hash
                        season["disclosure"].to_i
                      when Array
                        season.first.is_a?(Hash) ? season.first["disclosure"].to_i : 90
                      else
                        90
                      end
    
    # If no event_date or no disclosure, include by default
    if event_date_str.nil? || event_date_str.empty?
      LOGGER.debug "  Including booking (no event_date): #{attributes['nid']}"
      next true
    end
    
    if disclosure_days == 0
      LOGGER.debug "  Including booking (no disclosure): #{attributes['nid']}"
      next true
    end
    
    begin
      # Parse event date (assuming ISO format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
      event_date = Date.parse(event_date_str.split('T')[0])
      
      # Calculate disclosure deadline: event_date - disclosure_days
      disclosure_deadline = event_date - disclosure_days
      
      # Include if disclosure_deadline > today
      include = disclosure_deadline > today
      
      LOGGER.debug "  Booking #{attributes['nid']}: event=#{event_date}, disclosure=#{disclosure_days}d, deadline=#{disclosure_deadline}, today=#{today}, include=#{include}"
      
      include
    rescue ArgumentError => e
      LOGGER.info "Warning: Could not parse date '#{event_date_str}': #{e.message}"
      true # Include by default if date parsing fails
    end
  end
  
  count_after = filtered_data.length
  LOGGER.info "Status breakdown before filtering:"
  status_counts.each { |status, count| LOGGER.info "  #{status}: #{count}" }
  LOGGER.info "Tour-bookings after filter: #{count_after}"
  LOGGER.info "Filtered out: #{count_before - count_after} tour-bookings"
  
  filtered_data
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
      data = filter_tour_bookings(data)
      
      if data.empty?
        LOGGER.warn "Warning: All tour-bookings were filtered out!"
      else
        LOGGER.info "Adding event status URIs..."
        data = add_event_status(data, LOGGER)
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