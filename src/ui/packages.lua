-- Official LinkOS application catalogue. Installing never executes the download.
local config = dofile('/computer-link/src/common/config.lua')
local M = {}
local ROOT = '/computer-link/apps/'
local BASE = config.GITHUB_RAW .. 'packages/'
local FALLBACK = {
  {id='tasks',title='Mes taches',version='1.0',description='Checklist personnelle sauvegardee.'},
  {id='stopwatch',title='Chronometre',version='1.0',description='Chrono avec pause et remise a zero.'},
  {id='units',title='Convertisseur',version='1.0',description='Distance, temperature et temps.'},
  {id='devices',title='Peripheriques',version='1.0',description='Inspecter les appareils et inventaires.'},
  {id='calendar',title='Calendrier',version='1.0',description='Heure et jour du monde Minecraft.'},
  {id='system',title='Infos systeme',version='1.0',description='Etat local du Computer et de ses peripheriques.'},
  {id='redstone',title='Controle Redstone',version='1.0',description='Piloter les sorties redstone du poste local.'},
  {id='gps',title='GPS',version='1.0',description='Localiser le Computer avec le reseau GPS.'}
}
M.catalog = FALLBACK
M.catalogSource = 'local'

local function validEntry(value)
  return type(value)=='table'
    and type(value.id)=='string'
    and #value.id>=1 and #value.id<=32
    and not value.id:find('[^%w_%-]')
    and type(value.title)=='string' and #value.title>=1 and #value.title<=40
    and type(value.version)=='string' and #value.version>=1 and #value.version<=16
    and type(value.description)=='string' and #value.description<=120
end

function M.refreshCatalog()
  if not http or not http.get or not textutils or not textutils.unserializeJSON then
    return false,'Catalogue distant indisponible'
  end

  local ok,response,err=pcall(http.get,BASE..'catalog.json')
  if not ok or not response then
    return false,tostring(err or response or 'Reseau indisponible')
  end

  local source=response.read(32769)
  pcall(response.close)
  if type(source)~='string' or #source>32768 then
    return false,'Catalogue invalide ou trop volumineux'
  end

  local decoded=textutils.unserializeJSON(source)
  if type(decoded)~='table' or tonumber(decoded.schema)~=1 or type(decoded.apps)~='table' then
    return false,'Format de catalogue invalide'
  end

  local nextCatalog={}
  local seen={}
  for _,entry in ipairs(decoded.apps) do
    if not validEntry(entry) or seen[entry.id] then
      return false,'Entree de catalogue invalide'
    end
    seen[entry.id]=true
    nextCatalog[#nextCatalog+1]={
      id=entry.id,
      title=entry.title,
      version=entry.version,
      description=entry.description
    }
  end

  if #nextCatalog==0 or #nextCatalog>100 then
    return false,'Catalogue vide ou trop grand'
  end

  M.catalog=nextCatalog
  M.catalogSource='remote'
  return true,#nextCatalog
end

function M.find(id)
  for _,p in ipairs(M.catalog) do if p.id==id then return p end end
end
function M.path(id)
  assert(M.find(id),'Application inconnue')
  return ROOT..id..'.lua'
end
function M.installed(id) return fs.exists(M.path(id)) end
function M.install(id)
  local p=M.find(id)
  if not p then return false,'Application inconnue' end
  if not http or not http.get then return false,'HTTP indisponible' end
  local ok,response,err=pcall(http.get,BASE..id..'.lua')
  if not ok or not response then return false,tostring(err or response or 'Reseau indisponible') end
  local readOK,source=pcall(response.read,65537)
  pcall(response.close)
  if not readOK or type(source)~='string' or #source>65536 then return false,'Paquet invalide ou trop volumineux' end
  if not load(source,'@package:'..id,'t',{}) then return false,'Syntaxe Lua invalide' end
  if not source:find('-- LinkOS package '..id..' '..p.version,1,true) then return false,'Version du paquet incompatible' end
  local path=M.path(id)
  local success,failure=pcall(function()
    fs.makeDir(ROOT)
    local temp=path..'.download'
    local f=assert(fs.open(temp,'w'),'Ecriture impossible')
    f.write(source); f.close()
    if fs.exists(path) then
      -- Keep the previous working version; never delete user data.
      local backup=path..'.backup'
      if fs.exists(backup) then fs.delete(backup) end
      fs.move(path,backup)
    end
    local moved,moveErr=pcall(fs.move,temp,path)
    if not moved then
      if fs.exists(path..'.backup') and not fs.exists(path) then fs.move(path..'.backup',path) end
      error(moveErr)
    end
  end)
  return success,success and 'Application installee' or tostring(failure)
end
function M.remove(id)
  local path=M.path(id)
  if not fs.exists(path) then return true end
  -- Recoverable removal. Personal documents are untouched.
  local removed=path..'.removed'
  if fs.exists(removed) then return false,'Une copie retiree existe deja : reinstaller ou gerer les fichiers.' end
  return pcall(fs.move,path,removed)
end
return M
