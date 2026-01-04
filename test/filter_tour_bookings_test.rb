#!/usr/bin/env ruby
require 'minitest/autorun'
require_relative '../src/filter_tour_bookings'
require_relative './test_helper'

class FilterTourBookingsTest < Minitest::Test
  include TestHelper

  def setup
    @today = Date.parse('2025-12-11')
    @tour_booking_fixtures = load_fixture('tour_bookings.json')
  end

  def test_filter_includes_future_event_with_valid_disclosure
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(@tour_booking_fixtures)
      assert filtered.any? { |b| b['id'] == 1 }
    end
  end

  def test_filter_excludes_in_progress_status
     with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(@tour_booking_fixtures)
      refute filtered.any? { |b| b['id'] == 2 }
    end
  end

  def test_filter_includes_past_season_start
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(@tour_booking_fixtures)
      assert filtered.any? { |b| b['id'] == 3 }
    end
  end

  def test_filter_excludes_before_disclosure_date
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(@tour_booking_fixtures)
      refute filtered.any? { |b| b['id'] == 4 }
    end
  end

  def test_filter_include_closed_status_after_disclosure_date
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(@tour_booking_fixtures)
      assert filtered.any? { |b| b['id'] == 5 }
    end
  end

  def test_filter_include_postponed_status_after_disclosure_date
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(@tour_booking_fixtures)
      assert filtered.any? { |b| b['id'] == 6 }
    end
  end

  ### Edge Cases ###

  def test_filter_includes_booking_with_missing_disclosure
    booking = [{
      'id' => 11,
      'attributes' => {
        'nid' => 11,
        'status' => 'confirmed',
        'season' => { 
          'start' => 'invalid-date'
         }
      }
    }]
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(booking)
      assert filtered.any? { |b| b['id'] == 11 }
    end
  end
  

  def test_filter_handles_invalid_date_format
    booking = [{
      'attributes' => {
        'nid' => 11,
        'status' => 'confirmed',
        'season' => { 
          'disclosure' => 30,
          'start' => 'invalid-date'
         }
      }
    }]
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(booking)
      assert_equal 1, filtered.length
    end
  end

  def test_filter_handles_empty_data
    data = []
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(data)
      assert_equal 0, filtered.length
    end
  end

  def test_filter_handles_missing_season
    booking = [{
      'attributes' => {
        'nid' => 11,
        'status' => 'confirmed'
      }
    }]
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(booking)
      assert_equal 1, filtered.length
    end
  end

  def test_filter_handles_season_empty_array
    booking = [{
      'attributes' => {
        'nid' => 11,
        'status' => 'confirmed',
        'season' => []
      }
    }]
    with_date(@today) do
      filtered = Artsdata::TourBookings.filter_tour_bookings(booking)
      assert_equal 1, filtered.length
    end
  end
end