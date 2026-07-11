# Caps parameter nesting depth to stop deeply-nested-payload DoS. Full request BODY
# size limiting belongs at the reverse proxy / load balancer (see Section 14).
#
# Rails/Rack default param_depth_limit is 100 on older Rack; tighten to 32 for an API
# that only ever expects shallow JSON. (Rack 3.2 already defaults to 32 — setting it
# explicitly pins the guarantee regardless of the bundled Rack version.)

# key_space_limit was removed in Rack 3; guard so this stays version-portable.
Rack::Utils.key_space_limit = 65_536 if Rack::Utils.respond_to?(:key_space_limit=)
Rack::Utils.param_depth_limit = 32
