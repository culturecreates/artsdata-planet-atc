#!/usr/bin/env ruby
require 'minitest/autorun'
require 'minitest/mock'
require 'json'
require 'date'
require_relative '../src/fetch_atc_entities'
require_relative './test_helper'

class AddEventStatusTest < Minitest::Test
  include FixtureHelper

  def setup
    @today = Date.parse('2025-12-11')
    fixtures = load_fixture('tour_bookings.json')

    @tour_booking_confirmed      = fixtures['confirmed']
    @tour_booking_in_progress    = fixtures['in_progress']
    @tour_booking_past_deadline  = fixtures['past_deadline']
    @tour_booking_no_disclosure  = fixtures['no_disclosure']
    @tour_booking_season_array   = fixtures['season_array']
    @tour_booking_closed         = fixtures['closed']
    @tour_booking_postponed      = fixtures['postponed']
    @tour_booking_unknown_status = fixtures['unknown_status']
  end
  
  # Event Status Tests
  
  def test_add_event_status_confirmed
    data = [@tour_booking_confirmed]
    result = add_event_status(data, nil)
    
    assert_equal 1, result.length
    assert_equal 'http://schema.org/EventScheduled', result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_closed
    data = [@tour_booking_closed]
    result = add_event_status(data, nil)
    
    assert_equal 1, result.length
    assert_equal 'http://schema.org/EventCancelled', result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_postponed
    data = [@tour_booking_postponed]
    result = add_event_status(data, nil)
    
    assert_equal 1, result.length
    assert_equal 'http://schema.org/EventPostponed', result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_unknown_status
    data = [@tour_booking_unknown_status]
    result = add_event_status(data, nil)
    
    assert_equal 1, result.length
    assert_nil result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_in_progress
    data = [@tour_booking_in_progress]
    result = add_event_status(data, nil)
    
    assert_equal 1, result.length
    # in_progress is not in STATUS_MAPPING, so should not have event_status_uri
    assert_nil result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_multiple_bookings
    data = [
      @tour_booking_confirmed,
      @tour_booking_closed,
      @tour_booking_postponed,
      @tour_booking_unknown_status
    ]
    result = add_event_status(data, nil)
    
    assert_equal 4, result.length
    assert_equal 'http://schema.org/EventScheduled', result[0]['attributes']['event_status_uri']
    assert_equal 'http://schema.org/EventCancelled', result[1]['attributes']['event_status_uri']
    assert_equal 'http://schema.org/EventPostponed', result[2]['attributes']['event_status_uri']
    assert_nil result[3]['attributes']['event_status_uri']
  end

  def test_add_event_status_preserves_original_data
    original_booking = {
      'attributes' => {
        'nid' => 100,
        'status' => 'confirmed',
        'event_date' => '2026-02-15T19:00:00',
        'show' => { 'title' => 'Test Show' }
      }
    }
    data = [original_booking]
    result = add_event_status(data, nil)
    
    assert_equal 100, result.first['attributes']['nid']
    assert_equal 'confirmed', result.first['attributes']['status']
    assert_equal '2026-02-15T19:00:00', result.first['attributes']['event_date']
    assert_equal 'Test Show', result.first['attributes']['show']['title']
    assert_equal 'http://schema.org/EventScheduled', result.first['attributes']['event_status_uri']
  end

  # STATUS_MAPPING Tests
  
  def test_status_mapping_contains_all_required_statuses
    assert STATUS_MAPPING.key?('confirmed')
    assert STATUS_MAPPING.key?('closed')
    assert STATUS_MAPPING.key?('postponed')
  end

  def test_status_mapping_has_correct_uris
    assert_equal 'http://schema.org/EventScheduled', STATUS_MAPPING['confirmed']
    assert_equal 'http://schema.org/EventCancelled', STATUS_MAPPING['closed']
    assert_equal 'http://schema.org/EventPostponed', STATUS_MAPPING['postponed']
  end

  def test_status_mapping_does_not_include_in_progress
    refute STATUS_MAPPING.key?('in_progress')
  end

  # Source Map Tests
  
  def test_source_map_contains_all_required_entities
    expected_sources = [
      'artist', 'network', 'presenter', 'performance-space',
      'representative', 'show', 'tour-booking', 'genre', 'category'
    ]
    
    expected_sources.each do |source|
      assert SOURCE_MAP.key?(source), "SOURCE_MAP missing key: #{source}"
    end
  end

  def test_source_map_has_correct_filenames
    assert_equal 'artists', SOURCE_MAP['artist']
    assert_equal 'networks', SOURCE_MAP['network']
    assert_equal 'presenters', SOURCE_MAP['presenter']
    assert_equal 'performance-spaces', SOURCE_MAP['performance-space']
    assert_equal 'representatives', SOURCE_MAP['representative']
    assert_equal 'shows', SOURCE_MAP['show']
    assert_equal 'tour-bookings', SOURCE_MAP['tour-booking']
    assert_equal 'genres', SOURCE_MAP['genre']
    assert_equal 'categories', SOURCE_MAP['category']
  end

end
