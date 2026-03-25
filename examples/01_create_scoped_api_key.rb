require "licensekit"

base_url = ENV.fetch("LICENSEKIT_BASE_URL", "https://api.licensekit.dev")
management = LicenseKit::ManagementClient.new(
  base_url: base_url,
  token: ENV.fetch("LICENSEKIT_MANAGEMENT_TOKEN")
)

response = management.create_api_key(
  body: {
    "name" => "product-read",
    "scopes" => ["product:read"]
  }
)

puts response["data"]["api_key"]["name"]
