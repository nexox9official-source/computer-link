local ROOT = "/computer-link"
local STATE_FILE = ROOT .. "/install_state.db"
local STARTUP = "/startup.lua"

local args = { ... }

local function colour(c)
  if term.isColor and term.isColor() then term.setTextColor(c) end
end

local function header()
  term.clear()
  term.setCursorPos(1, 1)
  colour(colors.red)
  print("================================")
  print("        COMPUTER LINK")
  print("        DESINSTALLATION")
  print("================================")
  colour(colors.white)
  print("PC ID : #" .. os.getComputerID())
  print()
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r")
  if not f then return nil end
  local content = f.readAll()
  f.close()
  return content
end

local function isComputerLinkStartup(path)
  local content = readFile(path)
  if not content then return false end
  return content:find('/computer%-link/boot%.lua', 1, false) ~= nil
end

local function loadState()
  if not fs.exists(STATE_FILE) then return nil end
  local content = readFile(STATE_FILE)
  if not content then return nil end
  local ok, state = pcall(textutils.unserialize, content)
  if ok and type(state) == "table" then return state end
  return nil
end

local function findFallbackBackup()
  local candidates = {}

  if fs.exists("/startup.computer-link-backup.lua") then
    candidates[#candidates + 1] = {
      path = "/startup.computer-link-backup.lua",
      index = 1
    }
  end

  local rootEntries = fs.list("/")
  for _, name in ipairs(rootEntries) do
    local n = name:match("^startup%.computer%-link%-backup%-(%d+)%.lua$")
    if n then
      candidates[#candidates + 1] = {
        path = "/" .. name,
        index = tonumber(n) or 0
      }
    end
  end

  table.sort(candidates, function(a, b)
    return a.index > b.index
  end)

  for _, candidate in ipairs(candidates) do
    -- Ignore backups which are merely another Computer Link startup stub.
    if not isComputerLinkStartup(candidate.path) then
      return candidate.path
    end
  end

  return nil
end

header()

if not fs.exists(ROOT) then
  colour(colors.yellow)
  print("Computer Link n'est pas installe sur ce PC.")
  colour(colors.white)
  return
end

local force = string.lower(tostring(args[1] or "")) == "yes"
  or string.lower(tostring(args[1] or "")) == "force"

if not force then
  print("Cette commande va supprimer Computer Link de ce PC.")
  print()
  print("Supprime :")
  print(" - application Computer Link")
  print(" - configuration locale")
  print(" - historique local des conversations")
  print(" - sessions et donnees locales")
  print()
  colour(colors.yellow)
  print("Le Computer ID ne change pas.")
  colour(colors.white)
  print()

  write("Confirmer la desinstallation ? [oui/non] : ")
  local answer = string.lower(read() or "")

  if answer ~= "oui" and answer ~= "o" and answer ~= "yes" and answer ~= "y" then
    print("Desinstallation annulee.")
    return
  end
end

local state = loadState()
local backup = state and state.startup_backup or nil

if backup and (not fs.exists(backup) or isComputerLinkStartup(backup)) then
  backup = nil
end

if not backup then
  backup = findFallbackBackup()
end

-- Retire notre startup actuel avant de supprimer l'application.
if fs.exists(STARTUP) and isComputerLinkStartup(STARTUP) then
  fs.delete(STARTUP)
end

if backup and fs.exists(backup) then
  fs.copy(backup, STARTUP)
  print("Ancien startup restaure depuis:")
  print(backup)
else
  print("Aucun ancien startup utilisateur a restaurer.")
end

-- Supprime les backups uniquement s'ils appartiennent au mécanisme Computer Link.
for _, name in ipairs(fs.list("/")) do
  if name == "startup.computer-link-backup.lua"
    or name:match("^startup%.computer%-link%-backup%-%d+%.lua$") then
    local path = "/" .. name
    if fs.exists(path) then fs.delete(path) end
  end
end

-- Le programme courant est déjà chargé en mémoire, donc ce dossier peut être retiré.
if fs.exists(ROOT) then
  fs.delete(ROOT)
end

print()
colour(colors.lime)
print("Computer Link a ete desinstalle.")
colour(colors.white)
print("Tape 'reboot' pour redemarrer CraftOS proprement.")
