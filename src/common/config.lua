return {
  NAME = "Computer Link",
  NETWORK_NAME = "AstralNet",
  VERSION = "0.2.3",
  PROTOCOL_VERSION = 2,

  MAGIC = "COMPUTER_LINK",
  PROTOCOL = "astralnet.link.v2",
  SERVER_HOSTNAME = "MER",

  ROOT = "/computer-link",
  DATA_DIR = "/computer-link/data",
  DATABASE_FILE = "/computer-link/data/mer.db",
  HISTORY_FILE = "/computer-link/data/history.db",
  CRASH_FLAG = "/computer-link/data/crashed.flag",

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
  HACK_MAX_LIST_ENTRIES = 50,

  -- Seuls ces Computer IDs peuvent lancer des commandes d'intrusion.
  -- Les autres PC restent des cibles potentielles mais ne peuvent pas attaquer.
  HACK_OPERATOR_IDS = {
    [1] = true
  },

  CRASH_RECOVERY_SECONDS = 10,

  GITHUB_RAW = "https://raw.githubusercontent.com/nexox9official-source/computer-link/main/"
}
