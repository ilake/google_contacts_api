require "google_contacts_api/contact"
require "google_contacts_api/group"
require "google_contacts_api/client"

module GoogleContactsApi
  class User
    include Contact
    include Group
    attr_reader :client

    def initialize(access_token, refresh_token)
      @client = Client.new(access_token, refresh_token).client
    end
  end
end
