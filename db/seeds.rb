# Permissions (resource:action convention)
resources = %w[users roles permissions]
actions = %w[read write delete]
permissions = resources.flat_map do |resource|
  actions.map do |action|
    Permission.find_or_create_by!(resource: resource, action: action) do |p|
      p.description = "#{action.capitalize} #{resource}"
    end
  end
end

admin = Role.find_or_create_by!(name: "admin") { |r| r.description = "Full system access" }
member = Role.find_or_create_by!(name: "member") { |r| r.description = "Standard user access" }

admin.permissions = permissions                                     # admin: everything
member.permissions = Permission.where(resource: "users", action: "read")  # member: read users

admin_user = User.find_or_initialize_by(email: "admin@example.com")
admin_user.assign_attributes(password: "Password123!", first_name: "Admin", last_name: "User")
admin_user.save!
admin_user.roles = [ admin ]

member_user = User.find_or_initialize_by(email: "member@example.com")
member_user.assign_attributes(password: "Password123!", first_name: "Member", last_name: "User")
member_user.save!
member_user.roles = [ member ]

puts "Seeded: #{Permission.count} permissions, #{Role.count} roles, #{User.count} users"
