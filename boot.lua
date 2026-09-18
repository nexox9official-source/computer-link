local ROOT = "/computer-link"
local ROLE_FILE = ROOT .. "/role.txt"
local CONFIG_FILE = ROOT .. "/src/common/config.lua"

local function fail(message)
  term.setTextColor(colors.red)
  print("Computer Link: " .. message)
  term.setTextColor(colors.white)
end

if fs.exists(CONFIG_FILE) then
  local config = dofile(CONFIG_FILE)

  if fs.exists(config.CRASH_FLAG) then
    term.clear()
    term.setCursorPos(1, 1)
    if term.isColor and term.isColor() then term.setTextColor(colors.red) end
    print("================================")
    print("       SYSTEM FAILURE")
    print("================================")
    if term.isColor and term.isColor() then term.setTextColor(colors.white) end
    print()
    print("Computer Link a subi un crash distant.")
    print("Recuperation du systeme...")

    for remaining = config.CRASH_RECOVERY_SECONDS, 1, -1 do
      write("\rRedemarrage dans " .. remaining .. "s   ")
      sleep(1)
    end

    print()
    fs.delete(config.CRASH_FLAG)
  end
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
