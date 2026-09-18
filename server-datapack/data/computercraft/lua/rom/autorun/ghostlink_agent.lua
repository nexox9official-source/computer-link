-- GhostLink gameplay launcher for CC:Tweaked / Astralium.
-- Minecraft-only. The actual daemon lives in ROM and is not stored in the
-- player's writable Computer filesystem.

if settings.get("astralium.ghostlink.disable", false) then
  return
end

local program = "/rom/programs/ghostlinkd.lua"

if shell.openTab then
  pcall(shell.openTab, program)
  return
end

if multishell and multishell.launch then
  pcall(multishell.launch, _ENV, program)
  return
end

-- Standard Computers without multishell cannot keep a background ROM daemon
-- while the normal shell is active. Their GhostLink state is still stored by
-- the MER and will become active again when LinkOS runs or on an Advanced PC.
