module Events
  class VoteCast < RubyEventStore::Event
    SCHEMA = { event_id: Integer, clerk_user_id: String, value: String }.freeze

    def self.strict(data:)
      normalized = data.symbolize_keys
      valid = normalized.keys.sort == SCHEMA.keys.sort &&
        normalized.all? { |key, value| value.is_a?(SCHEMA.fetch(key)) } && %w[up down].include?(normalized[:value])
      raise ArgumentError, "Invalid vote event data" unless valid

      new(data: normalized)
    end
  end
end
