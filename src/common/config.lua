local SOURCE_REF = "main"
local sourcePath = "/computer-link/source_ref.txt"
if fs and fs.exists and fs.exists(sourcePath) then
  local handle = fs.open(sourcePath, "r")
  if handle then
    local value = tostring(handle.readAll() or ""):gsub("%s+", "")
    handle.close()
    if value ~= "" and not value:find("..", 1, true)
      and value:match("^[%w%._%-%/]+$") then
      SOURCE_REF = value
    end
  end
end

return {
  NAME = "Computer Link",
  NETWORK_NAME = "AstralNet",
  VERSION = "0.20.0",
  PROTOCOL_VERSION = 2,

  MAGIC = "COMPUTER_LINK",
  PROTOCOL = "astralnet.link.v2",
  SERVER_HOSTNAME = "MER",

  ROOT = "/computer-link",
  DATA_DIR = "/computer-link/data",
  DATABASE_FILE = "/computer-link/data/mer.db",
  HISTORY_FILE = "/computer-link/data/history.db",
  CRASH_FLAG = "/computer-link/data/crashed.flag",
  HACKED_STATE_FILE = "/computer-link/data/hacked_state.db",

  MESSAGE_MAX = 500,
  LOCAL_HISTORY_MAX = 500,

  HACK_MAGIC = "COMPUTER_LINK_HACK",
  HACK_PROTOCOL = "astralnet.hack.v1",
  HACK_PROTOCOL_VERSION = 1,
  HACK_CHANNEL = 55123,
  HACK_MAX_DISTANCE = 64,
  HACK_DEFAULT_SECURITY = 2,
  HACK_BASE_DIFFICULTY = 4000,
  HACK_MAX_PROOF = 300000,
  HACK_CHALLENGE_SECONDS = 30,
  HACK_SESSION_SECONDS = 120,
  HACK_DUMP_MESSAGES = 25,
  HACK_MAX_READ_BYTES = 4096,
  HACK_MAX_WRITE_BYTES = 4096,
  HACK_MAX_LIST_ENTRIES = 50,

  HACK_OPERATOR_IDS = {},

  CRASH_RECOVERY_SECONDS = 10,

  SOURCE_REF = SOURCE_REF,
  GITHUB_RAW = "https://raw.githubusercontent.com/nexox9official-source/computer-link/" .. SOURCE_REF .. "/"
}
