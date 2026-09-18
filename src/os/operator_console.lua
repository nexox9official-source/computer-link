local security = dofile("/computer-link/src/client/security.lua")

local Console = {}
Console.__index = Console

local function split(line)
  local command, rest = tostring(line or ""):match("^%s*(%S+)%s*(.-)%s*$")
  return string.lower(command or ""), rest or ""
end

local function yieldNow()
  os.queueEvent("linksec_yield")
  os.pullEvent("linksec_yield")
end

local function colour(value)
  if term.isColor and term.isColor() then
    term.setTextColor(value)
  end
end

function Console.new(service)
  local self = setmetatable({}, Console)
  self.service = service
  self.target = nil
  self.lines = {
    {text="LINKSEC TERMINAL", colour=colors.red},
    {text="Operator privilege confirmed.", colour=colors.lime},
    {text="Tape 'help' ou 'hlp' pour les commandes.", colour=colors.lightGray}
  }
  self.maxLines = 220
  self.lastScan = {}
  self.openConversation = nil
  return self
end

function Console:push(text, lineColour)
  self.lines[#self.lines + 1] = {
    text = tostring(text or ""),
    colour = lineColour or colors.white
  }

  while #self.lines > self.maxLines do
    table.remove(self.lines, 1)
  end
end

function Console:prompt()
  local target = self.target and ("#" .. tostring(self.target)) or "-"
  return "root@pc" .. os.getComputerID() .. "[" .. target .. "]$"
end

function Console:help()
  self:push("COMMANDES LINKSEC", colors.red)
  self:push(" help | hlp                    aide + exemples")
  self:push(" scan                          ex: scan")
  self:push(" targets                       voir dernier scan")
  self:push(" hack <id>                     ex: hack 12")
  self:push(" use <id>                      ex: use 12")
  self:push(" sessions                      sessions ouvertes")
  self:push(" status                        etat operateur/cible")
  self:push(" info                          infos PC cible")
  self:push(" conv                          lister les conversations")
  self:push(" conv <id>                     ouvrir une conversation")
  self:push(" conv close                    fermer la conversation")
  self:push(" ls [chemin]                   ex: ls /")
  self:push(" cat <fichier>                 ex: cat /startup.lua")
  self:push(" write <f> <texte>             ex: write /note.txt owned")
  self:push(" delete <chemin>               ex: delete /note.txt")
  self:push(" auth                          voir protection mot de passe")
  self:push(" crackpass [auto|pin|short]    ex: crackpass auto")
  self:push(" lock [message]                ex: lock ACCESS DENIED")
  self:push(" message <texte>               ex: message Je vous vois.")
  self:push(" unlock                        debloquer LinkOS")
  self:push(" label <nom>                   ex: label COMPROMISED")
  self:push(" reboot                        redemarrer cible")
  self:push(" crash                         crash simule cible")
  self:push(" disconnect                    retirer cible locale")
  self:push(" clear                         vider l'ecran")
  self:push(" exit                          revenir a LinkOS")
end

function Console:requireTarget()
  if not self.target then
    self:push("Aucune cible active. Exemple: hack 12", colors.orange)
    return nil
  end
  return self.target
end

function Console:remote(action, argument)
  local target = self:requireTarget()
  if not target then return nil end

  local data, err = self.service:remote(target, action, argument)
  if not data then
    self:push("ERREUR: " .. tostring(err), colors.red)
    return nil
  end

  return data
end

local function lowerAlphaCandidate(index, length)
  local chars = {}
  for i = length, 1, -1 do
    local digit = index % 26
    chars[i] = string.char(string.byte("a") + digit)
    index = math.floor(index / 26)
  end
  return table.concat(chars)
end

function Console:crackPassword(mode)
  local auth = self:remote("authinfo")
  if not auth then return end

  if not auth.enabled then
    self:push("La cible n'a aucun mot de passe LinkOS.", colors.orange)
    return
  end

  if not auth.salt or not auth.password_hash then
    self:push("Hash de mot de passe indisponible.", colors.red)
    return
  end

  mode = string.lower(mode or "")
  if mode == "" then mode = "auto" end

  if mode ~= "auto" and mode ~= "pin" and mode ~= "short" then
    self:push("Usage: crackpass [auto|pin|short]", colors.orange)
    return
  end

  self:push("PASSWORD HASH ACQUIRED", colors.red)
  self:push("Mode: " .. mode .. " | lancement du brute-force...", colors.orange)

  local attempts = 0
  local found = nil

  local function test(candidate)
    attempts = attempts + 1
    if security.hashPassword(candidate, auth.salt) == tostring(auth.password_hash) then
      found = candidate
      return true
    end

    if attempts % 5000 == 0 then
      self:push("... " .. attempts .. " essais", colors.lightGray)
      yieldNow()
    end

    return false
  end

  local common = {
    "1234", "0000", "1111", "123456", "password", "admin",
    "astralium", "minecraft", "coalition", "linkos", "qwerty"
  }

  if mode == "auto" then
    for _, candidate in ipairs(common) do
      if test(candidate) then break end
    end
  end

  if not found and (mode == "auto" or mode == "pin") then
    for i = 0, 9999 do
      local candidate = string.format("%04d", i)
      if test(candidate) then break end
    end
  end

  if not found and (mode == "auto" or mode == "short") then
    for length = 1, 4 do
      local count = 26 ^ length
      for i = 0, count - 1 do
        local candidate = lowerAlphaCandidate(i, length)
        if test(candidate) then break end
      end
      if found then break end
    end
  end

  if found then
    self:push("PASSWORD CRACKED", colors.lime)
    self:push("Mot de passe: " .. found, colors.lime)
    self:push("Essais: " .. attempts, colors.lightGray)
  else
    self:push("ECHEC: mot de passe hors de l'espace teste.", colors.red)
    self:push("Essais: " .. attempts, colors.lightGray)
    self:push("Essaie pin ou short selon le type suppose.", colors.orange)
  end
end

function Console:execute(line)
  line = tostring(line or "")
  if line:match("^%s*$") then return nil end

  local command, rest = split(line)

  if command == "exit" or command == "quit" then
    self:push(self:prompt() .. " " .. line, colors.lime)
    self:push("Retour a LinkOS.", colors.lightGray)
    return "exit"
  end

  self:push(self:prompt() .. " " .. line, colors.lime)

  if command == "help" or command == "hlp" or command == "?" then
    self:help()

  elseif command == "clear" or command == "cls" then
    self.lines = {}

  elseif command == "status" then
    self:push("Operator PC #" .. os.getComputerID(), colors.red)
    self:push("MER: " .. (self.service.online and "ONLINE" or "OFFLINE"),
      self.service.online and colors.lime or colors.red)
    self:push("Target: " .. (self.target and ("#" .. self.target) or "none"))
    self:push("Sessions: " .. tostring(#self.service:sessions()))

  elseif command == "scan" then
    self:push("Scanning radio range...", colors.orange)
    local found, err = self.service:scan()

    if not found then
      self:push("SCAN FAILED: " .. tostring(err), colors.red)
    else
      self.lastScan = found
      self:push("Found " .. tostring(#found) .. " target(s).", colors.lime)

      for _, pc in ipairs(found) do
        self:push("#" .. tostring(pc.id)
          .. "  " .. tostring(math.floor((pc.distance or 0) * 10) / 10) .. " blocks"
          .. "  SEC:" .. tostring(pc.security or "?")
          .. "  " .. tostring(pc.label or "-"))
      end
    end

  elseif command == "targets" then
    if #self.lastScan == 0 then
      self:push("Aucun resultat. Exemple: scan")
    else
      for _, pc in ipairs(self.lastScan) do
        self:push("#" .. tostring(pc.id) .. "  " .. tostring(pc.label or "-"))
      end
    end

  elseif command == "hack" then
    local id = tonumber(rest)
    if not id then
      self:push("Usage: hack <id> | Exemple: hack 12", colors.orange)
    else
      self:push("Launching exploit against #" .. id .. "...", colors.orange)
      local session, err = self.service:hack(id)

      if not session then
        self:push("ACCESS DENIED: " .. tostring(err), colors.red)
      else
        self.target = id
        self:push("ACCESS GRANTED -> PC #" .. id, colors.lime)
        self:push("Cible active. Exemple: info", colors.lightGray)
      end
    end

  elseif command == "use" or command == "target" then
    local id = tonumber(rest)
    if not id then
      self:push("Usage: use <id> | Exemple: use 12", colors.orange)
    else
      local found = false
      for _, session in ipairs(self.service:sessions()) do
        if session.id == id then found = true break end
      end

      if found then
        self.target = id
        self:push("Target selected: #" .. id, colors.lime)
      else
        self:push("No active session for #" .. id, colors.red)
      end
    end

  elseif command == "sessions" then
    local sessions = self.service:sessions()
    if #sessions == 0 then
      self:push("No active sessions.")
    else
      for _, session in ipairs(sessions) do
        self:push("#" .. session.id .. "  session active")
      end
    end

  elseif command == "disconnect" then
    self.target = nil
    self:push("Local target released.")

  elseif command == "info" then
    local data = self:remote("info")
    if data then
      self:push("PC #" .. tostring(data.computer_id))
      self:push("Label: " .. tostring(data.label or "-"))
      self:push("Messages: " .. tostring(data.messages or 0))
      self:push("Free: " .. tostring(data.free_space or "?"))
      self:push("Locked: " .. tostring(data.locked == true))
    end

  elseif command == "conversations" or command == "conv" then
    local arg = string.lower(rest or "")

    if arg == "" or arg == "list" then
      local data = self:remote("conversation_index")
      if data then
        self.lines = {}
        self:push("CONVERSATIONS DISPONIBLES", colors.red)

        for _, item in ipairs(data.conversations or {}) do
          local preview = tostring((item.last or {}).body or "")
          if #preview > 34 then preview = string.sub(preview, 1, 31) .. "..." end

          self:push("#" .. tostring(item.peer_id)
            .. "  " .. tostring(item.count or 0) .. " msg"
            .. (preview ~= "" and ("  |  " .. preview) or ""))
        end

        if #(data.conversations or {}) == 0 then
          self:push("(aucune conversation)", colors.lightGray)
        else
          self:push("", colors.white)
          self:push("Ouvre avec: conv <id>", colors.lightGray)
        end
      end

    elseif arg == "close" or arg == "back" then
      self.openConversation = nil
      self.lines = {}
      self:push("Conversation fermee.", colors.lightGray)
      self:push("Tape 'conv' pour revoir la liste.", colors.lightGray)

    else
      local peerId = tonumber(rest)
      if not peerId then
        self:push("Usage: conv | conv <id> | conv close", colors.orange)
      else
        local data = self:remote("conversation", peerId)
        if data then
          self.openConversation = peerId
          self.lines = {}
          self:push("CONVERSATION AVEC PC #" .. tostring(peerId), colors.red)
          self:push(string.rep("-", 26), colors.gray)

          for _, message in ipairs(data.messages or {}) do
            local fromId = tonumber(message.from_id)
            local prefix = fromId == tonumber(self.target)
              and "CIBLE"
              or ("PC #" .. tostring(fromId))

            self:push(prefix .. " : " .. tostring(message.body))
          end

          if #(data.messages or {}) == 0 then
            self:push("(conversation vide)", colors.lightGray)
          end

          self:push("", colors.white)
          self:push("conv close = fermer | conv = liste", colors.lightGray)
        end
      end
    end

  elseif command == "ls" then
    local path = rest ~= "" and rest or "/"
    local data = self:remote("ls", path)

    if data then
      self:push("--- " .. tostring(data.path or path) .. " ---", colors.red)
      for _, entry in ipairs(data.entries or {}) do
        self:push((entry.dir and "[DIR] " or "      ") .. tostring(entry.name))
      end
    end

  elseif command == "cat" then
    if rest == "" then
      self:push("Usage: cat <fichier> | Exemple: cat /startup.lua", colors.orange)
    else
      local data = self:remote("cat", rest)

      if data then
        self:push("--- " .. tostring(data.path or rest) .. " ---", colors.red)
        for textLine in (tostring(data.content or "") .. "\n"):gmatch("(.-)\n") do
          self:push(textLine)
        end
      end
    end

  elseif command == "write" then
    local path, content = rest:match("^(%S+)%s+(.+)$")

    if not path then
      self:push("Usage: write <fichier> <texte>", colors.orange)
      self:push("Exemple: write /note.txt owned", colors.lightGray)
    else
      local data = self:remote("write", {path=path, content=content})
      if data then
        self:push("WROTE " .. tostring(data.bytes or 0)
          .. " bytes -> " .. tostring(data.path), colors.lime)
      end
    end

  elseif command == "delete" or command == "del" then
    if rest == "" then
      self:push("Usage: delete <chemin>", colors.orange)
    else
      local data = self:remote("delete", rest)
      if data then self:push("DELETED " .. tostring(data.path), colors.lime) end
    end

  elseif command == "auth" then
    local data = self:remote("authinfo")
    if data then
      self:push("Password protection: " .. (data.enabled and "ENABLED" or "DISABLED"),
        data.enabled and colors.orange or colors.lightGray)
      if data.enabled then
        self:push("Auto-lock: " .. tostring(data.auto_lock_seconds or "?") .. "s")
        self:push("Hash captured. Exemple: crackpass auto", colors.red)
      end
    end

  elseif command == "crackpass" or command == "crack" then
    self:crackPassword(rest)

  elseif command == "lock" then
    local data = self:remote("lock", rest)
    if data then self:push("TARGET LOCKED", colors.red) end

  elseif command == "message" or command == "wall" then
    if rest == "" then
      self:push("Usage: message <texte>", colors.orange)
    else
      local data = self:remote("message", rest)
      if data then self:push("REMOTE MESSAGE DISPLAYED", colors.lime) end
    end

  elseif command == "unlock" then
    local data = self:remote("unlock")
    if data then self:push("TARGET UNLOCKED", colors.lime) end

  elseif command == "label" then
    if rest == "" then
      self:push("Usage: label <nom>", colors.orange)
    else
      local data = self:remote("label", rest)
      if data then self:push("LABEL -> " .. tostring(data.label), colors.lime) end
    end

  elseif command == "reboot" then
    local data = self:remote("reboot")
    if data then self:push("REBOOT SENT", colors.orange) end

  elseif command == "crash" then
    local data = self:remote("crash")
    if data then self:push("CRASH SENT", colors.red) end

  else
    self:push("Unknown command: " .. command, colors.red)
    self:push("Tape 'help' ou 'hlp'.", colors.lightGray)
  end

  return nil
end

function Console:runInteractive(target)
  target = target or term.current()
  local previous = term.current()
  term.redirect(target)

  local function render()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)

    colour(colors.red)
    term.write("LINKSEC CMD")
    colour(colors.lightGray)
    term.setCursorPos(math.max(1, w - 10), 1)
    term.write("PC #" .. os.getComputerID())

    colour(colors.gray)
    term.setCursorPos(1, 2)
    term.write(string.rep("-", w))

    local visible = math.max(1, h - 4)
    local first = math.max(1, #self.lines - visible + 1)
    local y = 3

    for i = first, #self.lines do
      local entry = self.lines[i]
      term.setCursorPos(1, y)
      colour(entry.colour or colors.white)
      local text = tostring(entry.text or "")
      if #text > w then text = string.sub(text, 1, w) end
      term.write(text)
      y = y + 1
      if y > h - 1 then break end
    end

    term.setCursorPos(1, h)
    colour(colors.lime)
    term.write(self:prompt() .. " ")
    colour(colors.white)
  end

  while true do
    render()
    local line = read()
    local result = self:execute(line)
    if result == "exit" then break end
  end

  term.redirect(previous)
end

return Console
