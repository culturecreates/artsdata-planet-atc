 #!/usr/bin/env ruby
require 'minitest/autorun'
require 'json'
require 'date'
require_relative '../src/fetch_atc_entities'
require_relative './test_helper'


class IntegrationTest < Minitest::Test
  include TestHelper

  def setup
    @today = Date.parse('2025-12-11')
    @fixtures = load_fixture('tour_bookings.json')
  end

  def test_filter_and_add_status_workflow
    with_date(@today) do
      # First filter
      filtered =  Artsdata::TourBookings.filter_tour_bookings(@fixtures)
      assert_equal 4, filtered.length
      
      # Then add status
      result = Artsdata::Attributes.add_event_status(filtered, nil)
      assert_equal 4, result.length
      
      # Check both have event_status_uri
      assert_equal 'http://schema.org/EventScheduled', result.select { |b| b['id'] == 1 }.first['attributes']['event_status_uri']
      assert_equal 'http://schema.org/EventCancelled', result.select { |b| b['id'] == 5 }.first['attributes']['event_status_uri']
    end
  end

  def test_empty_data_handling
    data = []
    
    with_date(@today) do
      filtered =  Artsdata::TourBookings.filter_tour_bookings(data)
      assert_equal 0, filtered.length
      
      result = Artsdata::Attributes.add_event_status(filtered, nil)
      assert_equal 0, result.length
    end
  end

 
end
  