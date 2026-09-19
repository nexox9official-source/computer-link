-- Run from repository root with texlua tests/shell_layout.lua (or lua).
colors={}
for i,name in ipairs({'white','orange','magenta','lightBlue','yellow','lime','pink',
  'gray','lightGray','cyan','purple','blue','brown','green','red','black'}) do colors[name]=2^(i-1) end
keys={up=1,down=2,left=3,right=4,tab=5,backspace=6,enter=7,escape=8,f10=9}
textutils={formatTime=function() return '12:30' end}
local originalDofile=dofile
dofile=function(path) return originalDofile((path:gsub('^/computer%-link/',''))) end
local shellui=dofile('src/ui/shell.lua')
local draw=dofile('src/ui/draw.lua')
local OS={handleKey=function() end,hit=function() return false end,
  renderShellOverlays=function() end,renderChrome=function() end}
shellui.install(OS,{get=function(_,fallback) return fallback end})
local checks=0
for _,size in ipairs({{26,12},{39,13},{51,19},{58,18},{82,26},{110,38}}) do
  local w,h=table.unpack(size)
  local cx,cy=1,1
  local target={getSize=function() return w,h end,
    setTextColor=function() end,setBackgroundColor=function() end,
    setCursorPos=function(x,y)
      assert(x>=1 and x<=w and y>=1 and y<=h,'Out of bounds cursor')
      cx,cy=x,y
    end,
    write=function(s) assert(cx+#s-1<=w,'Overflow write') end}
  draw.fill(target,-3,-5,w+20,h+20,colors.black)
  draw.text(target,-4,1,'clipped',colors.white)
  for _,operator in ipairs({false,true}) do
    local o=setmetatable({buttons={},service={online=true,unread=2},app='home'}, {__index=OS})
    function o:theme() return {text=colors.white,bg=colors.black,panel=colors.gray,
      muted=colors.lightGray,accent=colors.cyan,warn=colors.orange} end
    function o:isOperatorUI() return operator end
    function o:addButton(id,x,y,bw,bh,callback)
      assert(x>=1 and y>=1 and x+bw-1<=w and y+bh-1<=h,id..' outside screen')
      self.buttons[#self.buttons+1]={id=id,callback=callback}
    end
    function o:button(t,id,x,y,bw,label,callback)
      draw.button(t,x,y,bw,label,colors.white,colors.gray)
      self:addButton(id,x,y,bw,1,callback)
    end
    function o:openApp(id) self.app=id end
    function o:render() end
    local l={w=w,h=h,mode=h<15 and 'compact' or 'standard'}
    local seen={}
    o:renderHome(target,l)
    for page=1,o.desktopPages do
      o.desktopPage=page; o.buttons={}; o:renderHome(target,l)
      for _,b in ipairs(o.buttons) do seen[b.id]=true end
    end
    for _,app in ipairs(shellui.apps(operator)) do
      assert(app.id=='home' or seen['desktop:'..app.id],'Unreachable desktop '..app.id)
    end
    o.startMenuOpen=true; seen={}
    for index=1,#shellui.apps(operator) do
      o.launcherIndex=index; o:renderStartMenu(target,l)
      for _,b in ipairs(o.buttons) do seen[b.id]=true end
    end
    -- Default Start intentionally shows only a small pinned set.
    assert(seen['launcher:all'],'All Apps entry missing from simplified Start')

    -- Opening All Apps must make every allowed app reachable.
    for _,button in ipairs(o.buttons) do
      if button.id=='launcher:all' then button.callback();break end
    end
    o.buttons={}
    o:renderStartMenu(target,l)
    local allSeen={}
    for _,button in ipairs(o.buttons) do allSeen[button.id]=true end
    local pages=math.max(1,math.ceil(#(o.launcherApps or {})/math.max(1,(o.launcherCols or 1)*3)))
    local guard=0
    while guard<pages+2 do
      for _,button in ipairs(o.buttons) do allSeen[button.id]=true end
      local nextButton=nil
      for _,button in ipairs(o.buttons) do
        if button.id=='launcher:next' then nextButton=button break end
      end
      if not nextButton then break end
      local before=o.launcherIndex
      nextButton.callback()
      if o.launcherIndex==before then break end
      o.buttons={}
      o:renderStartMenu(target,l)
      guard=guard+1
    end
    for _,app in ipairs(shellui.apps(operator)) do
      assert(app.id=='home' or allSeen['launcher:'..app.id],'Unreachable All Apps entry '..app.id)
    end

    o.launcherQuery='calcul'; o.startAllApps=false; o:renderStartMenu(target,l)
    assert(#o.launcherApps==1 and o.launcherApps[1].id=='calculator')
    o:handleKey(keys.enter); assert(o.app=='calculator')
    o.startMenuOpen=true; o.launcherQuery='no-match'; o:renderStartMenu(target,l)
    assert(#o.launcherApps==0)
    o:handleKey(keys.enter)
    assert(o:hit(1,1)==true and not o.startMenuOpen)
    checks=checks+1
  end
end
print('PASS: '..checks..' resolution/permission cases; pagination, search, keyboard, modal and clipping')
