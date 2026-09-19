-- LinkOS package gps 1.0
return {draw=function(ctx)
  local d=ctx.data
  ctx.draw.text(ctx.target,2,2,'GPS',colors.cyan,colors.black,ctx.w-3)
  ctx.button('gps:locate',2,4,12,'LOCALISER',function()
    if not gps or not gps.locate then
      d.error='API GPS indisponible.'
      return
    end
    local x,y,z=gps.locate(2,false)
    if not x then
      d.error='Aucune tour GPS detectee.'
      d.pos=nil
    else
      d.error=nil
      d.pos={x=x,y=y,z=z}
    end
  end)
  if d.pos then
    ctx.draw.text(ctx.target,2,7,'Position',colors.lightGray,colors.black,ctx.w-3)
    ctx.draw.text(ctx.target,2,8,string.format('X %.1f',d.pos.x),colors.white,colors.black,ctx.w-3)
    ctx.draw.text(ctx.target,2,9,string.format('Y %.1f',d.pos.y),colors.white,colors.black,ctx.w-3)
    ctx.draw.text(ctx.target,2,10,string.format('Z %.1f',d.pos.z),colors.white,colors.black,ctx.w-3)
  elseif d.error then
    ctx.draw.text(ctx.target,2,7,d.error,colors.orange,colors.black,ctx.w-3)
  else
    ctx.draw.text(ctx.target,2,7,'Appuie sur LOCALISER.',colors.lightGray,colors.black,ctx.w-3)
  end
end}
