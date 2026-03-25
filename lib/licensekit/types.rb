module LicenseKit
  class RetryOptions
    attr_reader :retries, :retryable_methods

    def initialize(retries: 0, retryable_methods: ["GET"])
      @retries = retries
      @retryable_methods = Array(retryable_methods).map(&:to_s).map(&:upcase).freeze
    end
  end

  class RequestOptions
    attr_reader :headers, :timeout

    def initialize(headers: nil, timeout: nil)
      @headers = headers
      @timeout = timeout
    end
  end

  class RawResponse
    attr_reader :status, :headers, :data, :response, :body

    def initialize(status:, headers:, data:, response:, body:)
      @status = status
      @headers = headers
      @data = data
      @response = response
      @body = body
    end
  end

  class TransportRequest
    attr_reader :method, :url, :headers, :body, :timeout

    def initialize(method:, url:, headers:, body:, timeout:)
      @method = method
      @url = url
      @headers = headers
      @body = body
      @timeout = timeout
    end
  end

  class TransportResponse
    attr_reader :status, :headers, :body

    def initialize(status:, headers:, body:)
      @status = Integer(status)
      @headers = headers
      @body = body
    end
  end
end
