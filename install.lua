local BASE = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/"
local ROOT = "/computer-link"

local args = { ... }

local function colour(value)
  if term.isColor and term.isColor() then
    term.setTextColor(value)
  end
end

local function header()
  term.clear()
  term.setCursorPos(1, 1)
  colour(colors.cyan)
  print("================================")
  print("        COMPUTER LINK")
  print("       ASTRALNET INSTALLER")
  print("================================")
  colour(colors.white)
  print()
end

local function get(url)
  local response, err = http.get(url)

  if not response then
    return nil, err or "HTTP error"
  end

  local content = response.readAll()
  response.close()
  return content
end

local function writeFile(path, content)
  local dir = fs.getDir(path)

  if dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end

  local file = fs.open(path, "w")
  if not file then
    return false, "Impossible d'ecrire " .. path
  end

  file.write(content)
  file.close()
  return true
end

local function chooseRole()
  local role = string.lower(args[1] or "")

  if role == "mer" then role = "server" end

  if role == "server" or role == "client" then
    return role
  end

  print("Quel role pour ce Computer ?")
  print()
  colour(colors.yellow)
  print("  1 - MER SERVER")
  colour(colors.white)
  print("      Serveur central AstralNet")
  print()
  colour(colors.lightBlue)
  print("  2 - CLIENT")
  colour(colors.white)
  print("      Terminal joueur / pays")
  print()
  write("Choix [1/2]: ")

  while true do
    local choice = read()

    if choice == "1" then return "server" end
    if choice == "2" then return "client" end

    write("Tape 1 ou 2: ")
  end
end

local function backupStartup()
  local startup = "/startup.lua"

  if not fs.exists(startup) then
    return nil
  end

  local index = 1
  local backup = "/startup.computer-link-backup.lua"

  while fs.exists(backup) do
    index = index + 1
    backup = "/startup.computer-link-backup-" .. index .. ".lua"
  end

  fs.copy(startup, backup)
  return backup
end

header()

if not http or not http.get then
  colour(colors.red)
  print("HTTP n'est pas disponible.")
  colour(colors.white)
  print("Active HTTP dans la configuration CC:Tweaked.")
  return
end

local role = chooseRole()

print()
print("Role choisi: " .. string.upper(role))
print("Lecture du manifest...")

local manifestSource, manifestError = get(BASE .. "manifest.lua")
if not manifestSource then
  colour(colors.red)
  print("Impossible de telecharger le manifest.")
  print(tostring(manifestError))
  colour(colors.white)
  return
end

local loader, loadError = load(manifestSource, "@manifest.lua", "t", {})
if not loader then
  colour(colors.red)
  print("Manifest invalide: " .. tostring(loadError))
  colour(colors.white)
  return
end

local okManifest, manifest = pcall(loader)
if not okManifest or type(manifest) ~= "table" then
  colour(colors.red)
  print("Impossible de charger le manifest.")
  colour(colors.white)
  return
end

print("Version: " .. tostring(manifest.version))
print()

if not fs.exists(ROOT) then
  fs.makeDir(ROOT)
end

for index, path in ipairs(manifest.files or {}) do
  write("[" .. index .. "/" .. #manifest.files .. "] " .. path .. " ... ")

  local content, err = get(BASE .. path)

  if not content then
    colour(colors.red)
    print("ERREUR")
    colour(colors.white)
    print(tostring(err))
    print("Installation interrompue.")
    return
  end

  local success, writeError = writeFile(ROOT .. "/" .. path, content)

  if not success then
    colour(colors.red)
    print("ERREUR")
    colour(colors.white)
    print(tostring(writeError))
    return
  end

  colour(colors.lime)
  print("OK")
  colour(colors.white)
end

writeFile(ROOT .. "/role.txt", role .. "\n")

local backup = backupStartup()
local startupSource = [[-- Computer Link / AstralNet
shell.run("/computer-link/boot.lua")
]]

local success, startupError = writeFile("/startup.lua", startupSource)
if not success then
  colour(colors.red)
  print("Impossible d'installer startup.lua: " .. tostring(startupError))
  colour(colors.white)
  return
end

print()
colour(colors.lime)
print("================================")
print(" INSTALLATION TERMINEE")
print("================================")
colour(colors.white)
print("Role    : " .. string.upper(role))
print("Version : " .. tostring(manifest.version))

if backup then
  print("Ancien startup sauvegarde:")
  print(backup)
end

print()

if role == "server" then
  print("Place un Wireless Modem sur ce PC.")
  print("Ce Computer deviendra le serveur MER.")
else
  print("Place un Wireless Modem sur ce PC.")
  print("Le client cherchera MER au demarrage.")
end

print()
colour(colors.yellow)
print("Tape 'reboot' pour demarrer Computer Link.")
colour(colors.white)
