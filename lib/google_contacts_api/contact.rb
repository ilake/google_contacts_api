require "google_contacts_api/client"
require "google_contacts_api/request"
require "google_contacts_api/parser"
require "google_contacts_api/group"

module GoogleContactsApi
  module Contact
    include Request
    include Parser
    include Group

    BASE_URL = "https://www.google.com/m8/feeds/contacts/default/full"
    EMAIL_TYPES = %i(work home other).freeze
    PHONE_TYPES = %i(work home other mobile main home_fax work_fax pager).freeze
    GOOGLE_VOICE_LABEL = "grandcentral"

    def list(options = {})
      result = get(BASE_URL, parameters: { 'alt' => 'json', 'updated-min' => options[:since] || '1901-01-16T00:00:00', 'max-results' => '100000' }.merge(options))

      process_contacts_list(result[:data]['feed']['entry'])
    end
    alias_method :contacts, :list

    def group_contacts(group_id)
      list(group: group_base_url(group_id))
    end

    def show(contact_id, options = {})
      result = get("#{BASE_URL}/#{contact_id}", parameters: { "alt" => "json"}.merge(options))
      process_contact(result[:data]['entry'])
    end
    alias_method :contact, :show

    def update(contact_id, options)
      content = xml_of_show(contact_id)
      doc = Nokogiri::XML(CGI::unescape(content).delete("\n"))
      doc = handle_contact_options(doc, options)
      put("#{BASE_URL}/#{contact_id}", doc.to_xml)
    end
    alias_method :update_contact, :update

    def create(options)
      doc = Nokogiri::XML(contact_xml_template)
      doc = handle_contact_options(doc, options)
      post(BASE_URL, doc.to_xml)
    end
    alias_method :create_contact, :create

    protected

    def xml_of_show(contact_id, options = {})
      result = get("#{BASE_URL}/#{contact_id}", headers: { "GData-Version"=>"3.0", "Content-Type" => "application/atom+xml" }.merge(options))

      result[:body]
    end

    def process_contacts_list(group_list)
      (group_list || []).map do |contact|
        process_contact(contact)
      end
    end

    def process_contact(contact)
      contact_raw_data = {
        id: parse_id(pure_data(contact["id"])),
        emails: extract_schema(contact['gd$email']),
        phone_numbers: extract_schema(contact['gd$phoneNumber']),
        handles: extract_schema(contact['gd$im']),
        addresses: extract_schema(contact['gd$structuredPostalAddress']),
        name_data: cleanse_gdata(contact['gd$name']),
        nickname: contact['gContact$nickname'] && contact['gContact$nickname']['$t'],
        websites: extract_schema(contact['gContact$website']),
        organizations: extract_schema(contact['gd$organization']),
        events: extract_schema(contact['gContact$event']),
        group_ids: contact["gContact$groupMembershipInfo"] ? contact["gContact$groupMembershipInfo"].map{|g| parse_id(g["href"]) } : [],
        birthday: contact['gContact$birthday'].try(:[], "when")
      }.tap do |basic_data|
        # Extract a few useful bits from the basic data
        basic_data[:full_name] = basic_data[:name_data].try(:[], :full_name)
        primary_email_data = basic_data[:emails].find { |email_hash| email_hash["value"]["primary"] }
        basic_data[:primary_email] = primary_email_data if primary_email_data
      end
      GoogleContact.new(contact_raw_data)
    end

    def contact_xml_template
      <<-EOF
        <atom:entry xmlns:atom="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005">
          <atom:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#contact"/>
          <title></title>
          <gd:name>
            <gd:givenName></gd:givenName>
            <gd:familyName></gd:familyName>
          </gd:name>
        </atom:entry>
      EOF
    end

    def handle_contact_options(doc, options)
      options.each do |key, value|
        case key.to_sym
        when :name
          # name: { familyName: last_name, givenName: first_name}
          value.each do |name_type, name_value|
            doc.xpath("//*[name()='gd:#{name_type}']").first.content = name_value
          end
          doc.xpath("//*[name()='title']").first.content = "#{value[:givenName]} #{value[:familyName]}"
        when :phonetic_name
          # phonetic_name: { familyName: last_name, givenName: first_name}
          value.each do |name_type, name_value|
            name_node = doc.xpath("//*[name()='gd:#{name_type}']").first
            name_node.attributes["yomi"].value = name_value
          end
        when :emails
          # "emails"=> [
          #   {"type"=>"home", "value"=> { "address" =>  "taiwanhimawari@gmail.com" }, "primary": true},
          #   {"type"=>"unknown", "value"=> { "address" => "studioha3@dreamhint.com"}}
          # ]
          doc.xpath("//*[name()='gd:email']").remove
          value.each do |email_hash|
            attr = if EMAIL_TYPES.include?(email_hash["type"])
                     %Q|rel="http://schemas.google.com/g/2005##{email_hash["type"]}"|
                   else
                     %Q|label="#{email_hash["type"]}"|
                   end

            doc.children.children.last.add_next_sibling(
              %Q|<gd:email #{attr} address="#{email_hash["value"]["address"]}" primary="#{!!email_hash["primary"]}" />|
            )
          end
        when :phone_numbers
          # "phone_numbers"=> [
          #   {"type"=>"mobile", "value"=>"08036238534"},
          #   {"type"=>"home", "value"=>"0524095796"}
          # ]
          doc.xpath("//*[name()='gd:phoneNumber']").remove
          value.each do |phone_hash|
            attr = if PHONE_TYPES.include?(phone_hash["type"])
                     %Q|rel="http://schemas.google.com/g/2005##{phone_hash["type"]}"|
                   else
                     %Q|label="#{phone_hash["type"]}"|
                   end

            doc.children.children.last.add_next_sibling(
              %Q|<gd:phoneNumber #{attr} primary="#{!!phone_hash["primary"]}">#{phone_hash["value"]}</gd:phoneNumber>|
            )
          end
        when :addresses
          # addresses: [{ type: work, value: { street: street_name, city: city_name, region: region, postcode: postcode, country: Taiwan}}]
          doc.xpath("//*[name()='gd:structuredPostalAddress']").remove
          value.each do |address_hash|
            doc.children.children.last.add_next_sibling(
              %Q|<gd:structuredPostalAddress rel="http://schemas.google.com/g/2005##{address_hash["type"]}" primary="#{!!address_hash["primary"]}">
                   <gd:street>#{address_hash["value"]["street"]}</gd:street>
                   <gd:city>#{address_hash["value"]["city"]}</gd:city>
                   <gd:region>#{address_hash["value"]["region"]}</gd:region>
                   <gd:postcode>#{address_hash["value"]["postcode"]}</gd:postcode>
                   <gd:country>#{address_hash["value"]["country"]}</gd:country>
                 </gd:structuredPostalAddress>|
            )
          end
        when :birthday
          doc.xpath("//*[name()='gContact:birthday']").remove
          doc.children.children.last.add_next_sibling(
            %Q|<gContact:birthday when='#{value}' />|
          )
        when :add_group_ids
          Array(value).each do |group_id|
            unless doc.to_xml.match(/#{group_id}/)
              doc.children.children.last.add_next_sibling(
                %Q|<gContact:groupMembershipInfo deleted="false" href="#{group_base_url(group_id)}" />|
            )
            end
          end
        when :remove_group_ids
          Array(value).each do |group_id|
            if doc.to_xml.match(/#{group_id}/)
              doc.xpath("//*[name()='gContact:groupMembershipInfo'][contains(@href, '#{group_id}')]").remove
            end
          end
        end
      end
      doc
    end
  end
end

class GoogleContact
  extend Forwardable
  attr_accessor :first_name, :last_name, :phonetic_first_name, :phonetic_last_name, :raw_data
  def_delegators :@raw_data, :group_ids, :birthday, :id, :primary_email, :emails, :addresses, :phone_numbers

  def initialize(raw_data)
    @raw_data = Hashie::Mash.new(raw_data)
    @first_name = raw_data && raw_data[:name_data] ? raw_data[:name_data][:given_name] : nil
    @last_name = raw_data && raw_data[:name_data] ? raw_data[:name_data][:family_name] : nil
    @phonetic_first_name = raw_data && raw_data[:name_data] ? raw_data[:name_data][:phonetic_given_name] : nil
    @phonetic_last_name = raw_data && raw_data[:name_data] ? raw_data[:name_data][:phonetic_family_name] : nil
  end
end
