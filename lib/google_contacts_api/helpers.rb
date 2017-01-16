module GoogleContactsApi
  module Helpers
    def do_retry
      tries ||= 3

      yield
    rescue => e
      if (tries -= 1).zero?
        raise e
      else
        retry
      end
    end

  end
end
