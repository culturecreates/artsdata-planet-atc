#!/usr/bin/env ruby
require 'minitest/autorun'
require 'json'
require 'webmock/minitest'
require_relative '../src/fetch_atc_entities'
require_relative './test_helper'

class FetchDataTest < Minitest::Test
  include TestHelper

  def setup
    # Mock API responses
    @api_base_url = 'https://arts-tc.ca/api/'
    @api_key = 'test_api_key_base64'
    
    @artist_fixtures = load_fixture('artist_data.json')
    @tour_booking_fixtures = load_fixture('tour_bookings.json')
    @OUTPUT_DIR = 'json'
    Dir.mkdir(@OUTPUT_DIR) unless Dir.exist?(@OUTPUT_DIR)

  end

  def teardown
    WebMock.reset!
  end

  def test_fetch_data_single_page_success
    # Mock successful API response with data
    stub_request(:get, "#{@api_base_url}artist?page%5Boffset%5D=0")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => @artist_fixtures }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    # Mock empty response for next page (end of data)
    stub_request(:get, "#{@api_base_url}artist?page%5Boffset%5D=50")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => [] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    result = fetch_data('artist', @api_key)

    assert_equal @artist_fixtures.length, result.length
    assert_equal @artist_fixtures[0]['attributes']['nid'], result[0]['attributes']['nid']
    assert_equal @artist_fixtures[0]['attributes']['name'], result[0]['attributes']['name']
    assert_equal @artist_fixtures[1]['attributes']['nid'], result[1]['attributes']['nid']
  end

  def test_fetch_data_multiple_pages_pagination
    # Mock first page with 50 items
    first_page_data = Array.new(50) do |i|
      {
        'type' => 'artist',
        'id' => "#{i}",
        'attributes' => { 'nid' => 100 + i, 'name' => "Artist #{i}" }
      }
    end

    stub_request(:get, "#{@api_base_url}artist?page%5Boffset%5D=0")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => first_page_data }.to_json
      )

    # Mock second page with remaining items
    second_page_data = Array.new(25) do |i|
      {
        'type' => 'artist',
        'id' => "#{50 + i}",
        'attributes' => { 'nid' => 150 + i, 'name' => "Artist #{50 + i}" }
      }
    end

    stub_request(:get, "#{@api_base_url}artist?page%5Boffset%5D=50")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => second_page_data }.to_json
      )

    # Mock empty third page
    stub_request(:get, "#{@api_base_url}artist?page%5Boffset%5D=100")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => [] }.to_json
      )

    result = fetch_data('artist', @api_key)

    assert_equal 75, result.length
    assert_equal first_page_data[0]['attributes']['nid'], result[0]['attributes']['nid']
    assert_equal second_page_data[0]['attributes']['nid'], result[50]['attributes']['nid']
    assert_equal second_page_data[24]['attributes']['nid'], result[74]['attributes']['nid']
  end

  def test_fetch_data_empty_response
    # Mock API returning empty data immediately
    stub_request(:get, "#{@api_base_url}artist?page%5Boffset%5D=0")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => [] }.to_json
      )

    result = fetch_data('artist', @api_key)

    assert_equal 0, result.length
    assert_empty result
  end

   ## Save File Tests ##
  

  def test_save_json_creates_valid_file
    source = 'test-source'
    data = @tour_booking_fixtures
    path = "#{@OUTPUT_DIR}/#{source}.json"
    save_json(source, data)
    assert File.exist?(path)
    
    content = JSON.parse(File.read(path))
    assert_equal data, content['data']
    
    # Cleanup
    File.delete(path) if File.exist?(path)
  end
end