module GoogleContactsApi
  module Parser
    private

    # Turn an array of hashes into a hash with keys based on the original hash's 'rel' values, flatten, and cleanse.
    def extract_schema(records)
      (records || []).map do |record|
        memo = {}
        key = (record['label'] || record['rel'] || 'unknown').split('#').last.to_sym
        value = cleanse_gdata(record.except('rel'))
        if record["primary"] == 'true' # cast to a boolean for primary entries
          value["primary"] = true
          memo["primary"] = true
        end
        value["protocol"] = record["protocol"].split('#').last if value["protocol"].present? # clean namespace from handle protocols
        value = value["$t"] if value["$t"].present? # flatten out entries with keys of '$t'
        value = value["href"] if value.is_a?(Hash) && value.keys.include?("href") # flatten out entries with keys of 'href'
        memo["type"] = key
        memo["value"] = value
        memo
      end
    end

    # Transform this
    #     {"gd$fullName"=>{"$t"=>"Bob Smith"},
    #      "gd$givenName"=>{"$t"=>"Bob"},
    #      "gd$familyName"=>{"$t"=>"Smith"}}
    # into this
    #     { :full_name => "Bob Smith",
    #       :given_name => "Bob",
    #       :family_name => "Smith" }
    def cleanse_gdata(hash)
      (hash || {}).inject({}) do |m, (k, value)|
        k = k.gsub(/\Agd\$/, '').underscore # remove leading 'gd$' on key names and switch to underscores

        if value.is_a?(Hash)
          if value.keys.include?('$t') # flatten out { '$t' => "value" } results
            m[k.to_sym] = value['$t']
          end

          if value.keys.include?('yomi')
            m["phonetic_#{k}".to_sym] = value["yomi"]
          end

          if value.keys.exclude?('$t') && value.keys.exclude?('yomi')
            m[k] = value
          end
        else
          m[k] = value
        end
        m
      end
    end

    #"id"=>{"$t"=>"http://www.google.com/m8/feeds/contacts/{UserEmail}/base/2"} =>
    #   http://www.google.com/m8/feeds/contacts/{UserEmail}/base/2
    #  "gd$etag"=>"\"Qns4ejVSLit7I2A9XRRSEkwLQQQ.\"" => Qns4ejVSLit7I2A9XRRSEkwLQQQ
    #  "updated"=>{"$t"=>"2015-01-14T05:00:03.532Z"} => 2015-01-14T05:00:03.532Z
    def pure_data(data)
      if data.is_a?(Hash)
        pure_data(data.values.first)
      else
        data
      end
    end

    # http://www.google.com/m8/feeds/contacts/{UserEmail}/base/2 => 2
    def parse_id(id)
      if matched = id.match(/\/base\/(.*)/)
        matched[1]
      end
    end
  end
end
