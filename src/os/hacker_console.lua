local Console = {}
Console.__index = Console

local function split(line)
  local command, rest = tostring(line or ""):match("^%s*(%S+)%s*(.-)%s*$")
  return string.lower(command or ""), rest or ""
end

local function asLines(value)
  if type(value) == "table" then return value end
  return { tostring(value or "") }
end

function Console.new(service)
  local self = setmetatable({}, Console)
  self.service = service
  self.target = nil
  self.lines = {
    {text="LINKSEC TERMINAL", colour=colors.red},
    {text="Operator privilege confirmed.", colour=colors.lime},
    {text="Type 'help' for commands.", colour=colors.lightGray}
  }
  self.maxLines = 160
  return self
end

function Console:push(text, colour)
  self.lines[#self.lines + 1] = {
    text = tostring(text or ""),
    colour = colour or colors.white
  }
  while #self.lines > self.maxLines do
    table.remove(self.lines, 1)
  end
end

function Console:pushMany(lines, colour)
  for _, line in ipairs(asLines(lines)) do
    self:push(line, colour)
  end
end

function Console:prompt()
  local target = self.target and ("#" .. tostring(self.target)) or "-"
  return "root@pc" .. os.getComputerID() .. "[" .. target .. "]$"
end

function Console:help()
  self:push("COMMANDES LINKSEC", colors.red)
  self:push(" help                aide")
  self:push(" clear               nettoyer le terminal")
  self:push(" status              etat de l'operateur")
  self:push(" scan                scanner les PC proches")
  self:push(" targets             derniers PC detectes")
  self:push(" hack <id>           compromettre un PC")
  self:push(" use <id>            selectionner une cible compromise")
  self:push(" sessions            sessions actives")
  self:push(" info                 infos cible")
  self:push(" conversations        lire ses conversations")
  self:push(" ls [chemin]          lister ses fichiers")
  self:push(" cat <fichier>        lire un fichier")
  self:push(" write <f> <texte>    ecrire un fichier")
  self:push(" delete <chemin>      supprimer un chemin")
  self:push(" lock [message]       bloquer LinkOS")
  self:push(" message <texte>      message plein ecran")
  self:push(" unlock               debloquer LinkOS")
  self:push(" label <nom>          renommer le PC cible")
  self:push(" reboot               redemarrer la cible")
  self:push(" crash                crash simule cible")
  self:push(" disconnect           fermer cible locale")
end

function Console:requireTarget()
  if not self.target then
    self:push("Aucune cible active. Utilise: use <id>", colors.orange)
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

function Console:execute(line)
  line = tostring(line or "")
  if line:match("^%s*$") then return end

  self:push(self:prompt() .. " " .. line, colors.lime)

  local command, rest = split(line)

  if command == "help" or command == "?" then
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
    local found = self.lastScan or {}
    if #found == 0 then
      self:push("No scan results.")
    else
      for _, pc in ipairs(found) do
        self:push("#" .. tostring(pc.id) .. "  " .. tostring(pc.label or "-"))
      end
    end

  elseif command == "hack" then
    local id = tonumber(rest)
    if not id then
      self:push("Usage: hack <id>", colors.orange)
    else
      self:push("Launching exploit against #" .. id .. "...", colors.orange)
      local session, err = self.service:hack(id)
      if not session then
        self:push("ACCESS DENIED: " .. tostring(err), colors.red)
      else
        self.target = id
        self:push("ACCESS GRANTED -> PC #" .. id, colors.lime)
      end
    end

  elseif command == "use" or command == "target" then
    local id = tonumber(rest)
    if not id then
      self:push("Usage: use <id>", colors.orange)
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
    local data = self:remote("conversations")
    if data then
      local messages = data.messages or {}
      self:push("--- MESSAGE LOG ---", colors.red)
      for _, m in ipairs(messages) do
        self:push("#" .. tostring(m.from_id)
          .. " -> #" .. tostring(m.to_id)
          .. " : " .. tostring(m.body))
      end
      if #messages == 0 then self:push("(empty)") end
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
      self:push("Usage: cat <fichier>", colors.orange)
    else
      local data = self:remote("cat", rest)
      if data then
        self:push("--- " .. tostring(data.path or rest) .. " ---", colors.red)
        for lineText in (tostring(data.content or "") .. "\n"):gmatch("(.-)\n") do
          self:push(lineText)
        end
      end
    end

  elseif command == "write" then
    local path, content = rest:match("^(%S+)%s+(.+)$")
    if not path then
      self:push("Usage: write <fichier> <texte>", colors.orange)
    else
      local data = self:remote("write", {path=path, content=content})
      if data then
        self:push("WROTE " .. tostring(data.bytes or 0) .. " bytes -> " .. tostring(data.path), colors.lime)
      end
    end

  elseif command == "delete" or command == "del" then
    if rest == "" then
      self:push("Usage: delete <chemin>", colors.orange)
    else
      local data = self:remote("delete", rest)
      if data then self:push("DELETED " .. tostring(data.path), colors.lime) end
    end

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
    self:push("Type 'help' for available commands.", colors.lightGray)
  end
end

return Console
