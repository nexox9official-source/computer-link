-- LinkOS package system 1.1
local ui=dofile('/computer-link/src/ui/fluent.lua')
local started=os.clock()
return {draw=function(ctx)
  local t=ctx.theme or ui.theme('blue')
  local names=peripheral.getNames()
  local free=fs.getFreeSpace('/')
  local label=(os.getComputerLabel and os.getComputerLabel()) or '-'
  ui.sectionTitle(ctx.target,2,2,ctx.w-3,'Infos systeme','Etat local en lecture seule',t.accent)
  local rows={
    {'Computer ID','#'..tostring(os.getComputerID())},
    {'Nom',label},
    {'Stockage libre',tostring(free)..' B'},
    {'Peripheriques',tostring(#names)},
    {'Session',string.format('%.0f s',os.clock()-started)}
  }
  local y=6
  for _,row in ipairs(rows) do
    ctx.draw.fill(ctx.target,2,y,ctx.w-3,3,t.surface)
    ctx.draw.text(ctx.target,3,y,row[1],t.muted,t.surface,14)
    ctx.draw.text(ctx.target,3,y+1,row[2],t.text,t.surface,ctx.w-5)
    y=y+4
  end
end}