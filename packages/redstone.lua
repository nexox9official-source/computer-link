-- LinkOS package redstone 1.0
return {draw=function(ctx)
  ctx.draw.text(ctx.target,2,2,'REDSTONE LOCAL',colors.cyan,colors.black,ctx.w-3)
  if not redstone or not redstone.getSides then
    ctx.draw.text(ctx.target,2,5,'API redstone indisponible.',colors.lightGray,colors.black,ctx.w-3)
    return
  end
  local sides=redstone.getSides()
  local y=4
  for _,side in ipairs(sides) do
    local output=redstone.getOutput(side)
    local input=redstone.getInput(side)
    local label=string.upper(side)..'  OUT:'..(output and 'ON' or 'OFF')..'  IN:'..(input and 'ON' or 'OFF')
    ctx.button('redstone:'..side,2,y,math.min(ctx.w-3,32),label,function()
      redstone.setOutput(side,not redstone.getOutput(side))
      ctx.notice('Sortie '..side..' modifiee.')
    end)
    y=y+2
  end
  ctx.draw.text(ctx.target,2,y+1,'Clique une face pour basculer sa sortie.',colors.lightGray,colors.black,ctx.w-3)
end}
