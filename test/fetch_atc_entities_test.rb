#!/usr/bin/env ruby
require 'minitest/autorun'
require 'json'
require 'date'
require_relative '../src/fetch_atc_entities'

class FetchAtcEntitiesTest < Minitest::Test

  def setup
    @OUTPUT_DIR = 'json'
    @today = Date.parse('2025-12-11')
    
    # Mock data for testing
    @tour_booking_confirmed = {
      'attributes' => {
        'nid' => 1,
        'status' => 'confirmed',
        'event_date' => '2026-02-15T19:00:00',
        'season' => { 'disclosure' => 30 }
      }
    }
    
    @tour_booking_in_progress = {
      'attributes' => {
        'nid' => 2,
        'status' => 'in_progress',
        'event_date' => '2026-02-15T19:00:00',
        'season' => { 'disclosure' => 30 }
      }
    }
    
    @tour_booking_past_deadline = {
      'attributes' => {
        'nid' => 3,
        'status' => 'confirmed',
        'event_date' => '2025-12-20T19:00:00',
        'season' => { 'disclosure' => 30 }
      }
    }
    
    @tour_booking_no_disclosure = {
      'attributes' => {
        'nid' => 4,
        'status' => 'confirmed',
        'event_date' => '2026-01-20T19:00:00',
        'season' => { 'disclosure' => 0 }
      }
    }
    
    
    @tour_booking_season_array = {
      'attributes' => {
        'nid' => 6,
        'status' => 'confirmed',
        'event_date' => '2026-02-15T19:00:00',
        'season' => [{ 'disclosure' => 30 }]
      }
    }
  
    @tour_booking_closed = {
      'attributes' => {
        'nid' => 6,
        'status' => 'closed',
        'event_date' => '2026-02-15T19:00:00',
        'season' => [{ 'disclosure' => 30 }]
      }
    }

    @tour_booking_postponed = {
        'attributes' => {
        'nid' => 6,
        'status' => 'postponed',
        'event_date' => '2026-02-15T19:00:00',
        'season' => [{ 'disclosure' => 30 }]
      }
    }

    @tour_booking_unknown_status = {
      'attributes' => {
        'nid' => 6,
        'status' => 'invalid',
        'event_date' => '2026-02-15T19:00:00',
        'season' => [{ 'disclosure' => 30 }]
      }
    }
  end

  def test_filter_includes_future_event_with_valid_disclosure
    # Event: 2026-02-15, Disclosure: 30 days, Deadline: 2026-01-16
    # Today: 2025-12-11, Deadline (2026-01-16) > Today (2025-12-11) = true
    data = [@tour_booking_confirmed]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 1, filtered.length
      assert_equal 1, filtered.first['attributes']['nid']
    end
  end

  def test_filter_excludes_in_progress_status
    data = [@tour_booking_in_progress]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 0, filtered.length
    end
  end

  def test_filter_excludes_past_disclosure_deadline
    # Event: 2025-12-20, Disclosure: 30 days, Deadline: 2025-11-20
    # Today: 2025-12-11, Deadline (2025-11-20) < Today (2025-12-11) = false
    data = [@tour_booking_past_deadline]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 0, filtered.length
    end
  end

  def test_filter_includes_booking_with_no_disclosure
    data = [@tour_booking_no_disclosure]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 1, filtered.length
      assert_equal 4, filtered.first['attributes']['nid']
    end
  end

  def test_filter_handles_season_as_array
    data = [@tour_booking_season_array]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 1, filtered.length
      assert_equal 6, filtered.first['attributes']['nid']
    end
  end

  def test_filter_multiple_bookings_mixed_results
    data = [
      @tour_booking_confirmed,
      @tour_booking_in_progress,
      @tour_booking_past_deadline,
      @tour_booking_no_disclosure
    ]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 2, filtered.length
      
      nids = filtered.map { |b| b['attributes']['nid'] }
      assert_includes nids, 1  # confirmed, future deadline
      assert_includes nids, 4  # no disclosure
      refute_includes nids, 2  # in_progress
      refute_includes nids, 3  # past deadline
    end
  end

  def test_filter_calculates_disclosure_deadline_correctly
    # Event: 2026-01-15, Disclosure: 45 days
    # Deadline: 2026-01-15 - 45 = 2025-12-01
    # Today: 2025-12-11, Deadline (2025-12-01) < Today (2025-12-11) = false
    booking = {
      'attributes' => {
        'nid' => 8,
        'status' => 'confirmed',
        'event_date' => '2026-01-15T19:00:00',
        'season' => { 'disclosure' => 45 }
      }
    }
    data = [booking]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 0, filtered.length
    end
  end

  def test_filter_edge_case_deadline_equals_today
    # Event: 2026-01-11, Disclosure: 31 days
    # Deadline: 2026-01-11 - 31 = 2025-12-11 (exactly today)
    # Should exclude (not greater than today)
    booking = {
      'attributes' => {
        'nid' => 9,
        'status' => 'confirmed',
        'event_date' => '2026-01-11T19:00:00',
        'season' => { 'disclosure' => 31 }
      }
    }
    data = [booking]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 0, filtered.length
    end
  end

  def test_filter_edge_case_deadline_one_day_after_today
    # Event: 2026-01-13, Disclosure: 31 days
    # Deadline: 2026-01-13 - 31 = 2025-12-13 (one day after today)
    # Should include (greater than today)
    booking = {
      'attributes' => {
        'nid' => 10,
        'status' => 'confirmed',
        'event_date' => '2026-01-13T19:00:00',
        'season' => { 'disclosure' => 31 }
      }
    }
    data = [booking]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 1, filtered.length
    end
  end

  def test_filter_handles_invalid_date_format
    booking = {
      'attributes' => {
        'nid' => 11,
        'status' => 'confirmed',
        'event_date' => 'invalid-date',
        'season' => { 'disclosure' => 30 }
      }
    }
    data = [booking]
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      # Should include by default when date parsing fails
      assert_equal 1, filtered.length
    end
  end

  def test_filter_handles_empty_data
    data = []
    
    Date.stub :today, @today do
      filtered = filter_tour_bookings(data)
      assert_equal 0, filtered.length
    end
  end

  def test_save_json_creates_valid_file
    source = 'test-source'
    data = [@tour_booking_confirmed]
    path = "#{@OUTPUT_DIR}/#{source}.json"
    save_json(source, data)
    assert File.exist?(path)
    
    content = JSON.parse(File.read(path))
    assert_equal data, content['data']
    
    # Cleanup
    File.delete(path) if File.exist?(path)
  end

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


  # Event Status Tests
  
  def test_add_event_status_confirmed
    data = [@tour_booking_confirmed]
    result = add_event_status(data)
    
    assert_equal 1, result.length
    assert_equal 'http://schema.org/EventScheduled', result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_closed
    data = [@tour_booking_closed]
    result = add_event_status(data)
    
    assert_equal 1, result.length
    assert_equal 'http://schema.org/EventCancelled', result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_postponed
    data = [@tour_booking_postponed]
    result = add_event_status(data)
    
    assert_equal 1, result.length
    assert_equal 'http://schema.org/EventPostponed', result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_unknown_status
    data = [@tour_booking_unknown_status]
    result = add_event_status(data)
    
    assert_equal 1, result.length
    assert_nil result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_in_progress
    data = [@tour_booking_in_progress]
    result = add_event_status(data)
    
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
    result = add_event_status(data)
    
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
    result = add_event_status(data)
    
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

  # Integration Tests
  
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
      result = add_event_status(filtered)
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
      
      result = add_event_status(filtered)
      assert_equal 0, result.length
    end
  end
end
