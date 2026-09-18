local LINKOS = "/computer-link/src/os/linkos.lua"
local CLI = "/computer-link/src/client/cli.lua"

local function colour(c)
  if term.isColor and term.isColor() then
    term.setTextColor(c)
  end
end

if not fs.exists(LINKOS) then
  colour(colors.orange)
  print("LinkOS est absent. Demarrage du mode classique.")
  colour(colors.white)
  shell.run(CLI)
  return
end

local ok, err = pcall(function()
  shell.run(LINKOS)
end)

if not ok then
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)

  colour(colors.red)
  print("LinkOS a rencontre une erreur.")
  print(tostring(err))
  colour(colors.white)
  print()
  print("Demarrage du mode classique dans 2 secondes...")
  sleep(2)

  if fs.exists(CLI) then
    shell.run(CLI)
  end
end
