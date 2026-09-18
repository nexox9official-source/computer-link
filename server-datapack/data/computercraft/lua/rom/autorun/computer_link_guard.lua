-- Astralium LinkOS guard.
-- This file is injected in CraftOS ROM by the server datapack and is read-only to players.

local ROOT = "/computer-link"
local ROLE = ROOT .. "/role.txt"

if not fs.exists(ROLE) then
  return
end

local okPolicy, policy = pcall(require, "computer_link_policy")
if not okPolicy or type(policy) ~= "table" then
  return
end

if policy.lockdown_clients ~= true then
  return
end

local base = tostring(policy.github_raw or "")
if base == "" then
  return
end
if string.sub(base, -1) ~= "/" then
  base = base .. "/"
end

-- Minimum local protection even when GitHub/HTTP is temporarily unavailable.
local expectedStartup = [[-- Computer Link / LinkOS
shell.run("/computer-link/boot.lua")
]]

local function writeStartup()
  local current = nil
  if fs.exists("/startup.lua") then
    local f = fs.open("/startup.lua", "r")
    if f then
      current = f.readAll()
      f.close()
    end
  end

  if current ~= expectedStartup then
    local f = fs.open("/startup.lua", "w")
    if f then
      f.write(expectedStartup)
      f.close()
    end
  end
end

writeStartup()

if not http or not http.get then
  return
end

local response = http.get(base .. "bootstrap/client_guard.lua?t="
  .. tostring(os.epoch and os.epoch("utc") or os.time()))
if not response then
  return
end

local source = response.readAll()
response.close()

local loader = load(source, "@astralium_linkos_guard.lua", "t", _ENV)
if not loader then
  return
end

pcall(loader)
