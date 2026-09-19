-- Offline integration harness: actual LinkOS class + a CC terminal/filesystem model.
colors={}
for i,name in ipairs({'white','orange','magenta','lightBlue','yellow','lime','pink','gray',
  'lightGray','cyan','purple','blue','brown','green','red','black'}) do colors[name]=2^(i-1) end
keys={}
for i,name in ipairs({'up','down','left','right','tab','backspace','enter','escape','pageUp','pageDown',
  'f1','f2','f3','f4','f5','f6','f7','f8','f9','f10','f11','f12','m','s','w','leftCtrl','rightCtrl'}) do keys[name]=i end
local disk={}
fs={exists=function(p) return disk[p]~=nil end,makeDir=function(p) disk[p]=true end,
  isDir=function(p) return disk[p]==true end,getDir=function(p) return p:match('^(.*)/') or '' end,
  getFreeSpace=function() return 1000000 end,list=function() return {} end,
  getSize=function(p) return #(disk[p] or '') end,
  getName=function(p) return p:match('([^/]+)$') or '' end,
  combine=function(a,b) return a..'/'..b end,
  move=function(a,b) assert(disk[a]~=nil and disk[b]==nil);disk[b]=disk[a];disk[a]=nil end,
  delete=function(p) disk[p]=nil end}
function fs.open(p,mode)
  if mode=='w' then disk[p]='' end
  if type(disk[p])~='string' then return nil end
  return {write=function(s) disk[p]=disk[p]..s end,close=function() end,
    readAll=function() return disk[p] end,read=function(n) return disk[p]:sub(1,n) end}
end
local function serialize(v)
  if type(v)=='string' then return string.format('%q',v) end
  if type(v)~='table' then return tostring(v) end
  local s='{';for k,val in pairs(v) do s=s..'['..serialize(k)..']='..serialize(val)..',' end
  return s..'}'
end
textutils={formatTime=function() return '12:30' end,serialize=serialize,
  unserialize=function(s) local f=load('return '..s,'db','t',{});return f and f() end}
os.getComputerID=function() return 42 end
os.getComputerLabel=function() return 'TEST COMPUTER' end
os.queueEvent=function() end
local queue={}
os.pullEventRaw=function() assert(#queue>0,'Unexpected blocking event read');return table.unpack(table.remove(queue,1)) end
peripheral={getNames=function() return {} end,getType=function() return nil end}
local function hex(c) return string.format('%x',math.floor(math.log(c)/math.log(2)+0.5)) end
local function terminal(w,h)
  local rows={};local x,y=1,1;local fg,bg='0','f'
  local t={getSize=function() return w,h end,isColor=function() return true end,
    setCursorBlink=function() end,getCursorBlink=function() return false end,
    setCursorPos=function(a,b) x,y=a,b end,getCursorPos=function() return x,y end,
    setTextColor=function(c) fg=hex(c) end,setBackgroundColor=function(c) bg=hex(c) end,
    getTextColor=function() return 2^tonumber(fg,16) end,getBackgroundColor=function() return 2^tonumber(bg,16) end}
  function t.clear() for j=1,h do rows[j]={string.rep(' ',w),string.rep(fg,w),string.rep(bg,w)} end end
  function t.blit(text,f,b)
    assert(y>=1 and y<=h and x>=1 and x+#text-1<=w,'Out of bounds blit')
    assert(#text==#f and #text==#b)
    local r=rows[y]
    for i,s in ipairs({text,f,b}) do r[i]=r[i]:sub(1,x-1)..s..r[i]:sub(x+#s) end
    x=x+#text
  end
  function t.write(s) t.blit(s,string.rep(fg,#s),string.rep(bg,#s)) end
  function t.getLine(j) return table.unpack(assert(rows[j])) end
  function t.dump(path)
    local f=assert(io.open(path,'w'))
    for j=1,h do f:write(rows[j][1],'\n',rows[j][2],'\n',rows[j][3],'\n') end
    f:close()
  end
  t.clear();return t
end
window={create=function(_,_,_,w,h) return terminal(w,h) end}
local native=terminal(51,19)
term={current=function() return native end,native=function() return native end}
local originalDofile=dofile
dofile=function(path)
  if disk[path] and type(disk[path])=='string' then return assert(load(disk[path],path,'t',_ENV))() end
  return originalDofile((path:gsub('^/computer%-link/','')))
end
local f=assert(io.open('src/os/linkos.lua'));local source=f:read('*a');f:close()
source=assert(source:gsub('local instance = LinkOS.new%(%)%s*instance:run%(%)%s*$','return LinkOS'))
local OS=assert(load(source,'@linkos.lua','t',_ENV))()
local total=0
for _,size in ipairs({{26,12},{39,13},{51,19},{82,26}}) do
  native=terminal(size[1],size[2])
  local o=OS.new()
  o:refreshDisplays();o:render()
  local firstIcon=o:desktopApps()[1].id
  o:moveIcon(1,3);assert(o:desktopApps()[3].id==firstIcon)
  o:openApp('store');assert(#o.windows==1)
  local store=o.windows[1]
  o:openApp('notes');assert(#o.windows==2)
  local notes=o.windows[2]
  o.noteDocument.editing=true
  o:workspaceEvent('char','A');o:workspaceEvent('key',keys.enter);o:workspaceEvent('char','B')
  assert(table.concat(o.noteDocument.lines,'\n')=='A\nB')
  o:saveNote();assert(not o.noteDocument.dirty)
  assert(disk['/user/notes.txt']=='A\nB')
  o:workspaceEvent('key',keys.escape)
  o:openApp('store');assert(#o.windows==2 and o.windows[2]==store)
  o.windowDrag={win=store,dx=1,dy=0}
  o:workspaceEvent('mouse_drag',1,100,100)
  assert(store.x+store.w-1<=size[1] and store.y+store.h-1<=size[2]-1)
  o:workspaceEvent('mouse_up',1,100,100)
  if size[1]>=51 then
    store.maximized=false
    store.x,store.y,store.w,store.h=5,3,30,10
    o.windowDrag={win=store,dx=0,dy=0,original={5,3,30,10}}
    o:workspaceEvent('mouse_drag',1,1,5)
    o:workspaceEvent('mouse_up',1,1,5)
    assert(store.snapped=='left' and store.x==1 and store.y==1)
    assert(store.h==size[2]-1)
  end
  store.maximized=true;o:render();assert(store.w==size[1])
  o:openApp('home');assert(store.minimized and notes.minimized)
  o:handleKey(keys.f12);assert(o.app~='home')
  queue={{'char','O'},{'char','K'},{'key',keys.enter}}
  assert(o:prompt('Test','Integrated dialog')=='OK' and not o.dialogOpen)
  for _,app in ipairs({'network','messages','contacts','files','security','settings','calculator','terminal','about'}) do
    o:openApp(app)
    -- All actual built-in renderers run in the mock terminal.
    local win=o.windows[#o.windows]
    assert(not win.renderError,app..': '..tostring(win.renderError))
    o:closeWindow(win)
  end
  if size[1]==51 then
    o.notice=nil;o.noticeExpires=nil
    o:openApp('home');o:render();native.dump('/tmp/linkos-desktop.frame')

    o.startMenuOpen=true;o:render();native.dump('/tmp/linkos-launcher.frame')
    o.startMenuOpen=false;o.quickPanelOpen=true;o:render();native.dump('/tmp/linkos-system-panel.frame')
    o.quickPanelOpen=false

    o:openApp('store');o:render();native.dump('/tmp/linkos-store.frame')
    o:openApp('calculator');o:render();native.dump('/tmp/linkos-calculator.frame')
    o:openApp('settings');o.settingsTab='style';o:render();native.dump('/tmp/linkos-settings.frame')

    o:renderUserLockDisplay(native);native.dump('/tmp/linkos-lock.frame')
  end
  total=total+1
  disk['/user/notes.txt']=nil
end
local packages=dofile('src/ui/packages.lua')
http={get=function(url)
  local id=url:match('/([^/]+)%.lua$')
  local f=assert(io.open('packages/'..id..'.lua'));local s=f:read('*a');f:close()
  return {read=function(n) return s:sub(1,n) end,close=function() end}
end}
for _,p in ipairs(packages.catalog) do
  assert(packages.install(p.id));assert(packages.installed(p.id))
  assert(packages.install(p.id));assert(fs.exists(packages.path(p.id)..'.backup'))
  local o=OS.new();o:refreshDisplays();o:openApp('pkg:'..p.id)
  assert(#o.windows==1 and not o.windows[1].renderError)
  assert(packages.remove(p.id));assert(not packages.installed(p.id))
  assert(fs.exists(packages.path(p.id)..'.removed'))
end
http.get=function() return nil,'offline' end
assert(not packages.install('tasks'))
http.get=function() return {read=function() return 'not valid lua !' end,close=function() end} end
assert(not packages.install('tasks'))
print('PASS: '..total..' workspace sizes, actual built-in renderers, windows, dialogs, package lifecycle and failures')
