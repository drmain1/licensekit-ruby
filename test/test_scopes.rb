require_relative "test_helper"

class ScopesTest < Minitest::Test
  def test_get_required_scopes
    scopes = LicenseKit.get_required_scopes("createProduct")
    assert_equal ["product:write"], scopes
  end

  def test_has_required_scopes
    assert_equal true, LicenseKit.has_required_scopes("createProduct", ["product:write"])
    assert_equal true, LicenseKit.has_required_scopes("createProduct", ["admin"])
    assert_equal false, LicenseKit.has_required_scopes("createProduct", ["product:read"])
  end
end
