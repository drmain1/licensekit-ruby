module LicenseKit
  class ApiError < StandardError
    attr_reader :status, :code, :detail, :request_id, :timestamp, :body

    def initialize(status:, code:, message:, detail: nil, request_id: nil, timestamp: nil, body: nil)
      super(message)
      @status = status
      @code = code
      @detail = detail
      @request_id = request_id
      @timestamp = timestamp
      @body = body
    end

    def self.from_response(status, body)
      envelope = LicenseKit.parse_error_envelope(body)
      return new(status: status, code: "UNKNOWN_ERROR", message: "Request failed with status #{status}", body: body) if envelope.nil?

      meta = envelope["meta"] || {}
      new(
        status: status,
        code: envelope["error"]["code"],
        message: envelope["error"]["message"],
        detail: envelope["error"]["detail"],
        request_id: meta["request_id"],
        timestamp: meta["timestamp"],
        body: body
      )
    end
  end

  def self.api_error?(value)
    value.is_a?(ApiError)
  end

  def self.parse_error_envelope(body)
    return nil unless body.is_a?(Hash)

    error = body["error"]
    return nil unless error.is_a?(Hash)
    return nil unless error["code"].is_a?(String) && error["message"].is_a?(String)

    result = {
      "error" => {
        "code" => error["code"],
        "message" => error["message"]
      }
    }

    result["error"]["detail"] = error["detail"] if error["detail"].is_a?(String)

    meta = body["meta"]
    if meta.is_a?(Hash) && meta["request_id"].is_a?(String) && meta["timestamp"].is_a?(String)
      result["meta"] = {
        "request_id" => meta["request_id"],
        "timestamp" => meta["timestamp"]
      }
    end

    result
  end
end
