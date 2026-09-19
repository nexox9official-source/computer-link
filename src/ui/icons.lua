-- LinkOS icon assets 0.22.
-- Asset model inspired by OneOS MIT icon resources. See THIRD_PARTY_UI.md.
local I={}

-- Each icon is a 4x3 grid. "." is transparent; other letters select palette keys.
I.assets={
  home={
    {"bb.b","bb.b","...."},
    map={b=colors.lightBlue}
  },
  messages={
    {".cc.","c..c","ccc."},
    map={c=colors.cyan}
  },
  contacts={
    {".b..",".b..","bbb."},
    map={b=colors.lightBlue}
  },
  network={
    {"..g.",".gg.","ggg."},
    map={g=colors.lime}
  },
  security={
    {".pp.","pppp",".pp."},
    map={p=colors.purple}
  },
  files={
    {"oo..","oooo","oooo"},
    map={o=colors.orange}
  },
  notes={
    {"yyy.","y.y.","yyy."},
    map={y=colors.yellow}
  },
  calculator={
    {"ggg.","g.g.","ggg."},
    map={g=colors.green}
  },
  terminal={
    {"w...","ww..","w.w."},
    map={w=colors.lightGray}
  },
  settings={
    {"b.b.",".b..","b.b."},
    map={b=colors.lightBlue}
  },
  about={
    {".c..","....",".c.."},
    map={c=colors.cyan}
  },
  hacker={
    {"r.r.",".r..","r.r."},
    map={r=colors.red}
  },
  store={
    {".bb.","bbbb","b..b"},
    map={b=colors.blue}
  },
  tasks={
    {"c...","cc..","ccc."},
    map={c=colors.cyan}
  },
  stopwatch={
    {".o..","ooo.",".o.."},
    map={o=colors.orange}
  },
  units={
    {"b.b.",".b..","b.b."},
    map={b=colors.lightBlue}
  },
  devices={
    {"ppp.","p.p.","ppp."},
    map={p=colors.purple}
  },
  calendar={
    {"rrr.","r.r.","rrr."},
    map={r=colors.red}
  },
  system={
    {"bbb.",".b..","bbb."},
    map={b=colors.lightBlue}
  },
  redstone={
    {".r..","rrr.",".r.."},
    map={r=colors.red}
  },
  gps={
    {".g..","g.g.",".g.."},
    map={g=colors.lime}
  }
}

local function baseId(id)
  id=tostring(id or "")
  if id:sub(1,4)=="pkg:" then id=id:sub(5) end
  return id
end

function I.get(id)
  return I.assets[baseId(id)] or {
    {"bbbb","b..b","bbbb"},
    map={b=colors.lightBlue}
  }
end

function I.draw(target,id,x,y,bg,selectedBg)
  local asset=I.get(id)
  local rows=asset[1]
  local base=selectedBg or bg or colors.black
  for ry=1,3 do
    local line=rows[ry] or "...."
    for rx=1,4 do
      local key=line:sub(rx,rx)
      local colour=asset.map[key]
      if colour then
        target.setBackgroundColor(colour)
        target.setCursorPos(x+rx-1,y+ry-1)
        target.write(" ")
      elseif base then
        target.setBackgroundColor(base)
        target.setCursorPos(x+rx-1,y+ry-1)
        target.write(" ")
      end
    end
  end
end

return I
