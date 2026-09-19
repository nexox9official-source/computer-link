-- LinkOS package units 1.1
local ui=dofile('/computer-link/src/ui/fluent.lua')
local conversions={
  {'Metres > kilometres',function(n) return n/1000 end,'km'},
  {'Kilometres > metres',function(n) return n*1000 end,'m'},
  {'Celsius > Fahrenheit',function(n) return n*9/5+32 end,'F'},
  {'Fahrenheit > Celsius',function(n) return (n-32)*5/9 end,'C'},
  {'Minutes > secondes',function(n) return n*60 end,'s'}
}
return {draw=function(ctx)
  local t=ui.theme('blue')
  ui.sectionTitle(ctx.target,2,2,ctx.w-3,'Convertisseur','Distances, temperature et temps',t.accent)
  ui.card(ctx.target,2,6,ctx.w-3,4,{bg=t.surface,accent=t.accent,title='Resultat',
    subtitle=ctx.data.result or 'Choisis une conversion ci-dessous.',muted=t.muted})
  local y=12
  for i,c in ipairs(conversions) do
    local width=math.min(ctx.w-3,30)
    ctx.button('units:'..i,2,y,width,c[1],function()
      local n=tonumber(ctx.prompt(c[1],'Entre une valeur numerique'))
      if n then ctx.data.result=string.format('%.6g %s',c[2](n),c[3])
      else ctx.data.result='Valeur invalide' end
    end)
    y=y+2
  end
end}