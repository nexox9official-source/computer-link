local draw = dofile("/computer-link/src/ui/draw.lua")

local shellui = {}

local APPS = {
  {id="home", title="Bureau", short="HOME", icon="[]", pinned=true},
  {id="messages", title="Messages", short="MSG", icon="<>", pinned=true},
  {id="contacts", title="Contacts", short="CONT", icon="@@", pinned=false},
  {id="network", title="Reseau", short="NET", icon="::", pinned=true},
  {id="security", title="Securite", short="SEC", icon="##", pinned=true},
  {id="files", title="Fichiers", short="FILES", icon="//", pinned=true},
  {id="notes", title="Notes", short="NOTE", icon="N", pinned=false},
  {id="calculator", title="Calculatrice", short="CALC", icon="+", pinned=false},
  {id="terminal", title="Terminal", short="TERM", icon=">_", pinned=false},
  {id="settings", title="Parametres", short="SET", icon="**", pinned=false},
  {id="about", title="A propos", short="INFO", icon="i", pinned=false},
  {id="hacker", title="LinkSec", short="LSEC", icon="X", pinned=true, operator=true}
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
  mode = tostring(mode or "grid")
  local bg = colors.black
  draw.fill(target, x, y, w, h, bg)

  if w <= 0 or h <= 0 then return end

  if mode == "grid" then
    local stepX = w >= 55 and 8 or 6
    local stepY = h >= 20 and 4 or 3
    for py = y, y + h - 1, stepY do
      for px = x, x + w - 1, stepX do
        draw.text(target, px, py, ".", accent or colors.cyan, bg, 1)
      end
    end
  elseif mode == "lines" then
    for py = y, y + h - 1, 3 do
      draw.hline(target, x, py, w, "-", colors.gray, bg)
    end
  elseif mode == "clean" then
    -- Deliberately empty.
  else
    for py = y, y + h - 1, 2 do
      local offset = ((py - y) % 4 == 0) and 0 or 2
      for px = x + offset, x + w - 1, 6 do
        draw.text(target, px, py, ".", colors.gray, bg, 1)
      end
    end
  end
end

function shellui.startMenuRect(layout)
  local w = math.min(math.max(24, math.floor(layout.w * 0.56)), 44)
  local h = math.min(math.max(10, math.floor(layout.h * 0.65)), math.max(8, layout.h - 3))
  local x = 1
  local y = math.max(3, layout.h - h)
  return x, y, w, h
end

function shellui.quickPanelRect(layout)
  local w = math.min(math.max(22, math.floor(layout.w * 0.42)), 36)
  local h = math.min(11, math.max(7, layout.h - 4))
  local x = math.max(1, layout.w - w + 1)
  local y = math.max(3, layout.h - h)
  return x, y, w, h
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
    local x, y, w = 2, 4, math.max(1,l.w-2)
    local bottom = l.mode == "compact" and l.h-2 or l.h-4
    shellui.wallpaper(target,1,3,l.w,math.max(0,bottom-2),prefs.get("wallpaper","grid"),t.accent)
    draw.text(target,x,y,"Votre espace de travail",t.text,t.bg,w)
    y=y+1
    draw.text(target,x,y,(self.service.online and "ASTRALNET CONNECTE" or "MODE HORS LIGNE")
      .. "  /  " .. tostring(self.service.unread or 0) .. " nouveau(x)",
      self.service.online and t.accent or t.warn,t.bg,w)
    y=y+2
    local apps={}
    for _,app in ipairs(shellui.apps(self:isOperatorUI())) do
      if app.id~="home" then apps[#apps+1]=app end
    end
    local tileH = bottom-y >= 8 and 3 or 1
    local p=shellui.page(apps,w,math.max(1,bottom-y),self.desktopPage,tileH)
    self.desktopPage,self.desktopPages=p.page,p.pages
    for index=p.first,math.min(#apps,p.first+p.capacity-1) do
      local app=apps[index]
      local n=index-p.first
      local bx=x+(n%p.cols)*(p.cellW+1)
      local by=y+math.floor(n/p.cols)*(tileH+1)
      if by+tileH-1<bottom then
        draw.fill(target,bx,by,p.cellW,tileH,t.panel)
        draw.fill(target,bx,by,1,tileH,badges[app.id] or t.accent)
        draw.text(target,bx+2,by,app.title,t.text,t.panel,p.cellW-2)
        if tileH>1 then
          draw.text(target,bx+2,by+2,descriptions[app.id],t.muted,t.panel,p.cellW-2)
        end
        self:addButton("desktop:"..app.id,bx,by,p.cellW,tileH,function() self:openApp(app.id) end)
      end
    end
    if bottom>=y then
      self:button(target,"desktop:prev",x,bottom,3,"<",function()
        self.desktopPage=math.max(1,p.page-1)
      end)
      draw.text(target,x+4,bottom,"Page "..p.page.."/"..p.pages,t.muted,t.bg,math.max(1,w-9))
      self:button(target,"desktop:next",math.max(x+4,l.w-4),bottom,3,">",function()
        self.desktopPage=math.min(p.pages,p.page+1)
      end)
    end
  end

  function OS:renderStartMenu(target,l)
    if not self.startMenuOpen then return end
    local t=self:theme()
    local w=math.min(l.w-2,48)
    local h=math.min(l.h-3,19)
    local x,y=2,math.max(1,l.h-h-1)
    self.shellOverlay={x=x,y=y,w=w,h=h}
    -- A modal menu must never click through into an underlying application.
    self.buttons={}
    draw.fill(target,x,y,w,h,t.panel)
    draw.fill(target,x,y,w,1,t.accent)
    draw.text(target,x+1,y,"APPLICATIONS",t.text,t.accent,math.max(1,w-5))
    self:button(target,"launcher:close",x+w-3,y,3,"X",function() self.startMenuOpen=false end)
    draw.text(target,x+1,y+2,"Chercher: "..(self.launcherQuery or ""),t.text,colors.black,w-2)
    local apps={}
    local query=(self.launcherQuery or ""):lower()
    for _,app in ipairs(shellui.apps(self:isOperatorUI())) do
      if app.title:lower():find(query,1,true) then apps[#apps+1]=app end
    end
    self.launcherApps=apps
    self.launcherIndex=math.max(1,math.min(#apps,self.launcherIndex or 1))
    local count=math.max(1,h-6)
    local page=math.floor((self.launcherIndex-1)/count)
    for i=page*count+1,math.min(#apps,(page+1)*count) do
      local app=apps[i]
      local by=y+3+i-page*count
      local selected=i==self.launcherIndex
      draw.fill(target,x+1,by,w-2,1,selected and t.accent or t.panel)
      draw.text(target,x+2,by,(selected and "> " or "  ")..app.title,t.text,
        selected and t.accent or t.panel,w-4)
      self:addButton("launcher:"..app.id,x+1,by,w-2,1,function() self:openApp(app.id) end)
    end
    if #apps==0 then draw.text(target,x+2,y+4,"Aucun resultat",t.muted,t.panel,w-4) end
    local fy=y+h-1
    self:button(target,"launcher:prev",x,fy,3,"<",function()
      self.launcherIndex=math.max(1,self.launcherIndex-count)
    end)
    draw.text(target,x+4,fy,"Recherche / "..#apps.." apps",t.muted,t.panel,w-8)
    self:button(target,"launcher:next",x+w-3,fy,3,">",function()
      self.launcherIndex=math.min(#apps,self.launcherIndex+count)
    end)
  end

  function OS:renderShellOverlays(target,l)
    self.shellOverlay=nil
    if self.quickPanelOpen then
      self.buttons={}
      local x,y,w,h=shellui.quickPanelRect(l)
      self.shellOverlay={x=x,y=y,w=w,h=h}
    end
    oldOverlays(self,target,l)
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
