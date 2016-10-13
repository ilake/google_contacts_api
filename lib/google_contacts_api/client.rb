require "google_contacts_api/config"
require "google/api_client"

module GoogleContactsApi
  class Client
    attr_reader :client

    def initialize(access_token, refresh_token)
      configure_client(access_token, refresh_token)
    end

    private

    def configure_client(access_token, refresh_token)
      @client = Google::APIClient.new
      @client.authorization.access_token = access_token
      @client.authorization.refresh_token = refresh_token
      @client.authorization.client_id = Config.google_client_id
      @client.authorization.client_secret = Config.google_client_secret
      @client.authorization.refresh!
    end
  end
end
