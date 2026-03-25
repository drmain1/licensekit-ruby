require_relative "test_helper"
require "ed25519"

class VerificationTest < Minitest::Test
  def test_verify_runtime_payload_and_tamper_detection
    signing_key = Ed25519::SigningKey.generate
    verify_key = signing_key.verify_key
    payload = {
      "license_id" => "lic_1",
      "status" => "active"
    }
    payload_bytes = '{"license_id":"lic_1","status":"active"}'
    signature_bytes = signing_key.sign(payload_bytes)
    key_store = LicenseKit::PublicKeyStore.new(
      [
        {
          "kid" => "kid_live",
          "algorithm" => "Ed25519",
          "public_key" => Base64.strict_encode64(verify_key.to_bytes),
          "status" => "active",
          "created_at" => "2026-03-24T00:00:00Z"
        }
      ]
    )
    signature = {
      "alg" => "Ed25519",
      "kid" => "kid_live",
      "value" => Base64.strict_encode64(signature_bytes)
    }

    verified = LicenseKit.verify_runtime_payload(payload, signature, key_store)
    tampered = LicenseKit.verify_runtime_result(
      {
        "data" => payload.merge("status" => "revoked"),
        "signature" => signature
      },
      key_store
    )

    assert_equal true, verified.ok
    assert_equal "kid_live", verified.key["kid"]
    assert_equal false, tampered.ok
  end
end
