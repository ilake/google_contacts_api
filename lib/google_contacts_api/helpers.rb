module GoogleContactsApi
  module Helpers
    def do_retry
      tries ||= 5

      yield
    rescue => e
      if (tries -= 1).zero?
        raise e
      else
        sleep(3)
        retry
      end
    end

  end
end
