#!/usr/bin/env ruby
require 'minitest/autorun'
require_relative '../src/add_attributes'
require_relative './test_helper'

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
