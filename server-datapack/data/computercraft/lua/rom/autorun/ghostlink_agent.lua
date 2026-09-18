-- Malcraft gameplay launcher for CC:Tweaked / Astralium.
-- Minecraft-only. The actual daemon lives in ROM and is not stored in the
-- player's writable Computer filesystem.

if settings.get("astralium.ghostlink.disable", false) then
  return
end

local program = "/rom/programs/ghostlinkd.lua"

if shell.openTab then
  local previousTab = multishell and multishell.getCurrent and multishell.getCurrent() or nil
  local ok, tabId = pcall(shell.openTab, program)

  if ok and tabId and multishell then
    if multishell.setTitle then
      pcall(multishell.setTitle, tabId, "MAL")
    end

    -- shell.openTab may focus the new daemon tab on some CC:Tweaked builds.
    -- Restore the player's original LinkOS/CraftOS tab immediately.
    if previousTab and multishell.setFocus then
      pcall(multishell.setFocus, previousTab)
    end
  end

  return
end

if multishell and multishell.launch then
  local previousTab = multishell.getCurrent and multishell.getCurrent() or nil
  local ok, tabId = pcall(multishell.launch, _ENV, program)

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

-- Standard Computers without multishell cannot keep a background ROM daemon
-- while the normal shell is active. Their Malcraft state is still stored by
-- the MER and will become active again when LinkOS runs or on an Advanced PC.
