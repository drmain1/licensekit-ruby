require_relative "test_helper"

class ClientTest < Minitest::Test
  def test_management_client_normalizes_base_url_and_injects_bearer_auth
    transport = lambda do |request|
      assert_equal "https://api.licensekit.dev/api/v1/products?limit=25", request.url
      assert_equal "Bearer mgmt_test_token", request.headers["Authorization"]
      assert_equal "application/json", request.headers["Accept"]

      LicenseKit::TransportResponse.new(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate(
          "data" => [],
          "meta" => {
            "request_id" => "req_123",
            "timestamp" => "2026-03-24T00:00:00Z"
          }
        )
      )
    end

    client = LicenseKit::ManagementClient.new(
      base_url: "https://api.licensekit.dev///",
      token: "mgmt_test_token",
      transport: transport
    )

    response = client.list_products(query: { limit: 25 })

    assert_equal [], response["data"]
  end

  def test_runtime_client_injects_license_auth_and_idempotency_key
    transport = lambda do |request|
      assert_equal "License lic_test_key", request.headers["Authorization"]
      assert_equal "idem_123", request.headers["Idempotency-Key"]
      assert_equal "application/json", request.headers["Content-Type"]
      assert_equal "POST", request.method
      assert_equal({ "fingerprint" => "host-123" }, JSON.parse(request.body))

      LicenseKit::TransportResponse.new(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate(
          "data" => {
            "license_id" => "lic_1",
            "status" => "active",
            "license_type" => "subscription",
            "entitlement_version" => 1,
            "issued_at" => "2026-03-24T00:00:00Z",
            "next_check_at" => "2026-03-25T00:00:00Z",
            "device_id" => "dev_1",
            "features" => []
          },
          "signature" => {
            "alg" => "Ed25519",
            "kid" => "kid_1",
            "value" => "AQID"
          },
          "meta" => {
            "request_id" => "req_runtime",
            "timestamp" => "2026-03-24T00:00:00Z"
          }
        )
      )
    end

    client = LicenseKit::RuntimeClient.new(
      base_url: "https://api.licensekit.dev",
      license_key: "lic_test_key",
      transport: transport
    )

    response = client.activate_license(
      body: { "fingerprint" => "host-123" },
      idempotency_key: "idem_123"
    )

    assert_equal "lic_1", response["data"]["license_id"]
  end

  def test_system_client_health_alias_and_readyz_503_are_successes
    transport = lambda do |request|
      body =
        if request.url.end_with?("/health")
          {
            "data" => { "status" => "ok" },
            "meta" => {
              "request_id" => "req_health",
              "timestamp" => "2026-03-24T00:00:00Z"
            }
          }
        elsif request.url.end_with?("/readyz")
          {
            "data" => { "status" => "not_ready", "db" => "down" },
            "meta" => {
              "request_id" => "req_ready",
              "timestamp" => "2026-03-24T00:00:00Z"
            }
          }
        else
          raise "Unexpected path: #{request.url}"
        end

      status = request.url.end_with?("/readyz") ? 503 : 200
      LicenseKit::TransportResponse.new(
        status: status,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate(body)
      )
    end

    client = LicenseKit::SystemClient.new(
      base_url: "https://api.licensekit.dev",
      transport: transport
    )

    health = client.health
    ready = client.raw.readyz

    assert_equal "ok", health["data"]["status"]
    assert_equal 503, ready.status
    assert_equal "not_ready", ready.data["data"]["status"]
  end

  def test_error_envelopes_raise_api_error
    transport = lambda do |_request|
      LicenseKit::TransportResponse.new(
        status: 403,
        headers: { "Content-Type" => "application/json" },
        body: JSON.generate(
          "error" => {
            "code" => "TOKEN_SCOPE_DENIED",
            "message" => "scope denied"
          },
          "meta" => {
            "request_id" => "req_forbidden",
            "timestamp" => "2026-03-24T00:00:00Z"
          }
        )
      )
    end

    client = LicenseKit::ManagementClient.new(
      base_url: "https://api.licensekit.dev",
      token: "mgmt_test_token",
      transport: transport
    )

    error = assert_raises(LicenseKit::ApiError) { client.list_products }
    assert_equal 403, error.status
    assert_equal "TOKEN_SCOPE_DENIED", error.code
    assert_equal "req_forbidden", error.request_id
  end
end
