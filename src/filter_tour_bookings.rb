# frozen_string_literal: true
require 'date'

module Artsdata

  # TourBookings module for filtering tour bookings
  # include tour-booking IF ( atc:start_date (xsd:date) - atc:disclosure (# days) <  today (xsd:date) ) AND ( status != in_progress )
  module TourBookings
    def self.filter_tour_bookings(data, logger = nil)
      today = Date.today
      count_before = data.length
      logger&.info "Tour-bookings before filter: #{count_before}"
      logger&.info "Today's date: #{today}"

      status_counts = Hash.new(0)

      filtered_data = data.select do |booking|
        attributes = booking['attributes'] || {}
        status = attributes['status']
        status_counts[status] += 1

        if status == 'in_progress'
          logger&.debug "  Booking #{attributes['nid']}: filtered out (status: in_progress)"
          next false
        end

        season = attributes['season']
        season_start = season['start']
       
        if season_start.empty?
          logger&.debug "  Including booking (no season): #{attributes['nid']}"
          next true
        end

        begin
          disclosure_days = season['disclosure'].to_i
          season_start_date = Date.parse(season_start)
          disclosure_date = season_start_date - disclosure_days
          include = disclosure_date < today
          logger&.debug "  Booking #{attributes['nid']}: season_start=#{season_start_date}, disclosure=#{disclosure_days}d, deadline=#{disclosure_date}, today=#{today}, include=#{include}"
          include
        rescue ArgumentError => e
          logger&.info "Warning: Could not calculate disclosure date: #{e.message}"
          true
        end
      end

      count_after = filtered_data.length
      logger&.info "Status breakdown before filtering:"
      status_counts.each { |status, count| logger&.info "  #{status}: #{count}" }
      logger&.info "Tour-bookings after filter: #{count_after}"
      logger&.info "Filtered out: #{count_before - count_after} tour-bookings"

      filtered_data
    end
  end
end
