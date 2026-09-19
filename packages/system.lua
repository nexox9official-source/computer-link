-- LinkOS package system 1.0
local started=os.clock()
return {draw=function(ctx)
  local names=peripheral.getNames()
  local free=fs.getFreeSpace('/')
  local label=os.getComputerLabel() or '-'
  ctx.draw.text(ctx.target,2,2,'SYSTEME',colors.cyan,colors.black,ctx.w-3)
  local rows={
    {'Computer ID','#'..tostring(os.getComputerID())},
    {'Nom',label},
    {'Stockage libre',tostring(free)..' B'},
    {'Peripheriques',tostring(#names)},
    {'Session',string.format('%.0f s',os.clock()-started)}
  }
  local y=4
  for _,row in ipairs(rows) do
    ctx.draw.text(ctx.target,2,y,row[1],colors.lightGray,colors.black,15)
    ctx.draw.text(ctx.target,18,y,row[2],colors.white,colors.black,math.max(1,ctx.w-19))
    y=y+2
  end
  ctx.draw.text(ctx.target,2,y+1,'Lecture seule.',colors.lightGray,colors.black,ctx.w-3)
end}
