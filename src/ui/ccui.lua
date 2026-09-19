-- LinkOS CCUI 0.22
-- Component patterns adapted from MIT-licensed OneOS/Opus UI concepts.
-- See /computer-link/THIRD_PARTY_UI.md.

local draw = dofile("/computer-link/src/ui/draw.lua")

local C = {}

local function clamp(v,a,b) return math.max(a,math.min(b,v)) end

function C.panel(target,x,y,w,h,theme,opts)
  opts=opts or {}
  local bg=opts.bg or theme.surface
  draw.fill(target,x,y,w,h,bg)
  if opts.accent then draw.fill(target,x,y,1,h,opts.accent) end
  if opts.title then
    draw.text(target,x+(opts.accent and 2 or 1),y,opts.title,
      opts.titleFg or theme.text,bg,math.max(1,w-(opts.accent and 3 or 2)))
  end
  if opts.subtitle and h>=2 then
    draw.text(target,x+(opts.accent and 2 or 1),y+1,opts.subtitle,
      theme.muted,bg,math.max(1,w-(opts.accent and 3 or 2)))
  end
  return {x=x,y=y,w=w,h=h}
end

-- Opus-style stateful button: normal/focused/inactive/primary/danger.
function C.button(target,x,y,w,label,theme,state)
  state=state or {}
  local bg=theme.buttonQuiet
  local fg=theme.text
  if state.inactive then
    fg=theme.muted
  elseif state.danger then
    bg=theme.danger
  elseif state.primary then
    bg=theme.accent
  elseif state.focused or state.selected then
    bg=theme.selection
  end
  draw.fill(target,x,y,w,1,bg)
  local text=tostring(label or "")
  local pad=state.compact and 0 or 1
  draw.text(target,x+pad,y,text,fg,bg,math.max(1,w-pad*2))
  if state.focused and w>=2 then
    draw.text(target,x+w-1,y,">",theme.accent,bg,1)
  end
  return {x=x,y=y,w=w,h=1}
end

-- Opus-style tabs: a single active page, obvious selection, no nested chrome.
function C.tabs(target,x,y,w,items,selected,theme)
  local rects={}
  local count=math.max(1,#items)
  local cell=math.max(4,math.floor(w/count))
  local cursor=x
  for i,item in ipairs(items) do
    local width=(i==count) and (x+w-cursor) or cell
    local active=item.id==selected
    draw.fill(target,cursor,y,width,1,active and theme.selection or theme.surface)
    draw.text(target,cursor+1,y,tostring(item.label or item.id),
      active and theme.text or theme.muted,
      active and theme.selection or theme.surface,
      math.max(1,width-2))
    if active and width>=3 then draw.fill(target,cursor,y+1,width,1,theme.accent) end
    rects[#rects+1]={id=item.id,x=cursor,y=y,w=width,h=2}
    cursor=cursor+width
  end
  return rects
end

-- OneOS-style compact application card: icon area, title/meta, action.
function C.appRow(target,x,y,w,app,theme,iconDrawer,state)
  state=state or {}
  local h=4
  local bg=state.selected and theme.selection or theme.surface
  draw.fill(target,x,y,w,h,bg)
  if iconDrawer then iconDrawer(app.id,x+1,y,false,bg) end

  local title=tostring(app.title or app.name or app.id or "Application")
  local meta=tostring(app.meta or app.author or app.version or "")
  draw.text(target,x+6,y,title,theme.text,bg,math.max(1,w-7))
  draw.text(target,x+6,y+1,meta,theme.muted,bg,math.max(1,w-7))

  if app.description then
    draw.text(target,x+6,y+2,tostring(app.description),theme.muted,bg,math.max(1,w-7))
  end

  local action=tostring(app.action or "OUVRIR")
  local actionW=math.min(math.max(7,#action+2),math.max(7,w-8))
  local ax=x+w-actionW
  draw.fill(target,ax,y+3,actionW,1,state.primary and theme.accent or theme.surface2)
  draw.text(target,ax+1,y+3,action,theme.text,
    state.primary and theme.accent or theme.surface2,math.max(1,actionW-2))

  return {x=x,y=y,w=w,h=h,action={x=ax,y=y+3,w=actionW,h=1}}
end

-- Scrolling-list state modeled after Opus ScrollingGrid.
function C.page(total,pageSize,offset)
  total=math.max(0,tonumber(total) or 0)
  pageSize=math.max(1,tonumber(pageSize) or 1)
  offset=clamp(tonumber(offset) or 0,0,math.max(0,total-pageSize))
  return {
    total=total,pageSize=pageSize,offset=offset,
    first=offset+1,last=math.min(total,offset+pageSize),
    canUp=offset>0,canDown=offset+pageSize<total
  }
end

function C.scrollbar(target,x,y,h,page,theme)
  if page.total<=page.pageSize then return end
  draw.fill(target,x,y,1,h,theme.surface2)
  local thumbH=math.max(1,math.floor(h*page.pageSize/page.total))
  local maxOffset=math.max(1,page.total-page.pageSize)
  local thumbY=y+math.floor((h-thumbH)*page.offset/maxOffset)
  draw.fill(target,x,thumbY,1,thumbH,theme.accent)
end

function C.modal(target,title,subtitle,theme,opts)
  opts=opts or {}
  local sw,sh=target.getSize()
  local w=math.min(opts.w or math.max(28,math.floor(sw*0.70)),math.max(18,sw-2))
  local h=math.min(opts.h or 8,math.max(6,sh-2))
  local x=math.max(1,math.floor((sw-w)/2)+1)
  local y=math.max(1,math.floor((sh-h)/2)+1)

  -- Opaque shadow works better than fake transparency on CC terminals.
  if x+w<=sw and y+h<=sh then
    draw.fill(target,x+1,y+1,w,h,theme.surface2)
  end
  draw.fill(target,x,y,w,h,theme.elevated or theme.surface)
  draw.fill(target,x,y,1,h,opts.accent or theme.accent)
  draw.text(target,x+2,y,tostring(title or "LinkOS"),theme.text,
    theme.elevated or theme.surface,math.max(1,w-3))
  if subtitle and h>=3 then
    draw.text(target,x+2,y+1,tostring(subtitle),theme.muted,
      theme.elevated or theme.surface,math.max(1,w-3))
  end
  return {x=x,y=y,w=w,h=h}
end

function C.inputField(target,x,y,w,value,theme,opts)
  opts=opts or {}
  local bg=opts.bg or theme.surface2
  local text=tostring(value or "")
  local prefix=opts.prefix or "> "
  local available=math.max(1,w-#prefix-1)
  if #text>available then text=text:sub(#text-available+1) end
  draw.fill(target,x,y,w,1,bg)
  draw.text(target,x+1,y,prefix,theme.accent,bg,math.min(#prefix,w-1))
  draw.text(target,x+1+#prefix,y,text,theme.text,bg,available)
  return {x=x,y=y,w=w,h=1,cursorX=math.min(x+w-1,x+1+#prefix+#text)}
end

function C.breadcrumb(target,x,y,w,parts,theme)
  draw.fill(target,x,y,w,1,theme.surface)
  local cursor=x+1
  for i,part in ipairs(parts) do
    local text=tostring(part.label or part)
    if cursor+#text>x+w-1 then break end
    draw.text(target,cursor,y,text,i==#parts and theme.text or theme.muted,
      theme.surface,math.min(#text,x+w-cursor))
    cursor=cursor+#text
    if i<#parts and cursor<x+w-1 then
      draw.text(target,cursor,y," > ",theme.muted,theme.surface,3)
      cursor=cursor+3
    end
  end
end

return C
