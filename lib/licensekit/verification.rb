require "base64"
require "ed25519"
require "json"

module LicenseKit
  class VerificationResult
    attr_reader :key

    def initialize(ok:, key:)
      @ok = ok
      @key = key
    end

    def ok
      @ok
    end
  end

  class PublicKeyStore
    def initialize(keys = nil)
      @keys = {}
      @verify_keys = {}
      Array(keys).each { |key| add(key) }
    end

    def add(key)
      @keys[key.fetch("kid")] = key
      @verify_keys.delete(key.fetch("kid"))
    end

    def add_all(keys)
      Array(keys).each { |key| add(key) }
    end

    def get(kid)
      @keys[kid]
    end

    def values
      @keys.values
    end

    def verify_key(kid)
      key = get(kid)
      raise TypeError, "Unknown public key kid: #{kid}" if key.nil?

      @verify_keys[kid] ||= Ed25519::VerifyKey.new(LicenseKit.send(:decode_base64, key.fetch("public_key")))
    end
  end

  def self.find_public_key(keys, kid)
    if keys.is_a?(PublicKeyStore)
      keys.get(kid)
    else
      Array(keys).find { |key| key["kid"] == kid }
    end
  end

  def self.verify_runtime_payload(data, signature, keys)
    public_key = find_public_key(keys, signature.fetch("kid"))
    raise TypeError, "Unknown public key kid: #{signature.fetch('kid')}" if public_key.nil?

    if public_key.fetch("algorithm") != "Ed25519" || signature.fetch("alg") != "Ed25519"
      raise TypeError, "Unsupported signature algorithm: expected Ed25519, received key=#{public_key.fetch('algorithm')}, signature=#{signature.fetch('alg')}"
    end

    verify_key = keys.is_a?(PublicKeyStore) ? keys.verify_key(public_key.fetch("kid")) : Ed25519::VerifyKey.new(LicenseKit.send(:decode_base64, public_key.fetch("public_key")))
    payload = stable_json_bytes(data)
    signature_bytes = LicenseKit.send(:decode_base64, signature.fetch("value"))

    begin
      verify_key.verify(signature_bytes, payload)
      VerificationResult.new(ok: true, key: public_key)
    rescue Ed25519::VerifyError
      VerificationResult.new(ok: false, key: public_key)
    end
  end

  def self.verify_runtime_result(result, keys)
    verify_runtime_payload(result.fetch("data"), result.fetch("signature"), keys)
  end

  def self.stable_json_bytes(data)
    JSON.generate(data).encode("UTF-8")
  end

  def self.decode_base64(value)
    Base64.strict_decode64(value.to_s)
  rescue ArgumentError => e
    raise TypeError, "Malformed base64 input: #{e.message}"
  end

  private_class_method :stable_json_bytes, :decode_base64
end
