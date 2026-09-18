local LINKOS = "/computer-link/src/os/linkos.lua"

-- Remove obsolete maintenance files which must never be exposed on clients.
for _, path in ipairs({
  "/computer-link/src/client/cli.lua",
  "/computer-link/src/client/hack.lua",
  "/computer-link/src/client/hacked_state.lua",
  "/computer-link/src/os/hacker_console.lua",
  "/computer-link/src/server"
}) do
  if fs.exists(path) then
    pcall(fs.delete, path)
  end
end

local function colour(c)
  if term.isColor and term.isColor() then
    term.setTextColor(c)
  end
end

local function recovery(message)
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()
  term.setCursorPos(1, 1)

  colour(colors.red)
  print("================================")
  print("       LINK OS RECOVERY")
  print("================================")
  colour(colors.white)
  print()
  print(tostring(message or "Erreur systeme."))
  print()
  print("Le mode shell n'est pas disponible sur un poste joueur.")
  print("Reparation au prochain demarrage...")
  sleep(3)
  os.reboot()
end

if not fs.exists(LINKOS) then
  recovery("Fichiers LinkOS manquants.")
  return
end

local program, loadErr = loadfile(LINKOS)
if not program then
  recovery("LinkOS invalide: " .. tostring(loadErr))
  return
end

local ok, runErr = pcall(program)
if not ok then
  recovery("LinkOS a rencontre une erreur: " .. tostring(runErr))
end
