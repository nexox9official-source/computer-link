local ROOT = "/computer-link"
local ROLE_FILE = ROOT .. "/role.txt"
local CONFIG_FILE = ROOT .. "/src/common/config.lua"
local MANIFEST_URL = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/manifest.lua"

local function setColour(colour)
  if term.isColor and term.isColor() then
    term.setTextColor(colour)
  end
end

local function fail(message)
  setColour(colors.red)
  print("Computer Link: " .. message)
  setColour(colors.white)
end

local function loadLocalConfig()
  if not fs.exists(CONFIG_FILE) then
    return nil
  end

  local ok, config = pcall(dofile, CONFIG_FILE)
  if ok and type(config) == "table" then
    return config
  end

  return nil
end

local function fetchRemoteManifest()
  if not http or not http.get then
    return nil, "HTTP indisponible"
  end

  local response, err = http.get(MANIFEST_URL)
  if not response then
    return nil, err or "manifest inaccessible"
  end

  local source = response.readAll()
  response.close()

  local loader, loadErr = load(source, "@remote_manifest.lua", "t", {})
  if not loader then
    return nil, loadErr
  end

  local ok, manifest = pcall(loader)
  if not ok or type(manifest) ~= "table" then
    return nil, "manifest distant invalide"
  end

  return manifest
end

local function autoUpdate()
  local config = loadLocalConfig()
  if not config then return end

  term.clear()
  term.setCursorPos(1, 1)
  setColour(colors.cyan)
  print("================================")
  print("        COMPUTER LINK")
  print("        AUTO UPDATE")
  print("================================")
  setColour(colors.white)
  print("Verification des mises a jour...")

  local remote, err = fetchRemoteManifest()

  if not remote then
    setColour(colors.orange)
    print("GitHub indisponible: demarrage hors-ligne.")
    setColour(colors.white)
    sleep(0.5)
    return
  end

  local localVersion = tostring(config.VERSION or "?")
  local remoteVersion = tostring(remote.version or "?")

  print("Local  : " .. localVersion)
  print("Remote : " .. remoteVersion)

  if localVersion == remoteVersion then
    setColour(colors.lime)
    print("Computer Link est a jour.")
    setColour(colors.white)
    sleep(0.35)
    return
  end

  setColour(colors.yellow)
  print("Nouvelle version detectee.")
  print("Mise a jour automatique...")
  setColour(colors.white)

  local ok = shell.run(ROOT .. "/update.lua")

  if ok then
    setColour(colors.lime)
    print("Mise a jour terminee.")
    setColour(colors.white)
  else
    setColour(colors.red)
    print("La mise a jour a echoue. Demarrage avec les fichiers disponibles.")
    setColour(colors.white)
  end

  sleep(0.6)
end

-- Chaque lancement verifie GitHub AVANT de demarrer MER ou le client.
autoUpdate()

-- Recharge la configuration au cas ou l'auto-update vient de la remplacer.
local config = loadLocalConfig()

if config and fs.exists(config.CRASH_FLAG) then
  term.clear()
  term.setCursorPos(1, 1)
  setColour(colors.red)
  print("================================")
  print("       SYSTEM FAILURE")
  print("================================")
  setColour(colors.white)
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
