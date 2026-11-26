module Billetto
  class EventSyncJob < ApplicationJob
    queue_as :default
    retry_on Billetto::Client::TemporaryFailure, wait: :polynomially_longer, attempts: 5

    def perform
      EventIngestor.new.call
    end
  end
end
