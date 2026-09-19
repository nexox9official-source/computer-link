local ROOT = "/computer-link"
local ROLE_FILE = ROOT .. "/role.txt"
local CONFIG_FILE = ROOT .. "/src/common/config.lua"

local function sourceRef()
  local path = ROOT .. "/source_ref.txt"
  if not fs.exists(path) then return "main" end
  local f = fs.open(path, "r")
  if not f then return "main" end
  local value = tostring(f.readAll() or ""):gsub("%s+", "")
  f.close()
  if value == "" or value:find("..", 1, true)
    or not value:match("^[%w%._%-%/]+$") then
    return "main"
  end
  return value
end

local SOURCE_REF = sourceRef()
local MANIFEST_URL = "https://raw.githubusercontent.com/nexox9official-source/computer-link/"
  .. SOURCE_REF .. "/manifest.lua"

local function cleanupLegacyInternalNames()
  local legacy = {
    ROOT .. "/src/client/hack.lua",
    ROOT .. "/src/client/hacked_state.lua",
    ROOT .. "/src/os/hacker_console.lua"
  }

  for _, path in ipairs(legacy) do
    if fs.exists(path) then
      pcall(fs.delete, path)
    end
  end
end

local function cleanupClientFiles()
  for _, path in ipairs({
    ROOT .. "/src/server",
    ROOT .. "/src/client/cli.lua",
    ROOT .. "/uninstall.lua",
    ROOT .. "/src/client/hack.lua",
    ROOT .. "/src/client/hacked_state.lua",
    ROOT .. "/src/os/hacker_console.lua"
  }) do
    if fs.exists(path) then
      pcall(fs.delete, path)
    end
  end
end

local function setColour(colour)
  if term.isColor and term.isColor() then
    term.setTextColor(colour)
  end
end

local function applyFluentPalette()
  local path = ROOT .. "/src/ui/fluent.lua"
  if fs.exists(path) then
    local ok, ui = pcall(dofile, path)
    if ok and type(ui) == "table" and type(ui.applyPalette) == "function" then
      pcall(ui.applyPalette, term.current())
    end
  end
end

local function setBackground(colour)
  if term.isColor and term.isColor() and term.setBackgroundColor then
    term.setBackgroundColor(colour)
  end
end

local function center(row, text, foreground, background)
  local w = select(1, term.getSize())
  text = tostring(text or "")
  if background then setBackground(background) end
  if foreground then setColour(foreground) end
  term.setCursorPos(math.max(1, math.floor((w - #text) / 2) + 1), row)
  write(text:sub(1, w))
end

local function bootScreen(status, colour, detail)
  applyFluentPalette()
  local w, h = term.getSize()
  setBackground(colors.black)
  setColour(colors.white)
  term.clear()

  local mid = math.max(5, math.floor(h / 2))
  local logoX = math.max(2, math.floor(w / 2) - 3)

  -- Four tiles echo Windows without depending on external image assets.
  if term.isColor and term.isColor() then
    setBackground(colors.lightBlue)
    for dy=0,1 do
      term.setCursorPos(logoX, mid-4+dy)
      write("  ")
      term.setCursorPos(logoX+3, mid-4+dy)
      write("  ")
    end
    for dy=0,1 do
      term.setCursorPos(logoX, mid-1+dy)
      write("  ")
      term.setCursorPos(logoX+3, mid-1+dy)
      write("  ")
    end
  else
    center(mid-3, "[ ][ ]", colors.white, colors.black)
    center(mid-2, "[ ][ ]", colors.white, colors.black)
  end

  setBackground(colors.black)
  center(mid+2, "LinkOS", colors.white, colors.black)
  center(mid+4, status or "Demarrage", colour or colors.lightBlue, colors.black)
  if detail and h >= 12 then
    center(mid+5, detail, colors.lightGray, colors.black)
  end

  if h >= 6 then
    setBackground(colors.gray)
    term.setCursorPos(1,h)
    write(string.rep(" ",w))
    center(h, "Canal " .. SOURCE_REF, colors.lightGray, colors.gray)
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

  bootScreen("Verification des mises a jour", colors.cyan,
    "LinkOS " .. tostring(config.VERSION or "?"))

  local remote, err = fetchRemoteManifest()

  if not remote then
    bootScreen("Demarrage hors-ligne", colors.orange,
      tostring(err or "GitHub indisponible"))
    sleep(0.35)
    return
  end

  local localVersion = tostring(config.VERSION or "?")
  local remoteVersion = tostring(remote.version or "?")

  if localVersion == remoteVersion then
    bootScreen("Systeme a jour", colors.lime, "Version " .. localVersion)
    sleep(0.18)
    return
  end

  bootScreen("Mise a jour " .. localVersion .. " -> " .. remoteVersion,
    colors.yellow, "Installation automatique")

  local ok = shell.run(ROOT .. "/update.lua")
  if ok then
    bootScreen("Mise a jour terminee", colors.lime, "Demarrage de LinkOS")
  else
    bootScreen("Mise a jour impossible", colors.red,
      "Demarrage avec les fichiers disponibles")
  end
  sleep(0.35)
end
-- Chaque lancement verifie GitHub AVANT de demarrer MER ou le client.
autoUpdate()

-- Supprime les anciens noms de fichiers internes trop explicites.
cleanupLegacyInternalNames()

-- Recharge la configuration au cas ou l'auto-update vient de la remplacer.
local config = loadLocalConfig()

if config and fs.exists(config.CRASH_FLAG) then
  for remaining = config.CRASH_RECOVERY_SECONDS, 1, -1 do
    bootScreen("RECUPERATION SYSTEME", colors.red,
      "Redemarrage dans " .. remaining .. "s")
    sleep(1)
  end
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
  cleanupClientFiles()
  shell.run(ROOT .. "/src/client/client.lua")
else
  fail("role inconnu: " .. tostring(role))
end
