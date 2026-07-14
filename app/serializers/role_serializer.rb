class RoleSerializer < ApplicationSerializer
  def serialize
    { id: record.id, name: record.name, description: record.description,
      permissions: record.permissions.map(&:name) }
  end
end
