-- LinkOS package units 1.0
local conversions={
  {'Metres > kilometres',function(n) return n/1000 end,'km'},
  {'Kilometres > metres',function(n) return n*1000 end,'m'},
  {'Celsius > Fahrenheit',function(n) return n*9/5+32 end,'F'},
  {'Fahrenheit > Celsius',function(n) return (n-32)*5/9 end,'C'},
  {'Minutes > secondes',function(n) return n*60 end,'s'}
}
return {draw=function(ctx)
  ctx.draw.text(ctx.target,2,2,'CONVERTISSEUR',colors.cyan,colors.black,ctx.w-3)
  for i,c in ipairs(conversions) do
    ctx.button('units:'..i,2,4+i*2,math.min(ctx.w-3,28),c[1],function()
      local n=tonumber(ctx.prompt(c[1],'Entre une valeur numerique'))
      if n then ctx.data.result=string.format('%.6g %s',c[2](n),c[3])
      else ctx.data.result='Valeur invalide' end
    end)
  end
  ctx.draw.text(ctx.target,2,4,ctx.data.result or 'Choisir une conversion',colors.white,colors.black,ctx.w-3)
end}
