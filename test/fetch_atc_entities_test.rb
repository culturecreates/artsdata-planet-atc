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
    @api_base_url = 'https://arts-tc.ca/'
    @api_key = 'test_api_key_base64'
    
    @artist_fixtures = load_fixture('artist_data.json')

  end

  def teardown
    WebMock.reset!
  end

  def test_fetch_data_single_page_success
    # Mock successful API response with data
    stub_request(:get, "#{@api_base_url}/artist?page%5Boffset%5D=0")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => @artist_fixtures }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    # Mock empty response for next page (end of data)
    stub_request(:get, "#{@api_base_url}/artist?page%5Boffset%5D=50")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => [] }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    
    result = fetch_data('artist', @api_key)
    
    assert_equal 2, result.length
    assert_equal 101, result[0]['attributes']['nid']
    assert_equal 'Test Artist 1', result[0]['attributes']['name']
    assert_equal 102, result[1]['attributes']['nid']
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
    
    stub_request(:get, "#{@api_base_url}/artist?page%5Boffset%5D=0")
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
    
    stub_request(:get, "#{@api_base_url}/artist?page%5Boffset%5D=50")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => second_page_data }.to_json
      )
    
    # Mock empty third page
    stub_request(:get, "#{@api_base_url}/artist?page%5Boffset%5D=100")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => [] }.to_json
      )
    
    result = fetch_data('artist', @api_key)
    
    assert_equal 75, result.length
    assert_equal 100, result[0]['attributes']['nid']
    assert_equal 150, result[50]['attributes']['nid']
    assert_equal 174, result[74]['attributes']['nid']
  end

  def test_fetch_data_empty_response
    # Mock API returning empty data immediately
    stub_request(:get, "#{@api_base_url}/artist?page%5Boffset%5D=0")
      .with(headers: { 'Authorization' => "basic #{@api_key}" })
      .to_return(
        status: 200,
        body: { 'data' => [] }.to_json
      )
    
    result = fetch_data('artist', @api_key)
    
    assert_equal 0, result.length
    assert_empty result
  end

end