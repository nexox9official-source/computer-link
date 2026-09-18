-- Malcraft gameplay launcher for CC:Tweaked / Astralium.
-- Minecraft-only. The actual daemon lives in ROM and is not stored in the
-- player's writable Computer filesystem.

if settings.get("astralium.ghostlink.disable", false) then
  return
end

local program = "/rom/programs/ghostlinkd.lua"

-- Buffer the player's normal terminal through a window. CC:Tweaked windows
-- retain every rendered line, allowing an infected Advanced Computer to expose
-- a live in-game screen to LinkSec without requiring LinkOS.
local captureSurface = rawget(_G, "__malcraft_capture")
if not captureSurface then
  local parent = term.current()
  local width, height = parent.getSize()
  captureSurface = window.create(parent, 1, 1, width, height, true)
  term.redirect(captureSurface)
  rawset(_G, "__malcraft_capture", captureSurface)
end

-- Always perform one immediate carrier scan at boot. This also gives standard
-- Computers (without multishell) a way to become infected from an inserted
-- Malcraft data disk without ever installing LinkOS.
pcall(shell.run, program, "--oneshot")

if multishell and multishell.launch then
  local previousTab = multishell.getCurrent and multishell.getCurrent() or nil
  local env = setmetatable({
    __malcraft_capture = captureSurface
  }, {__index = _ENV})

  local ok, tabId = pcall(multishell.launch, env, program)

  if ok and tabId then
    if multishell.setTitle then
      pcall(multishell.setTitle, tabId, "MAL")
    end
    if previousTab and multishell.setFocus then
      pcall(multishell.setFocus, previousTab)
    end
  end

  return
end

if shell.openTab then
  local previousTab = multishell and multishell.getCurrent and multishell.getCurrent() or nil
  local ok, tabId = pcall(shell.openTab, program)

  if ok and tabId and multishell then
    if multishell.setTitle then
      pcall(multishell.setTitle, tabId, "MAL")
    end
    if previousTab and multishell.setFocus then
      pcall(multishell.setFocus, previousTab)
    end
  end

  return
end

-- Standard Computers without multishell cannot keep a background ROM daemon
-- while the normal shell is active. Their Malcraft state is still stored by
-- the MER and will become active again when LinkOS runs or on an Advanced PC.
