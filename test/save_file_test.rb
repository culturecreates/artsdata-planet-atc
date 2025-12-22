#!/usr/bin/env ruby
require 'minitest/autorun'
require 'json'
require 'date'
require_relative '../src/fetch_atc_entities'
require_relative './test_helper'

class SaveJsonTest < Minitest::Test
  include FixtureHelper

  def setup
    @OUTPUT_DIR = 'json'
    Dir.mkdir(OUTPUT_DIR) unless Dir.exist?(OUTPUT_DIR)
    @today = Date.parse('2025-12-11')
    fixtures = load_fixture('tour_bookings.json')

    @tour_booking_confirmed = fixtures['confirmed']
    
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

  def teardown
    Dir.delete(@OUTPUT_DIR) if Dir.exist?(@OUTPUT_DIR)
  end
  
end
