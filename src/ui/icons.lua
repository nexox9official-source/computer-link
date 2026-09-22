-- Original LinkOS 0.24 assets, drawn at 8x9 subpixels (4x3 terminal cells).
local I={}
local palette={b=colors.lightBlue,c=colors.cyan,y=colors.yellow,o=colors.orange,
  w=colors.white,g=colors.lightGray,p=colors.purple,r=colors.red,f=colors.black}
I.assets={
  home={"........","bb..bb..","bb..bb..","bb..bb..","........","bb..bb..","bb..bb..","bb..bb..","........"},
  messages={"........",".cccccc.","cccccccc","ccwwwwcc","cccccccc","ccwwwccc",".cccccc.","..cc....","..c....."},
  files={"........",".yyy....","yyyyy...","yooooooo","yooooooo","oooooooo","oooooooo","oooooooo",".oooooo."},
  notes={".wwwww..",".wwwwwg.",".wwwwwww",".wggggww",".wwwwwww",".wggggww",".wwwwwww",".wgggwww",".wwwwwww"},
  store={"...bb...","..b..b..","..b..b..",".bbbbbb.",".bbwwbb.",".bbwbbb.",".bbwwbb.",".bbbbbb.","..bbbb.."},
  calculator={".gggggg.",".gwwwwg.",".gwwwwg.",".gggggg.",".gwgwgg.",".gggggg.",".gwgwgg.",".gggggg.","..gggg.."},
  contacts={"...bb...","..bbbb..","..bbbb..","...bb...","........","..bbbb..",".bbbbbb.",".bbbbbb.","........"},
  network={"........","..cccc..",".c....c.","........","...cc...","..c..c..","........","...cc...","...cc..."},
  security={"...pp...",".pppppp.",".pppppp.",".ppppwp.",".pppwwp.","..pwwp..","..pppp..","...pp...","........"},
  settings={"...gg...",".g.gg.g.",".gggggg.","..gwwg..","ggwwwwgg","..gwwg..",".gggggg.",".g.gg.g.","...gg..."},
  about={"..bbbb..",".bbbbbb.","bbbwwbbb","bbbbbbbb","bbbwwbbb","bbbwwbbb","bbbwwbbb",".bbbbbb.","..bbbb.."},
  terminal={"gggggggg","gffffffg","gfwwfffg","gfffwffg","gfwwfffg","gffffffg","gfffwwfg","gffffffg","gggggggg"},
  hacker={"..rrrr..",".rrrrrr.","rrfrrfrr","rrfrrfrr","rrrrrrrr",".rffffr.",".rrrrrr.","..r..r..","........"},
  calendar={"..r..r..",".rrrrrr.",".rrrrrr.",".wwwwww.",".wgwgwg.",".wwwwww.",".wgwgwg.",".wwwwww.","........"},
  tasks={".wwwwww.",".wggggw.",".wwwwww.",".wgwwwg.",".wwgggw.",".wwwwww.",".wggggw.",".wwwwww.","........"},
  stopwatch={"...oo...","...oo...","..oooo..",".owwwwo.","oowwwooo","oowwwooo",".owowwo.","..oooo..","........"},
  units={"........",".bbbbbb.",".bwbbwbb",".bbbbbb.","........",".bbbbbb.",".bbwwbwb",".bbbbbb.","........"},
  devices={".pppppp.",".pffffp.",".pffffp.",".pffffp.",".pppppp.","...pp...","..pppp..","........","........"},
  system={".bbbbbb.",".bffffb.",".bffffb.",".bffffb.",".bbbbbb.","...bb...","..bbbb..","........","........"},
  redstone={"........","...rr...","..rrrr..",".rrrrrr.","rrrrrrrr",".rrrrrr.","..rrrr..","...rr...","........"},
  gps={"..gggg..",".ggwwgg.",".gwwwwg.",".ggwwgg.","..gggg..","..gggg..","...gg...","...gg...","........"},
}
function I.get(id)
  id=tostring(id or ""):gsub("^pkg:","")
  return I.assets[id] or I.assets.system
end

-- CC's mosaic characters encode five pixels; the sixth is the background.
-- Pick the two most useful colours locally, without UTF-8 conversion.
local function mosaic(pixels)
  local bg=pixels[6]
  local counts={}
  for _,c in ipairs(pixels) do if c~=bg then counts[c]=(counts[c] or 0)+1 end end
  local fg,best=bg,0
  for _,c in ipairs(pixels) do
    if (counts[c] or 0)>best then fg,best=c,counts[c] end
  end
  local mask=0
  for i=1,5 do if pixels[i]==fg and fg~=bg then mask=mask+2^(i-1) end end
  return string.char(128+mask),fg,bg
end

local function render(target,id,x,y,bg,selectedBg,cols,lines)
  local rows=I.get(id)
  local sw,sh=target.getSize()
  for cy=0,lines-1 do
    for cx=0,cols-1 do
      local tx,ty=x+cx,y+cy
      if tx>=1 and tx<=sw and ty>=1 and ty<=sh then
        local base=selectedBg or bg
        if not base and target.getLine then
          local _,_,line=target.getLine(ty)
          base=2^tonumber(line:sub(tx,tx),16)
        end
        base=base or colors.black
        local pixels={}
        for py=0,2 do for px=0,1 do
          local sy=math.floor((cy*3+py)*9/(lines*3))+1
          local sx=math.floor((cx*2+px)*8/(cols*2))+1
          local k=rows[sy]:sub(sx,sx)
          pixels[#pixels+1]=palette[k] or base
        end end
        local ch,fg,back=mosaic(pixels)
        target.setCursorPos(tx,ty)
        target.setTextColor(fg)
        target.setBackgroundColor(back)
        target.write(ch)
      end
    end
  end
end
function I.draw(target,id,x,y,bg,selectedBg)
  render(target,id,x,y,bg,selectedBg,4,3)
end
function I.drawMini(target,id,x,y,bg)
  render(target,id,x,y,bg,nil,2,1)
end
return I
