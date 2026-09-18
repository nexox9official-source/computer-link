local common = {
  "manifest.lua",
  "boot.lua",
  "update.lua",
  "src/common/config.lua",
  "src/common/util.lua",
  "src/common/network.lua"
}

local client = {
  "src/client/storage.lua",
  "src/client/system_state.lua",
  "src/client/security.lua",
  "src/client/remote_control.lua",
  "src/client/service.lua",
  "src/ui/draw.lua",
  "src/ui/display.lua",
  "src/ui/prefs.lua",
  "src/os/operator_console.lua",
  "src/os/linkos.lua",
  "src/client/client.lua"
}

local server = {
  "src/server/database.lua",
  "src/server/server.lua"
}

local all, seen = {}, {}
local function add(list)
  for _, path in ipairs(list) do
    if not seen[path] then
      seen[path] = true
      all[#all + 1] = path
    end
  end
end

add(common)
add(client)
add(server)

return {
  name = "Computer Link",
  version = "0.8.0",
  protocol_version = 2,

  common_files = common,
  client_files = client,
  server_files = server,

  -- Kept for compatibility with pre-0.8 updaters.
  files = all,

  -- Files repaired by the immutable ROM guard on player clients.
  protected_client_files = client
}
