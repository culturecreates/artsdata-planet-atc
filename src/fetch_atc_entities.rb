#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'uri'
require 'date'
require 'base64'

# Configuration
# The API_BASE_URL can be overridden with environment variable
API_BASE_URL = 'https://test-block-booking.pantheonsite.io/api'
OUTPUT_DIR = 'json'

atc_event_token_arg = ARGV.find { |arg| arg.start_with?('--token=') }
ATC_EVENT_TOKEN = atc_event_token_arg ? atc_event_token_arg.split('=', 2)[1] : nil
unless ATC_EVENT_TOKEN
  puts "no atc event token available, exiting"
  exit(1)
end

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

# Status mapping for event schema
# Maps ATC status values to schema.org event status URIs
STATUS_MAPPING = {
  'confirmed' => 'http://schema.org/EventScheduled',
  'closed' => 'http://schema.org/EventCancelled',
  'postponed' => 'http://schema.org/EventPostponed'
}

def fetch_data(source, api_key)
  all_data = []
  offset = 0
  
  loop do
    url = URI("#{API_BASE_URL}/#{source}?page%5Boffset%5D=#{offset}")
    puts "Fetching #{source} with offset #{offset}"
    puts "URL: #{url}" if ENV['DEBUG']
    
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(url)
    # Use Basic authentication with the API key
    request['Authorization'] = "basic #{api_key}"
    
    response = http.request(request)
    
    unless response.is_a?(Net::HTTPSuccess)
      puts "Error fetching #{source}: #{response.code} #{response.message}"
      if ENV['DEBUG']
        puts "Response body: #{response.body}"
      end
      break
    end
    
    begin
      data = JSON.parse(response.body)
    rescue JSON::ParserError => e
      puts "Error parsing JSON for #{source}: #{e.message}"
      break
    end
    
    # Check if data is empty
    if data['data'].nil? || data['data'].empty?
      puts "No more data for #{source}"
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
  puts "Tour-bookings before filter: #{count_before}"
  puts "Today's date: #{today}"
  
  status_counts = Hash.new(0)
  
  filtered_data = data.select do |booking|
    attributes = booking['attributes'] || {}
    
    # Get status
    status = attributes['status']
    status_counts[status] += 1
    
    # Skip if status is "in_progress"
    if status == 'in_progress'
      puts "  Filtering out booking (status: in_progress): #{attributes['nid']}" if ENV['DEBUG']
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
      puts "  Including booking (no event_date): #{attributes['nid']}" if ENV['DEBUG']
      next true
    end
    
    if disclosure_days == 0
      puts "  Including booking (no disclosure): #{attributes['nid']}" if ENV['DEBUG']
      next true
    end
    
    begin
      # Parse event date (assuming ISO format: YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
      event_date = Date.parse(event_date_str.split('T')[0])
      
      # Calculate disclosure deadline: event_date - disclosure_days
      disclosure_deadline = event_date - disclosure_days
      
      # Include if disclosure_deadline > today
      include = disclosure_deadline > today
      
      if ENV['DEBUG']
        puts "  Booking #{attributes['nid']}: event=#{event_date}, disclosure=#{disclosure_days}d, deadline=#{disclosure_deadline}, today=#{today}, include=#{include}"
      end
      
      include
    rescue ArgumentError => e
      puts "Warning: Could not parse date '#{event_date_str}': #{e.message}"
      true # Include by default if date parsing fails
    end
  end
  
  count_after = filtered_data.length
  puts "\nStatus breakdown before filtering:"
  status_counts.each { |status, count| puts "  #{status}: #{count}" }
  puts "\nTour-bookings after filter: #{count_after}"
  puts "Filtered out: #{count_before - count_after} tour-bookings"
  
  filtered_data
end

def add_event_status(data)
  puts "\nAdding event status URIs..."
  status_added = 0
  status_skipped = 0
  
  data.each do |booking|
    attributes = booking['attributes'] || {}
    status = attributes['status']
    
    if STATUS_MAPPING.key?(status)
      # Add the schema.org event status URI
      attributes['event_status_uri'] = STATUS_MAPPING[status]
      status_added += 1
      
      if ENV['DEBUG']
        puts "  Added event status for booking #{attributes['nid']}: #{status} -> #{STATUS_MAPPING[status]}"
      end
    else
      # Status not mapped (e.g., "in_progress" or unknown status)
      status_skipped += 1
      
      if ENV['DEBUG']
        puts "  Skipped event status for booking #{attributes['nid']}: unmapped status '#{status}'"
      end
    end
  end
  
  puts "Event status URIs added: #{status_added}"
  puts "Event status URIs skipped: #{status_skipped}" if status_skipped > 0
  
  data
end

def save_json(source, data, file_name)
  json_data = { 'data' => data }
  File.write("#{OUTPUT_DIR}/#{source}.json", JSON.pretty_generate(json_data))
  puts "Saved #{data.length} records to #{OUTPUT_DIR}/#{source}.json"
end

def main
  unless ATC_EVENT_TOKEN
    puts "Error: ATC_EVENT_TOKEN not provided"
    puts "Usage: ruby #{__FILE__} --token=your_base64_encoded_key"
    exit 1
  end
  
  puts "Using API: #{API_BASE_URL}"
  
  # Create output directory
  Dir.mkdir(OUTPUT_DIR) unless Dir.exist?(OUTPUT_DIR)
  
  SOURCE_MAP.each do |source, file_name|
    puts "\n=========================================="
    puts "Processing #{file_name}"
    puts "=========================================="
    
    # Fetch data from API
    data = fetch_data(source, ATC_EVENT_TOKEN)
    
    if data.empty?
      puts "Warning: No data fetched for #{source}"
      next
    end
    
    # Apply filter and add event status for tour-bookings
    if source == 'tour-booking'
      puts "\nApplying filter to tour-bookings..."
      data = filter_tour_bookings(data)
      
      if data.empty?
        puts "Warning: All tour-bookings were filtered out!"
      else
        # Add event status URIs to the filtered data
        data = add_event_status(data)
      end
    end
    
    # Save JSON file
    save_json(source, data, file_name)
    
    puts "✓ Completed #{file_name}"
  end
  
  puts "\n=========================================="
  puts "All entities fetched successfully!"
  puts "=========================================="
end

# Run the script
main if __FILE__ == $PROGRAM_NAME