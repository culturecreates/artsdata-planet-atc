# Status mapping for event schema
# Maps ATC status values to schema.org event status URIs

def add_attribute(
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


STATUS_MAPPING = {
  'confirmed' => 'http://schema.org/EventScheduled',
  'closed'    => 'http://schema.org/EventCancelled',
  'postponed' => 'http://schema.org/EventPostponed'
}.freeze

def add_event_status(data, logger)
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