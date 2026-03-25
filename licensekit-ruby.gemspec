require_relative "lib/licensekit/version"

Gem::Specification.new do |spec|
  spec.name = "licensekit-ruby"
  spec.version = LicenseKit::VERSION
  spec.authors = ["David Main"]
  spec.email = ["dtmain@gmail.com"]

  spec.summary = "Ruby SDK for the LicenseKit licensing API"
  spec.description = "Typed-ish Ruby SDK for the LicenseKit licensing API with management, runtime, and system clients plus Ed25519 verification helpers."
  spec.homepage = "https://licensekit.dev"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6"

  spec.metadata = {
    "homepage_uri" => "https://licensekit.dev",
    "documentation_uri" => "https://licensekit.dev/docs/agent-quickstart",
    "changelog_uri" => "https://github.com/drmain1/licensekit-ruby/releases",
    "bug_tracker_uri" => "https://github.com/drmain1/licensekit-ruby/issues",
    "source_code_uri" => "https://github.com/drmain1/licensekit-ruby",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    Dir[
      ".gitignore",
      "LICENSE",
      "README.md",
      "examples/**/*",
      "lib/**/*.rb",
      "openapi/**/*",
      "scripts/**/*.rb",
      "test/**/*.rb"
    ]
  end
  spec.bindir = "exe"
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "ed25519", "~> 1.3.0"
end
