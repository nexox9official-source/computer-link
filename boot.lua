local ROOT = "/computer-link"
local ROLE_FILE = ROOT .. "/role.txt"

local function fail(message)
  term.setTextColor(colors.red)
  print("Computer Link: " .. message)
  term.setTextColor(colors.white)
end

if not fs.exists(ROLE_FILE) then
  fail("role.txt introuvable. Relance install.lua.")
  return
end

local file = fs.open(ROLE_FILE, "r")
local role = file.readAll():gsub("%s+", "")
file.close()

if role == "server" then
  shell.run(ROOT .. "/src/server/server.lua")
elseif role == "client" then
  shell.run(ROOT .. "/src/client/client.lua")
else
  fail("role inconnu: " .. tostring(role))
end
