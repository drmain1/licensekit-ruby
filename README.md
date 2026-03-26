# `licensekit-ruby`

First-party Ruby SDK for `licensekit.dev`.

It provides Management, Runtime, and System clients for the LicenseKit licensing API, plus least-privilege scope metadata and Ed25519 runtime-signature verification helpers for activation, validation, metering, and offline-aware license flows.

## Why use it

- `LicenseKit::ManagementClient`, `LicenseKit::RuntimeClient`, and `LicenseKit::SystemClient`
- Runtime signature verification backed by `ed25519`
- Least-privilege scope discovery derived from the OpenAPI contract
- Hosted and self-hosted support through a configurable `base_url`

Links:

- [Agent quickstart](https://licensekit.dev/docs/agent-quickstart)
- [API contract notes](https://licensekit.dev/docs/api-contract)
- [OpenAPI spec](https://licensekit.dev/openapi.yaml)
- [LLM reference](https://licensekit.dev/llms.txt)
- [Source repository](https://github.com/drmain1/licensekit-ruby)

## Install

```bash
gem install licensekit-ruby
```

## Quick Start

```ruby
require "licensekit"

base_url = "https://api.licensekit.dev"

system = LicenseKit::SystemClient.new(base_url: base_url)
health = system.health
puts health["data"]["status"]

management = LicenseKit::ManagementClient.new(
  base_url: base_url,
  token: "lkm_..."
)

product = management.create_product(
  body: {
    "name" => "Example App",
    "code" => "example-app"
  }
)

runtime = LicenseKit::RuntimeClient.new(
  base_url: base_url,
  license_key: "lsk_..."
)

result = runtime.validate_license(
  body: {
    "fingerprint" => "host-123"
  }
)

public_keys = system.list_public_keys
verified = LicenseKit.verify_runtime_result(
  result,
  LicenseKit::PublicKeyStore.new(public_keys["data"])
)

puts [product["data"]["id"], verified.ok].join(" ")
```

## Package Shape

- `LicenseKit::ManagementClient`
  Uses `Authorization: Bearer <token>` for `/api/v1/...` management operations.
- `LicenseKit::RuntimeClient`
  Uses `Authorization: License <license-key>` for `/api/v1/license/...` runtime operations.
- `LicenseKit::SystemClient`
  Unauthenticated access to `/health`, `/healthz`, `/readyz`, `/metrics`, and `/api/v1/system/public-keys`.

Hosted deployments should prefer `/health` for liveness checks behind `api.licensekit.dev`.
`/healthz` remains available for local and self-hosted compatibility.

## Scope Metadata

```ruby
required = LicenseKit.get_required_scopes("createProduct")
allowed = LicenseKit.has_required_scopes("createProduct", ["product:write"])
```

## Raw Response Access

Each client exposes a `raw` companion for callers that need status codes and headers.

```ruby
system = LicenseKit::SystemClient.new(base_url: "https://api.licensekit.dev")
ready = system.raw.readyz

puts [ready.status, ready.data["data"]["status"]].join(" ")
```

## Development

```bash
bundle install --path vendor/bundle
ruby scripts/generate_from_openapi.rb
bundle exec ruby -Ilib:test test/test_client.rb
bundle exec ruby -Ilib:test test/test_scopes.rb
bundle exec ruby -Ilib:test test/test_verification.rb
gem build licensekit-ruby.gemspec
```

Generation uses the checked-in OpenAPI snapshot at [`openapi/openapi.yaml`](./openapi/openapi.yaml).
