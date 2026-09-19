-- LinkOS package calendar 1.0
return {draw=function(ctx)
  local day=os.day and os.day() or nil
  local time=textutils.formatTime(os.time(),true)
  ctx.draw.text(ctx.target,2,2,'CALENDRIER',colors.cyan,colors.black,ctx.w-3)
  ctx.draw.text(ctx.target,2,4,'Heure du monde',colors.lightGray,colors.black,ctx.w-3)
  ctx.draw.text(ctx.target,2,5,time,colors.white,colors.black,ctx.w-3)
  if day then
    ctx.draw.text(ctx.target,2,7,'Jour Minecraft',colors.lightGray,colors.black,ctx.w-3)
    ctx.draw.text(ctx.target,2,8,tostring(day),colors.white,colors.black,ctx.w-3)
  end
  ctx.draw.text(ctx.target,2,11,'Actualise a chaque rafraichissement.',colors.lightGray,colors.black,ctx.w-3)
end}
