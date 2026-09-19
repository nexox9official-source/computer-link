-- Malcraft gameplay launcher for CC:Tweaked / Astralium.
-- Minecraft-only. The daemon and transport never access the player's real PC.

if settings.get("astralium.ghostlink.disable", false) then
  return
end

-- A standard Computer uses an inner shell so the Malcraft daemon can remain
-- alive in a parallel coroutine. Prevent that child shell from spawning a
-- second daemon recursively.
local CHILD_SHELL = "astralium.malcraft.child_shell"
if settings.get(CHILD_SHELL, false) then
  return
end

local program = "/rom/programs/ghostlinkd.lua"

-- Buffer the player's terminal through a window. This lets the ROM daemon
-- expose the in-game CraftOS screen to the LinkSec operator even when LinkOS
-- was never installed on this Computer.
local captureSurface = rawget(_G, "__malcraft_capture")
if not captureSurface then
  local parent = term.current()
  local width, height = parent.getSize()
  captureSurface = window.create(parent, 1, 1, width, height, true)
  term.redirect(captureSurface)
  rawset(_G, "__malcraft_capture", captureSurface)
end

local function daemonEnvironment()
  return setmetatable({
    __malcraft_capture = captureSurface
  }, {__index = _ENV})
end

local function runDaemon(...)
  local env = daemonEnvironment()
  local loader, err = loadfile(program, nil, env)

  if not loader then
    return false, err
  end

  local ok, runErr = pcall(loader, ...)
  return ok, runErr
end

-- Immediate carrier scan at every boot. A contaminated disk therefore marks
-- a Computer before the normal CraftOS prompt appears.
runDaemon("--oneshot")

-- Keep Malcraft inside the existing CraftOS tab instead of creating a visible
-- multishell tab. This works on both Basic and Advanced Computers: the daemon
-- runs as a parallel coroutine while the player uses a nested CraftOS shell.
-- The CHILD_SHELL flag prevents the nested shell from starting a second agent.
settings.set(CHILD_SHELL, true)

local ok = pcall(function()
  parallel.waitForAny(
    function()
      runDaemon()
    end,
    function()
      shell.run("shell")
    end
  )
end)

settings.unset(CHILD_SHELL)

-- If the nested shell exits, return to the original CraftOS shell. No extra
-- tab is ever created, so there is no MAL/Malcraft indicator in multishell.
if not ok then
  return
end
