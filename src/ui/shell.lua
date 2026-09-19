local draw = dofile("/computer-link/src/ui/draw.lua")

local shellui = {}

local APPS = {
  {id="home", title="Bureau", short="HOME", icon="L", pinned=true},
  {id="messages", title="Messages", short="MSG", icon="M", pinned=true},
  {id="contacts", title="Contacts", short="CONT", icon="C", pinned=false},
  {id="network", title="Reseau", short="NET", icon="N", pinned=true},
  {id="security", title="Securite", short="SEC", icon="S", pinned=true},
  {id="files", title="Fichiers", short="FILES", icon="F", pinned=true},
  {id="notes", title="Notes", short="NOTE", icon="T", pinned=false},
  {id="calculator", title="Calculatrice", short="CALC", icon="=", pinned=false},
  {id="terminal", title="Terminal", short="TERM", icon=">", pinned=false},
  {id="settings", title="Parametres", short="SET", icon="*", pinned=false},
  {id="about", title="A propos", short="INFO", icon="i", pinned=false},
  {id="hacker", title="LinkSec", short="LSEC", icon="!", pinned=true, operator=true}
}

local function clone(value)
  local out = {}
  for k, v in pairs(value) do out[k] = v end
  return out
end

function shellui.apps(operator)
  local out = {}
  for _, app in ipairs(APPS) do
    if not app.operator or operator then
      out[#out + 1] = clone(app)
    end
  end
  return out
end

function shellui.find(id, operator)
  for _, app in ipairs(shellui.apps(operator)) do
    if app.id == id then return app end
  end
  return nil
end

function shellui.allowed(id, operator)
  return shellui.find(id, operator) ~= nil
end

function shellui.pinned(operator)
  local out = {}
  for _, app in ipairs(shellui.apps(operator)) do
    if app.pinned then out[#out + 1] = app end
  end
  return out
end

function shellui.nextApp(current, operator, delta)
  local apps = shellui.apps(operator)
  if #apps == 0 then return "home" end

  local index = 1
  for i, app in ipairs(apps) do
    if app.id == current then
      index = i
      break
    end
  end

  delta = tonumber(delta) or 1
  index = ((index - 1 + delta) % #apps) + 1
  return apps[index].id
end

function shellui.wallpaper(target, x, y, w, h, mode, accent)
  mode = tostring(mode or "dots")
  draw.fill(target, x, y, w, h, colors.black)
  if w <= 0 or h <= 0 or mode == "clean" then return end

  if mode == "lines" then
    for py = y + 1, y + h - 1, 4 do
      draw.hline(target, x, py, w, "-", colors.gray, colors.black)
    end
    return
  end

  local stepX = mode == "grid" and 10 or 14
  local stepY = mode == "grid" and 4 or 5
  for py = y + 1, y + h - 1, stepY do
    local offset = ((py - y) % (stepY * 2) == 0) and 2 or math.floor(stepX / 2)
    for px = x + offset, x + w - 1, stepX do
      draw.text(target, px, py, mode == "grid" and "." or "'", accent or colors.cyan, colors.black, 1)
    end
  end
end

function shellui.startMenuRect(layout)
  local w = math.min(math.max(28, math.floor(layout.w * 0.62)), math.max(24, layout.w - 2))
  local h = math.min(math.max(10, math.floor(layout.h * 0.70)), math.max(8, layout.h - 2))
  return 2, math.max(1, layout.h - h), w, h
end

function shellui.quickPanelRect(layout)
  local w = math.min(math.max(22, math.floor(layout.w * 0.42)), math.max(20, layout.w - 2))
  local h = math.min(10, math.max(7, layout.h - 3))
  return math.max(1, layout.w - w), math.max(1, layout.h - h), w, h
end

-- Responsive shell v0.13. Kept separate from the network/application backend.
function shellui.page(items, width, height, requested, tileHeight)
  local cols = math.max(1, math.min(4, math.floor((width + 1) / 16)))
  local rows = math.max(1, math.floor(height / (tileHeight + 1)))
  local capacity = cols * rows
  local pages = math.max(1, math.ceil(#items / capacity))
  local page = math.max(1, math.min(pages, requested or 1))
  return {cols=cols, capacity=capacity, pages=pages, page=page,
    first=(page-1)*capacity+1, cellW=math.floor((width-cols+1)/cols)}
end

function shellui.install(OS, prefs)
  local oldKey, oldHit = OS.handleKey, OS.hit
  local oldOverlays = OS.renderShellOverlays
  local oldChrome = OS.renderChrome
  local descriptions = {messages="Conversations privees", contacts="Votre carnet d'adresses",
    network="Connexion AstralNet", files="Documents personnels", security="Protection du poste",
    notes="Ecrire et sauvegarder", calculator="Calculs rapides", terminal="Console CraftOS",
    settings="Personnaliser LinkOS", about="Version et raccourcis", hacker="Acces operateur"}
  local badges = {messages=colors.cyan, contacts=colors.blue, network=colors.lime,
    files=colors.orange, security=colors.purple, notes=colors.yellow,
    calculator=colors.green, terminal=colors.gray, settings=colors.lightBlue,
    about=colors.blue, hacker=colors.red}

  function OS:renderChrome(target, l)
    oldChrome(self, target, l)
    -- Replace the crowded second row with a clean breadcrumb and clock.
    local t = self:theme()
    draw.fill(target, 1, 2, l.w, 1, colors.black)
    local app = shellui.find(self.app, self:isOperatorUI())
    draw.text(target, 2, 2, "Astralium / " .. (app and app.title or "Bureau"), t.muted, colors.black, math.max(1,l.w-10))
    draw.text(target, math.max(1,l.w-5), 2, textutils.formatTime(os.time(),true), t.accent, colors.black, 5)
    for i=#self.buttons,1,-1 do
      if self.buttons[i].id == "quick:update" then table.remove(self.buttons,i) end
    end
  end

  function OS:renderHome(target, l)
    local t = self:theme()
    local bottom = math.max(3, l.h - 1)
    shellui.wallpaper(target, 1, 1, l.w, bottom, prefs.get("wallpaper","dots"), t.accent)

    draw.text(target, 2, 2, "LINKOS", t.accent, colors.black, math.max(1,l.w-3))
    draw.text(target, 2, 3,
      self.service.online and "AstralNet connecte" or "Mode hors-ligne",
      self.service.online and t.good or t.warn, colors.black, math.max(1,l.w-3))

    local apps = {}
    for _, app in ipairs(shellui.apps(self:isOperatorUI())) do
      if app.id ~= "home" then apps[#apps+1] = app end
    end

    local p = shellui.page(apps, math.max(1,l.w-3), math.max(1,l.h-6), self.desktopPage, 2)
    self.desktopPage, self.desktopPages = p.page, p.pages
    local x, y = 2, 5

    for index=p.first,math.min(#apps,p.first+p.capacity-1) do
      local app=apps[index]
      local n=index-p.first
      local bx=x+(n%p.cols)*(p.cellW+1)
      local by=y+math.floor(n/p.cols)*3
      if by+1 < bottom then
        local badge=badges[app.id] or t.accent
        draw.fill(target,bx,by,p.cellW,2,colors.black)
        draw.fill(target,bx,by,2,2,badge)
        draw.text(target,bx,by,app.icon or "+",colors.white,badge,2)
        draw.text(target,bx+3,by,app.title,t.text,colors.black,math.max(1,p.cellW-3))
        draw.text(target,bx+3,by+1,descriptions[app.id] or "",t.muted,colors.black,math.max(1,p.cellW-3))
        self:addButton("desktop:"..app.id,bx,by,p.cellW,2,function() self:openApp(app.id) end)
      end
    end
  end

  function OS:renderStartMenu(target,l)
    if not self.startMenuOpen then return end
    local t=self:theme()
    local x,y,w,h=shellui.startMenuRect(l)
    self.shellOverlay={x=x,y=y,w=w,h=h}
    self.buttons={}

    draw.fill(target,x,y,w,h,colors.gray)
    draw.fill(target,x,y,w,1,t.accent)
    draw.text(target,x+2,y,"LINKOS",colors.white,t.accent,math.max(1,w-8))
    self:button(target,"launcher:close",x+w-3,y,3,"X",function() self.startMenuOpen=false end)

    local query=self.launcherQuery or ""
    draw.fill(target,x+2,y+2,w-4,1,colors.black)
    draw.text(target,x+3,y+2,(query=="" and "Rechercher une application..." or query),
      query=="" and t.muted or t.text,colors.black,math.max(1,w-6))

    local apps={}
    local q=query:lower()
    for _,app in ipairs(shellui.apps(self:isOperatorUI())) do
      if q=="" or app.title:lower():find(q,1,true) or app.id:lower():find(q,1,true) then
        apps[#apps+1]=app
      end
    end
    self.launcherApps=apps
    self.launcherIndex=math.max(1,math.min(math.max(1,#apps),self.launcherIndex or 1))

    draw.text(target,x+2,y+4,q=="" and "TOUTES LES APPS" or "RESULTATS",t.muted,colors.gray,w-4)
    local top=y+5
    local footer=y+h-2
    local count=math.max(1,footer-top)
    local page=math.floor((self.launcherIndex-1)/count)
    local first=page*count+1

    for i=first,math.min(#apps,first+count-1) do
      local app=apps[i]
      local by=top+(i-first)
      local selected=i==self.launcherIndex
      local bg=selected and colors.black or colors.gray
      local badge=badges[app.id] or t.accent
      draw.fill(target,x+2,by,w-4,1,bg)
      draw.text(target,x+2,by," "..(app.icon or "+").." ",colors.white,badge,3)
      draw.text(target,x+6,by,app.title,selected and colors.white or t.text,bg,math.max(1,w-11))
      if w>=38 then draw.text(target,x+w-10,by,app.short or "",t.muted,bg,7) end
      self:addButton("launcher:"..app.id,x+2,by,w-4,1,function() self:openApp(app.id) end)
    end

    if #apps==0 then draw.text(target,x+3,top+1,"Aucun resultat",t.muted,colors.gray,w-6) end

    draw.fill(target,x,footer,w,2,colors.black)
    draw.text(target,x+2,footer,"F10 fermer",t.muted,colors.black,12)
    self:button(target,"launcher:settings",x+w-21,footer,9,"SETTINGS",function() self:openApp("settings") end)
    self:button(target,"launcher:power",x+w-10,footer,8,"REBOOT",function()
      if self:confirm("Redemarrer ce PC ?") then os.reboot() end
    end)
  end

  function OS:renderQuickPanel(target,l)
    if not self.quickPanelOpen then return end
    local t=self:theme()
    local x,y,w,h=shellui.quickPanelRect(l)
    self.shellOverlay={x=x,y=y,w=w,h=h}
    self.buttons={}

    draw.fill(target,x,y,w,h,colors.gray)
    draw.fill(target,x,y,w,1,t.accent)
    draw.text(target,x+2,y,"SYSTEME",colors.white,t.accent,w-5)
    self:button(target,"quick:close",x+w-3,y,3,"X",function() self.quickPanelOpen=false end)

    local row=y+2
    local function line(label,value,colour)
      if row>=y+h-2 then return end
      draw.text(target,x+2,row,label,t.muted,colors.gray,math.max(1,w-4))
      local text=tostring(value or "-")
      draw.text(target,math.max(x+2,x+w-#text-2),row,text,colour or t.text,colors.gray,math.max(1,w-4))
      row=row+1
    end

    line("AstralNet",self.service.online and "ONLINE" or "OFFLINE",self.service.online and t.good or t.danger)
    line("Messages",tostring(self.service.unread or 0),(self.service.unread or 0)>0 and t.warn or t.text)
    line("Ecran",self.active and self.active.label or "-",t.text)
    line("Heure",textutils.formatTime(os.time(),true),t.accent)

    local by=y+h-2
    self:button(target,"quick:settings",x+2,by,10,"SETTINGS",function() self:openApp("settings") end)
    self:button(target,"quick:desktop",x+w-11,by,9,"BUREAU",function() self:openApp("home") end)
  end

  function OS:renderShellOverlays(target,l)
    self.shellOverlay=nil
    if self.startMenuOpen then
      self:renderStartMenu(target,l)
    elseif self.quickPanelOpen then
      self:renderQuickPanel(target,l)
    else
      oldOverlays(self,target,l)
    end
  end

  function OS:hit(x,y)
    local r=self.shellOverlay
    if r and (x<r.x or x>=r.x+r.w or y<r.y or y>=r.y+r.h) then
      self.startMenuOpen,self.quickPanelOpen=false,false
      return true
    end
    return oldHit(self,x,y)
  end

  function OS:handleKey(key)
    if self.startMenuOpen then
      if key==keys.down or key==keys.tab then
        self.launcherIndex=math.min(#(self.launcherApps or {}),(self.launcherIndex or 1)+1)
      elseif key==keys.up then self.launcherIndex=math.max(1,(self.launcherIndex or 1)-1)
      elseif key==keys.backspace then
        self.launcherQuery=(self.launcherQuery or ""):sub(1,-2); self.launcherIndex=1
      elseif key==keys.enter then
        local app=(self.launcherApps or {})[self.launcherIndex or 1]
        if app then self:openApp(app.id) end
      elseif key==keys.escape or key==keys.f10 then self.startMenuOpen=false end
      return
    end
    if self.app=="home" and (key==keys.left or key==keys.right) then
      self.desktopPage=math.max(1,math.min(self.desktopPages or 1,
        (self.desktopPage or 1)+(key==keys.right and 1 or -1)))
      return
    end
    return oldKey(self,key)
  end
end

return shellui
