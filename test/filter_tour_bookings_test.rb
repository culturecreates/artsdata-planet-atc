#!/usr/bin/env ruby
require 'minitest/autorun'
require 'json'
require 'date'
require_relative '../src/fetch_atc_entities'
require_relative './test_helper'


class FilterTourBookingsTest < Minitest::Test
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
end
