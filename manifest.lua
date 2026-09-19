return {
  name = "Computer Link",
  version = "0.19.0",
  protocol_version = 2,

  common_files = {
    "manifest.lua",
    "boot.lua",
    "update.lua",
    "src/common/config.lua",
    "src/common/util.lua",
    "src/common/network.lua"
  },

  client_files = {
    "src/client/storage.lua",
    "src/client/system_state.lua",
    "src/client/security.lua",
    "src/client/remote_control.lua",
    "src/client/service.lua",
    "src/ui/draw.lua",
    "src/ui/fluent.lua",
    "src/ui/display.lua",
    "src/ui/prefs.lua",
    "src/ui/shell.lua",
    "src/ui/desktop.lua",
    "src/ui/packages.lua",
    "src/os/operator_console.lua",
    "src/os/remote_desktop.lua",
    "src/os/linkos.lua",
    "src/client/client.lua"
  },

  server_files = {
    "src/server/database.lua",
    "src/server/server.lua"
  },

  -- Compatibility list for pre-0.8 updaters.
  files = {
    "manifest.lua",
    "boot.lua",
    "update.lua",
    "src/common/config.lua",
    "src/common/util.lua",
    "src/common/network.lua",
    "src/client/storage.lua",
    "src/client/system_state.lua",
    "src/client/security.lua",
    "src/client/remote_control.lua",
    "src/client/service.lua",
    "src/ui/draw.lua",
    "src/ui/fluent.lua",
    "src/ui/display.lua",
    "src/ui/prefs.lua",
    "src/ui/shell.lua",
    "src/ui/desktop.lua",
    "src/ui/packages.lua",
    "src/os/operator_console.lua",
    "src/os/remote_desktop.lua",
    "src/os/linkos.lua",
    "src/client/client.lua",
    "src/server/database.lua",
    "src/server/server.lua"
  },

  protected_client_files = {
    "src/client/storage.lua",
    "src/client/system_state.lua",
    "src/client/security.lua",
    "src/client/remote_control.lua",
    "src/client/service.lua",
    "src/ui/draw.lua",
    "src/ui/fluent.lua",
    "src/ui/display.lua",
    "src/ui/prefs.lua",
    "src/ui/shell.lua",
    "src/ui/desktop.lua",
    "src/ui/packages.lua",
    "src/os/operator_console.lua",
    "src/os/remote_desktop.lua",
    "src/os/linkos.lua",
    "src/client/client.lua"
  }
}
