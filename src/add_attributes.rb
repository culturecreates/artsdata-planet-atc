require 'tzinfo'
require 'time'
module Artsdata
  module Attributes
    STATUS_MAPPING = {
      'confirmed' => 'http://schema.org/EventScheduled',
      'closed'    => 'http://schema.org/EventCancelled',
      'postponed' => 'http://schema.org/EventPostponed'
    }.freeze

    TORONTO_TZ = TZInfo::Timezone.get('America/Toronto')

    def self.add_attribute(
      data,
      source_key:,
      target_key:,
      transformer:,
      logger: nil
    )
      added = 0
      skipped = 0

      data.each do |item|
        attributes = item['attributes'] ||= {}

        source_value = attributes[source_key]
        new_value = transformer.call(source_value, attributes)

        if new_value.nil?
          skipped += 1
          logger&.debug "Skipped #{target_key} for #{attributes['nid']}"
          next
        end

        attributes[target_key] = new_value
        added += 1

        logger&.debug(
          "Added #{target_key} for #{attributes['nid']}: #{new_value}"
        )
      end

      logger&.info "#{target_key} added: #{added}" if logger
      logger&.info "#{target_key} skipped: #{skipped}" if logger && skipped > 0

      data
    end

    def self.add_event_status(data, logger = nil)
      add_attribute(
        data,
        source_key: 'status',
        target_key: 'event_status_uri',
        logger: logger,
        transformer: ->(status, _attrs) {
          STATUS_MAPPING[status]
        }
      )
    end

    # This method shifts the value back to the correct Toronto wall-clock time 
    # and strips the timezone suffix to produce a floating xsd:dateTime. 
    def self.add_event_date_local(data, logger = nil)
      add_attribute(
        data,
        source_key: 'event_date',
        target_key: 'event_date_local',
        logger: logger,
        transformer: ->(event_date_str, _attrs) {
          return nil if event_date_str.nil? || event_date_str.strip.empty?

          begin
            # Parse the incoming value as UTC (it is mislabeled — it is
            # actually the user's Toronto local time passed through as UTC).
            # Time.iso8601 always interprets Z as UTC regardless of host TZ.
            utc_time = Time.iso8601(event_date_str).utc

            # utc_to_local is the correct tzinfo API: given a UTC instant,
            # return the Toronto wall-clock time, handling DST automatically.
            local_time = TORONTO_TZ.utc_to_local(utc_time)

            # Return a floating dateTime — no Z, no offset suffix.
            local_time.strftime('%Y-%m-%dT%H:%M:%S')
          rescue ArgumentError, TZInfo::InvalidTimezoneIdentifier => e
            logger&.warn "Could not convert event_date '#{event_date_str}': #{e.message}"
            nil
          end
        }
      )
    end
  end
end