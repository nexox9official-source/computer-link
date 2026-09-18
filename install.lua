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
  print("       LINK OS INSTALLER")
  print("================================")
  colour(colors.white)
  print("PC ID : #" .. os.getComputerID())
  print()
end

local function get(url)
  local response, err = http.get(url)
  if not response then return nil, err or "HTTP error" end
  local content = response.readAll()
  response.close()
  return content
end

local function writeFile(path, content)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end

  local file = fs.open(path, "w")
  if not file then return false, "Impossible d'ecrire " .. path end

  file.write(content)
  file.close()
  return true
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local file = fs.open(path, "r")
  if not file then return nil end
  local content = file.readAll()
  file.close()
  return content
end

local function currentRole()
  local content = readFile(ROOT .. "/role.txt")
  if not content then return nil end
  return content:gsub("%s+", "")
end

local function serverPolicy()
  local ok, policy = pcall(require, "computer_link_policy")
  if ok and type(policy) == "table" then return policy end
  return nil
end

local function canInstallMer()
  -- An already-provisioned MER may reinstall itself.
  if currentRole() == "server" then return true end

  local policy = serverPolicy()
  if not policy then return false end

  if policy.allow_public_mer_install == true then return true end

  return type(policy.mer_install_ids) == "table"
    and policy.mer_install_ids[os.getComputerID()] == true
end

local function chooseRole()
  local requested = string.lower(tostring(args[1] or ""))

  if requested == "server" or requested == "mer" then
    if canInstallMer() then
      return "server"
    end

    colour(colors.red)
    print("ACCES REFUSE")
    colour(colors.white)
    print("L'installation du MER est reservee")
    print("a l'administration Astralium.")
    return nil
  end

  if requested == "client" or requested == "install" then
    return "client"
  end

  print("Installer LinkOS sur ce Computer ?")
  print()
  print("1 - Installer LinkOS")
  print("2 - Annuler")
  write("Choix: ")

  local choice = read()
  if choice == "1" then return "client" end
  return nil
end

local function isComputerLinkStartup(path)
  local content = readFile(path)
  return type(content) == "string"
    and content:find('/computer%-link/boot%.lua', 1, false) ~= nil
end

local function backupStartup()
  local startup = "/startup.lua"
  if not fs.exists(startup) or isComputerLinkStartup(startup) then return nil end

  local index = 1
  local backup = "/startup.computer-link-backup.lua"

  while fs.exists(backup) do
    index = index + 1
    backup = "/startup.computer-link-backup-" .. index .. ".lua"
  end

  fs.copy(startup, backup)
  return backup
end

local function loadInstallState()
  local path = ROOT .. "/install_state.db"
  local content = readFile(path)
  if not content then return {} end

  local ok, value = pcall(textutils.unserialize, content)
  if ok and type(value) == "table" then return value end
  return {}
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
if not role then return end

print()
if role == "server" then
  colour(colors.red)
  print("MODE ADMIN : REINSTALLATION MER")
  colour(colors.white)
else
  print("Installation LinkOS client")
end

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

if not fs.exists(ROOT) then fs.makeDir(ROOT) end

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

local previousState = loadInstallState()
local backup = backupStartup()

if not backup and previousState.startup_backup
  and fs.exists(previousState.startup_backup) then
  backup = previousState.startup_backup
end

local startupSource = [[-- Computer Link / LinkOS
shell.run("/computer-link/boot.lua")
]]

local success, startupError = writeFile("/startup.lua", startupSource)
if not success then
  colour(colors.red)
  print("Impossible d'installer startup.lua: " .. tostring(startupError))
  colour(colors.white)
  return
end

local installState = {
  role = role,
  startup_backup = backup,
  installed_at = os.epoch and math.floor(os.epoch("utc") / 1000) or os.time(),
  installer_version = manifest.version
}
writeFile(ROOT .. "/install_state.db", textutils.serialize(installState))

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
print("Place un Wireless Modem sur ce PC.")

if role == "client" then
  print("LinkOS cherchera automatiquement le MER.")
else
  print("Ce Computer conserve son role MER existant.")
end

print()
colour(colors.yellow)
print("Tape 'reboot' pour demarrer.")
colour(colors.white)
