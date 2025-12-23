 #!/usr/bin/env ruby
require 'minitest/autorun'
require 'json'
require 'date'
require_relative '../src/fetch_atc_entities'
require_relative './test_helper'


class IntegrationTest < Minitest::Test
  include FixtureHelper

  def setup
    @today = Date.parse('2025-12-11')
    fixtures = load_fixture('tour_bookings.json')

    @tour_booking_confirmed      = fixtures['confirmed']
    @tour_booking_in_progress    = fixtures['in_progress']
    @tour_booking_past_deadline  = fixtures['past_deadline']
    @tour_booking_closed         = fixtures['closed']
    
  end

 def test_filter_and_add_status_workflow
    data = [
      @tour_booking_confirmed,
      @tour_booking_in_progress,
      @tour_booking_closed,
      @tour_booking_past_deadline
    ]
    
    Date.stub :today, @today do
      # First filter
      filtered = filter_tour_bookings(data)
      assert_equal 2, filtered.length
      
      # Then add status
      result = add_event_status(filtered, nil)
      assert_equal 2, result.length
      
      # Check both have event_status_uri
      assert_equal 'http://schema.org/EventScheduled', result[0]['attributes']['event_status_uri']
      assert_equal 'http://schema.org/EventCancelled', result[1]['attributes']['event_status_uri']
    end
  end

  def test_empty_data_handling
    data = []
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 0, filtered.length
      
      result = add_event_status(filtered, nil)
      assert_equal 0, result.length
    end
  end

end
  