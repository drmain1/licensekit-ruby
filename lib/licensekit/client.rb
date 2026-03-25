require "cgi"
require "date"
require "json"
require "net/http"
require "time"
require "uri"

module LicenseKit
  class TransportError < StandardError; end

  def self.normalize_base_url(base_url)
    trimmed = base_url.to_s.strip
    raise ArgumentError, "base_url is required" if trimmed.empty?

    trimmed.sub(%r{/+\z}, "")
  end

  class DefaultTransport
    def call(request)
      uri = URI.parse(request.url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      if request.timeout
        http.open_timeout = request.timeout
        http.read_timeout = request.timeout
        http.write_timeout = request.timeout if http.respond_to?(:write_timeout=)
      end

      http_request = request_class(request.method).new(uri.request_uri)
      request.headers.each do |key, value|
        http_request[key] = value
      end
      http_request.body = request.body unless request.body.nil?

      response = http.request(http_request)
      TransportResponse.new(
        status: response.code.to_i,
        headers: response.each_header.to_h,
        body: response.body.to_s
      )
    rescue StandardError => e
      raise TransportError, e.message
    end

    private

    def request_class(method)
      case method.to_s.upcase
      when "GET" then Net::HTTP::Get
      when "POST" then Net::HTTP::Post
      when "PATCH" then Net::HTTP::Patch
      when "PUT" then Net::HTTP::Put
      when "DELETE" then Net::HTTP::Delete
      else
        raise ArgumentError, "Unsupported HTTP method: #{method}"
      end
    end
  end

  class BaseClient
    def initialize(base_url:, auth_type:, auth_value:, headers: nil, timeout: nil, user_agent: nil, retry_options: nil, transport: nil)
      @base_url = LicenseKit.normalize_base_url(base_url)
      @default_headers = normalize_headers(headers)
      @timeout = timeout
      @user_agent = user_agent
      @auth_type = auth_type
      @auth_value = auth_value
      @retry = retry_options || RetryOptions.new
      @transport = transport || DefaultTransport.new
    end

    private

    def perform_request(operation_id, request = nil, options: nil, **kwargs)
      perform_request_raw(operation_id, request, options: options, **kwargs).data
    end

    def perform_request_raw(operation_id, request = nil, options: nil, **kwargs)
      metadata = Generated::OPERATION_METADATA.fetch(operation_id)
      normalized_request = normalize_request(request, kwargs)
      url = build_url(metadata[:path], normalized_request)
      headers = build_headers(options, normalized_request)
      body = nil

      if normalized_request.key?(:body)
        headers["Content-Type"] = "application/json"
        body = JSON.generate(normalized_request[:body])
      end

      transport_request = TransportRequest.new(
        method: metadata[:method],
        url: url,
        headers: headers,
        body: body,
        timeout: options&.timeout || @timeout
      )

      response = send_with_retry(transport_request)
      success_kind = metadata[:success][response.status]
      raise ApiError.from_response(response.status, parse_error_body(response)) if success_kind.nil?

      RawResponse.new(
        status: response.status,
        headers: response.headers,
        data: parse_success_body(response, success_kind),
        response: response,
        body: response.body
      )
    end

    def normalize_request(request, kwargs)
      merged = {}
      merged.merge!(request) if request.is_a?(Hash)
      merged.merge!(kwargs.transform_keys(&:to_sym))
      merged
    end

    def build_url(path_template, request)
      path = path_template.dup
      path_values = request[:path]
      if path_values
        raise TypeError, "request[:path] must be a hash" unless path_values.is_a?(Hash)

        path_values.each do |key, value|
          escaped = CGI.escape(value.to_s).gsub("+", "%20")
          path.gsub!("{#{key}}", escaped)
        end
      end

      raise ArgumentError, "Missing path parameters for #{path_template}" if path.include?("{") || path.include?("}")

      query_values = request[:query]
      return "#{@base_url}#{path}" if query_values.nil? || query_values.empty?
      raise TypeError, "request[:query] must be a hash" unless query_values.is_a?(Hash)

      encoded = URI.encode_www_form(iter_query_params(query_values))
      "#{@base_url}#{path}?#{encoded}"
    end

    def iter_query_params(query)
      query.each_with_object([]) do |(key, value), items|
        normalize_query_value(key.to_s, value).each { |entry| items << entry }
      end
    end

    def normalize_query_value(key, value)
      case value
      when nil
        []
      when Array
        value.flat_map { |item| normalize_query_value(key, item) }
      when Date, DateTime, Time
        [[key, value.iso8601]]
      when true
        [[key, "true"]]
      when false
        [[key, "false"]]
      else
        [[key, value.to_s]]
      end
    end

    def build_headers(options, request)
      headers = @default_headers.dup
      headers.merge!(normalize_headers(options.headers)) if options&.headers

      headers["Accept"] ||= "application/json"
      headers["User-Agent"] ||= @user_agent if @user_agent

      case @auth_type
      when "bearer"
        headers["Authorization"] = "Bearer #{@auth_value}" if @auth_value
      when "license"
        headers["Authorization"] = "License #{@auth_value}" if @auth_value
      end

      headers["Idempotency-Key"] = request[:idempotency_key].to_s if request.key?(:idempotency_key)
      headers
    end

    def send_with_retry(transport_request)
      retries = @retry.retries
      retryable_methods = @retry.retryable_methods
      should_retry = retryable_methods.include?(transport_request.method.to_s.upcase)

      attempt = 0
      begin
        attempt += 1
        response = @transport.call(transport_request)
        coerce_transport_response(response)
      rescue StandardError => e
        raise e unless should_retry && attempt <= retries

        sleep([0.1 * attempt, 0.5].min)
        retry
      end
    end

    def coerce_transport_response(response)
      return response if response.is_a?(TransportResponse)

      if response.is_a?(Hash)
        return TransportResponse.new(
          status: response.fetch(:status) { response.fetch("status") },
          headers: response[:headers] || response["headers"] || {},
          body: response[:body] || response["body"] || ""
        )
      end

      if response.respond_to?(:status) && response.respond_to?(:headers) && response.respond_to?(:body)
        return TransportResponse.new(status: response.status, headers: response.headers, body: response.body)
      end

      raise TypeError, "transport must return a TransportResponse-compatible object"
    end

    def parse_success_body(response, kind)
      case kind
      when "empty"
        nil
      when "text"
        response.body.to_s
      else
        JSON.parse(response.body.to_s)
      end
    end

    def parse_error_body(response)
      content_type = header_value(response.headers, "Content-Type").to_s
      if content_type.include?("application/json")
        JSON.parse(response.body.to_s)
      else
        response.body.to_s
      end
    rescue JSON::ParserError
      nil
    end

    def normalize_headers(headers)
      return {} if headers.nil?
      raise TypeError, "headers must be a hash" unless headers.is_a?(Hash)

      headers.each_with_object({}) do |(key, value), result|
        result[key.to_s] = value.to_s
      end
    end

    def header_value(headers, name)
      return nil unless headers

      headers.each do |key, value|
        return value if key.to_s.downcase == name.downcase
      end
      nil
    end
  end
end
