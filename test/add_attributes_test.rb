#!/usr/bin/env ruby
require 'minitest/autorun'
require_relative '../src/add_attributes'
require_relative './test_helper'
require 'tzinfo'

class AddEventStatusTest < Minitest::Test
  include TestHelper

  def setup
    @fixtures = load_fixture('tour_bookings.json')
  end

  def test_add_event_status_confirmed
    result = Artsdata::Attributes.add_event_status(@fixtures)
    
    assert_equal 'http://schema.org/EventScheduled', result.select { |b| b['id'] == 1 }.first['attributes']['event_status_uri']
  end

  def test_add_event_status_closed
    result = Artsdata::Attributes.add_event_status(@fixtures)
    
    assert_equal 'http://schema.org/EventCancelled', result.select { |b| b['id'] == 5 }.first['attributes']['event_status_uri']
  end

  def test_add_event_status_postponed
    result = Artsdata::Attributes.add_event_status(@fixtures)
    assert_equal 'http://schema.org/EventPostponed', result.select { |b| b['id'] == 6 }.first['attributes']['event_status_uri']
  end

  ### Edge Cases ###
  
  def test_add_event_status_unknown_status
    data = [{
      'attributes' => {
        'nid' => 11,
        'status' => 'unknown',
        'season' => { 
          'disclosure' => 30,
          'start' => 'invalid-date'
         }
      }
    }]
    result = Artsdata::Attributes.add_event_status(data)
    
    assert_equal 1, result.length
    assert_nil result.first['attributes']['event_status_uri']
  end

  def test_add_event_status_in_progress
     data = [{
      'attributes' => {
        'nid' => 11,
        'status' => 'in_progress',
        'season' => { 
          'disclosure' => 30,
          'start' => 'invalid-date'
         }
      }
    }]
    result = Artsdata::Attributes.add_event_status(data)
    
    assert_equal 1, result.length
    # in_progress is not in STATUS_MAPPING, so should not have event_status_uri
    assert_nil result.first['attributes']['event_status_uri']
  end

end

class AddEventDateLocalTest < Minitest::Test

  def make_record(nid, event_date)
    { 'attributes' => { 'nid' => nid, 'event_date' => event_date } }
  end

  def run_transform(records)
    Artsdata::Attributes.add_event_date_local(records)
  end


  def test_summer_date_edt
    data = [make_record('1', '2024-07-15T23:00:00Z')]
    run_transform(data)
    assert_equal '2024-07-15T19:00:00', data[0]['attributes']['event_date_local']
  end

  def test_winter_date_est
    data = [make_record('2', '2025-01-20T23:00:00Z')]
    run_transform(data)
    assert_equal '2025-01-20T18:00:00', data[0]['attributes']['event_date_local']
  end

  def test_issue_42_sample_a
    data = [make_record('42a', '2025-03-15T00:00:00Z')]
    run_transform(data)
    # 2025-03-15 is after spring-forward (2025-03-09), so EDT: UTC−4
    assert_equal '2025-03-14T20:00:00', data[0]['attributes']['event_date_local']
  end

  # Original event_date must be preserved on the record
  def test_original_event_date_untouched
    original = '2024-07-15T23:00:00Z'
    data = [make_record('8', original)]
    run_transform(data)
    assert_equal original, data[0]['attributes']['event_date']
  end

  def test_positive_zero_offset_format
    data = [make_record('10', '2027-03-10T00:30:00+00:00')]
    run_transform(data)
    # March 10, 2027 is before spring-forward (EST, UTC-5): 00:30 - 5h = 19:30 Mar 9
    assert_equal '2027-03-09T19:30:00', data[0]['attributes']['event_date_local']
  end

  # Multiple records — all transformed independently
  def test_multiple_records
    data = [
      make_record('9a', '2024-07-15T23:00:00Z'),
      make_record('9b', '2025-01-20T23:00:00Z')
    ]
    run_transform(data)
    assert_equal '2024-07-15T19:00:00', data[0]['attributes']['event_date_local']
    assert_equal '2025-01-20T18:00:00', data[1]['attributes']['event_date_local']
  end
end
