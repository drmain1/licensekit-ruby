require "licensekit"

base_url = ENV.fetch("LICENSEKIT_BASE_URL", "https://api.licensekit.dev")
runtime = LicenseKit::RuntimeClient.new(
  base_url: base_url,
  license_key: ENV.fetch("LICENSEKIT_LICENSE_KEY")
)
system = LicenseKit::SystemClient.new(base_url: base_url)

result = runtime.validate_license(
  body: {
    "fingerprint" => ENV.fetch("LICENSEKIT_FINGERPRINT", "host-123")
  }
)

public_keys = system.list_public_keys
verified = LicenseKit.verify_runtime_result(
  result,
  LicenseKit::PublicKeyStore.new(public_keys["data"])
)

puts [result["data"]["status"], verified.ok].join(" ")
