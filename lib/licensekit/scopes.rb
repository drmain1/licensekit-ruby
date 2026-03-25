module LicenseKit
  MANAGEMENT_SCOPES = Generated::MANAGEMENT_SCOPES
  OPERATION_SCOPES = Generated::OPERATION_SCOPES

  def self.get_required_scopes(operation_id)
    entry = OPERATION_SCOPES.fetch(operation_id)
    entry[:scopes]
  end

  def self.has_required_scopes(operation_id, scopes)
    granted = Array(scopes).map(&:to_s)
    return true if granted.include?("admin")

    get_required_scopes(operation_id).all? { |scope| granted.include?(scope) }
  end
end
