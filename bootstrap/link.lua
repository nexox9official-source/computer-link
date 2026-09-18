local INSTALL_URL = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/install.lua"
local ROOT = "/computer-link"
local args = { ... }

local function colour(c)
  if term.isColor and term.isColor() then term.setTextColor(c) end
end

local function title()
  colour(colors.cyan)
  print("================================")
  print("        COMPUTER LINK")
  print("          LINK OS")
  print("================================")
  colour(colors.white)
  print("PC ID : #" .. os.getComputerID())
  print()
end

local function installed()
  return fs.exists(ROOT .. "/role.txt")
end

local function role()
  if not installed() then return nil end
  local f = fs.open(ROOT .. "/role.txt", "r")
  if not f then return nil end
  local value = f.readAll():gsub("%s+", "")
  f.close()
  return value
end

local function version()
  if not fs.exists(ROOT .. "/src/common/config.lua") then return nil end
  local ok, cfg = pcall(dofile, ROOT .. "/src/common/config.lua")
  if ok and type(cfg) == "table" then return cfg.VERSION end
  return nil
end

local function runInstaller()
  if not http or not http.get then
    colour(colors.red)
    print("HTTP est desactive sur ce serveur.")
    colour(colors.white)
    return false
  end

  print("Telechargement de LinkOS...")
  local response, err = http.get(INSTALL_URL)
  if not response then
    colour(colors.red)
    print("GitHub inaccessible: " .. tostring(err))
    colour(colors.white)
    return false
  end

  local source = response.readAll()
  response.close()

  local loader, loadErr = load(source, "@computer_link_install.lua", "t", _ENV)
  if not loader then
    colour(colors.red)
    print("Installateur invalide: " .. tostring(loadErr))
    colour(colors.white)
    return false
  end

  local ok, runErr = pcall(loader, "client")
  if not ok then
    colour(colors.red)
    print("Installation impossible: " .. tostring(runErr))
    colour(colors.white)
    return false
  end

  return true
end

local function status()
  title()

  if not installed() then
    colour(colors.yellow)
    print("Etat    : NON INSTALLE")
    colour(colors.white)
    print("Tape 'link install' pour installer LinkOS.")
    return
  end

  colour(colors.lime)
  print("Etat    : INSTALLE")
  colour(colors.white)
  print("Role    : " .. tostring(role() or "?"))
  print("Version : " .. tostring(version() or "?"))
  print()
  print("Mise a jour automatique active au demarrage.")
end

local command = string.lower(tostring(args[1] or ""))

if command == "" then
  title()

  if installed() then
    print("Computer Link est deja installe.")
    print("Role    : " .. tostring(role() or "?"))
    print("Version : " .. tostring(version() or "?"))
    print()
    print("1 - Demarrer LinkOS")
    print("2 - Mettre a jour")
    print("3 - Statut")
    print("4 - Quitter")
    write("Choix: ")

    local choice = read()

    if choice == "1" then
      shell.run(ROOT .. "/boot.lua")
    elseif choice == "2" then
      shell.run(ROOT .. "/update.lua")
    elseif choice == "3" then
      status()
    end
    return
  end

  print("Installer LinkOS sur ce Computer ?")
  print()
  print("1 - Installer LinkOS")
  print("2 - Quitter")
  write("Choix: ")

  local choice = read()
  if choice == "1" then
    command = "install"
  else
    return
  end
end

if command == "install" or command == "client" then
  title()
  runInstaller()

elseif command == "server" or command == "mer" then
  title()
  colour(colors.red)
  print("ACCES REFUSE")
  colour(colors.white)
  print("Le serveur MER est provisionne uniquement")
  print("par l'administration Astralium.")

elseif command == "update" then
  title()
  if not installed() then
    print("LinkOS n'est pas installe.")
    print("Utilise: link install")
  else
    shell.run(ROOT .. "/update.lua")
  end

elseif command == "start" then
  title()
  if installed() then
    shell.run(ROOT .. "/boot.lua")
  else
    print("LinkOS n'est pas installe.")
  end

elseif command == "uninstall" or command == "remove" then
  title()
  colour(colors.red)
  print("ACTION BLOQUEE")
  colour(colors.white)
  print("La maintenance systeme n'est pas disponible depuis un poste joueur.")

elseif command == "status" or command == "id" then
  status()

elseif command == "help" then
  title()
  print("link            menu")
  print("link install    installer LinkOS")
  print("link update     mise a jour manuelle")
  print("link start      demarrer LinkOS")
  print("link status     statut du PC")

else
  print("Commande inconnue. Utilise: link help")
end
