module GoogleContactsApi
  module Request
    def get(url, options = {})
      response = client.execute({
        uri: url,
        headers: { 'GData-Version' => '3.0', 'Content-Type' => 'application/json' }
      }.merge(options))

      { body: response.body, data: response.data }
    end

    def post(url, body, options = {})
      response = client.execute({
        uri: url,
        http_method: "POST",
        body: body,
        headers: { "Content-Type" => "application/atom+xml" }
      }.merge(options))

      { body: response.body, data: response.data }
    end

    def put(url, body, options = {})
      response = client.execute({
        uri: url,
        http_method: "PUT",
        body: body,
        headers: { "GData-Version" => "3.0", "Content-Type" => "application/atom+xml", "If-Match" => "*" }
      }.merge(options))

      { body: response.body, data: response.data }
    end
  end
end
