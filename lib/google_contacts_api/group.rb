require "google_contacts_api/client"
require "google_contacts_api/request"
require "google_contacts_api/parser"

module GoogleContactsApi
  module Group
    include GoogleContactsApi::Request
    include GoogleContactsApi::Parser

    BASE_URL = "https://www.google.com/m8/feeds/groups/default/full"

    def list
      tries ||= 3
      result = get(BASE_URL, parameters: { 'alt' => 'json', 'max-results' => '100' })

      process_group_list(result[:data]['feed']['entry'])
    rescue => e
      if (tries -= 1).zero?
        raise e
      else
        retry
      end
    end
    alias_method :groups, :list

    def create(title)
      result = post(BASE_URL, group_xml(title))
      doc = Nokogiri::XML(CGI::unescape(result[:body]).delete("\n"))
      base_url = doc.xpath("//*[name()='id']").first.content
      raw_data = {
        title: doc,
        id: parse_id(base_url),
        base_url: base_url
      }

      GoogleGroup.new(raw_data)
    end
    alias_method :create_group, :create

    def update(group_id, title)
      content = xml_of_group_show(group_id)
      doc = Nokogiri::XML(CGI::unescape(content).delete("\n"))
      doc.xpath("//*[name()='title']").first.content = title.to_s.encode(xml: :text)
      put("#{BASE_URL}/#{group_id}", doc.to_xml)
    end
    alias_method :update_group, :update

    # http://www.google.com/m8/feeds/groups/{UserEmail}/base/abcdefg
    def url(group_id)
      groups.first.base_url.sub(/base\/\w+/, "base/#{group_id}")
    end
    alias_method :group_base_url, :url

    private

    def xml_of_group_show(group_id, options = {})
      result = get("#{BASE_URL}/#{group_id}", headers: { "GData-Version"=>"3.0", "Content-Type" => "application/atom+xml" }.merge(options))

      result[:body]
    end

    def group_xml(title)
      <<-EOS
      <atom:entry xmlns:gd="http://schemas.google.com/g/2005"
        xmlns:atom="http://www.w3.org/2005/Atom">
        <atom:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#group"/>
        <atom:title type="text">#{title.to_s.encode(xml: :text)}</atom:title>
      </atom:entry>
      EOS
    end

    def process_group_list(group_list)
      (group_list || []).map do |group|
        group_cleansed = cleanse_gdata(group) #todo: do i want to filter out anything?
        group_cleansed[:base_url] = group_cleansed[:id]
        group_cleansed[:id] = parse_id(group_cleansed[:id])
        GoogleGroup.new(group_cleansed)
      end
    end
  end

  class GoogleGroup
    attr_accessor :title, :id, :base_url, :raw_data

    def initialize(raw_data)
      @raw_data = raw_data
      @title = raw_data[:title]
      @id = raw_data[:id]
      @base_url = raw_data[:base_url]
    end
  end
end
