-- Server-provided Computer Link hint.
if fs.exists("/computer-link/role.txt") then
  return
end

if settings.get("computer_link.hide_hint", false) then
  return
end

if term.isColor and term.isColor() then
  term.setTextColor(colors.lightBlue)
end
print("[Computer Link] AstralNet disponible : tape 'link'")
if term.isColor and term.isColor() then
  term.setTextColor(colors.white)
end
