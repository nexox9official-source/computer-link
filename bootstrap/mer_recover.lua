-- Astralium MER recovery bootstrap.
-- This entry point is intentionally restricted to the designated MER Computer.
local OFFICIAL_MER_ID = 1
local INSTALL_URL = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua"

local function colour(c)
  if term.isColor and term.isColor() then term.setTextColor(c) end
end

term.clear()
term.setCursorPos(1, 1)
colour(colors.cyan)
print("================================")
print("     ASTRALIUM MER RECOVERY")
print("================================")
colour(colors.white)

local id = os.getComputerID()
print("Computer ID : #" .. tostring(id))
print("MER attendu : #" .. tostring(OFFICIAL_MER_ID))
print()

if id ~= OFFICIAL_MER_ID then
  colour(colors.red)
  print("ACCES REFUSE")
  colour(colors.white)
  print("Ce Computer n'est pas le MER Astralium officiel.")
  return
end

if not http or not http.get then
  colour(colors.red)
  print("HTTP indisponible dans CC:Tweaked.")
  colour(colors.white)
  return
end

-- Add a cache-buster so a recently reset MER cannot receive a stale installer
-- from an intermediary cache.
local url = INSTALL_URL .. "?recovery=" ..
  tostring(os.epoch and os.epoch("utc") or os.time())

print("Telechargement de l'installateur MER...")
local response, err = http.get(url)
if not response then
  colour(colors.red)
  print("Telechargement impossible: " .. tostring(err))
  colour(colors.white)
  return
end

local source = response.readAll()
response.close()

local loader, loadErr = load(source, "@astralium_mer_install.lua", "t", _ENV)
if not loader then
  colour(colors.red)
  print("Installateur invalide: " .. tostring(loadErr))
  colour(colors.white)
  return
end

local ok, runErr = pcall(loader, "server")
if not ok then
  colour(colors.red)
  print("Installation MER echouee: " .. tostring(runErr))
  colour(colors.white)
  return
end

if fs.exists("/computer-link/role.txt") then
  local f = fs.open("/computer-link/role.txt", "r")
  local role = f and f.readAll():gsub("%s+", "") or ""
  if f then f.close() end

  if role == "server" then
    colour(colors.lime)
    print()
    print("MER reinstalle avec succes.")
    colour(colors.white)
    print("Tape: reboot")
  else
    colour(colors.orange)
    print()
    print("Installation terminee mais role detecte: " .. tostring(role))
    colour(colors.white)
  end
end
