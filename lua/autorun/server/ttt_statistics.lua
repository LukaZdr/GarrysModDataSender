--[=====[
TTTStatistics
  Created by github.com/LukaZdr and github.com/P0werE


Gathers information about the game



InterestingHooks
https://wiki.facepunch.com/gmod/Game_Events
player_changename

-- VELOCITY/Position need to be transformed to list, instead of one string
-- CHECK DATA TYPE
-- change type of weapon to slot
-- corpse searched missing suspsect
-- Player:GetActiveWeapon() -- if player cause is same as attacker?
-- Player:GetAmmotCount() AmmoCount of Player
-- Player:GetEntityInUse()
-- Player:GetWeapons() Returns a table of the player's weapons. 


Resources
https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/terrortown/gamemode/player.lua
https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/terrortown/gamemode/player_ext.lua
https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/terrortown/gamemode/player_ext_shd.lua
https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/base/gamemode/player.lua

--]=====]


--[ GLOBALS ]
-- //////   [ File DB Flags ]   //////
--    Flag to allow game logs to  be written
local TTT_STATS_WRITING_LOGS = CreateConVar("tttstatistics_write_logs", "1", FCVAR_CHEAT,  "Enable write logs to file", 0, 1 )
--    Flag to allow game to send the logs to the host via http
local TTT_STATS_HOST = CreateConVar("tttstatistics_url", "http://tttstatistics-rest:3030", FCVAR_CHEAT,  "Enable write logs to host", nil, nil )
local TTT_STATS_WRITE_TO_DB = CreateConVar("tttstatistics_write_db", "0", FCVAR_CHEAT, "Enable write log to api", 0, 1 )
local TTT_STATS_DB_PRINT_SUCCESSFUL = CreateConVar("tttstatistics_debug", "1", FCVAR_CHEAT,  "Enable debug", 0, 1 ) 
local TTT_STATISTICS_TOKEN = CreateConVar("tttstatistics_token", "", FCVAR_CHEAT, "Set token as header", nil, nil )



-- instead of writing directly to db host, accumulate round info and send it after round is over
local TTT_DUMP_AT_END = true

-- Epoch Time 
-- Important 
local SERVER_START_TIME = os.time()

concommand.Add( "print_date", function( ply, cmd, args )
  -- '2006-01-02T15:04:05.999999999Z07:00'
  -- '2006-01-02T15:04:05.999.999.999Z07:00'
  -- os.date("%Y-%m-%dT%X.---"
  -- os.date("%Y-%m-%dT%X.---"
  -- os.date("%Y-%m-%dT%X.MS.NS.000Z00:00")
  local nowDeltaTimeInSeconds = SysTime()  
  print("Hello", nowDeltaTimeInSeconds)
end )

--  //////   [ File IO Flags ]   //////
--    Foldername where statistics will be written to
--    filename will be "session" followed by the timestamp in YEARMONTHDAYHOURMINUTE
local TTT_STATS_FOLDER_NAME = "ttt_statistics"
--    global variable which will be written over by the Initialize Hook


-- //////   [ File DB Flags ]   //////
-- Host to send the data to

-- Http Methods as globals which need to be uppercase
local TTT_STATS_HTTP_METHOD_POST = 'POST'
local TTT_STATS_HTTP_METHOD_PATCH = 'PATCH'
local TTT_STATS_HTTP_METHOD_GET = 'GET'
-- allow to write the data to the database



--[=====[
  PrepareRound:  {
   ['roundid'] = roundid,
   ['action'] = 'round prepare',
   ['outcome'] = 'preparing',
   ['time'] = EpochTime(),
   ['map'] = game.GetMap()
  }

  start: {
    ['roundid'] = roundid,
    ['action'] = 'round start',
    ['time'] = EpochTime(),
    ['traitors'] = traitors_list,
    ['detectives'] = detectives_list,
    ['innocents'] = innocents_list,
    ['spectators'] = spectators_list,
    ['map'] = game.GetMap()
  }

  actions {
    PlayerTakesDamages []
    PlayerDieds []
    EquipmentBoughts[]
    ItemPickedUps []
    CorpseSearchs []
    FoundDNAs[]
  }

  end: {
    ['roundid'] = roundid,
    ['action'] = action,
    ['time'] = EpochTime(),
    ['reason'] = win_reason,
    ['result'] = {
      ["dead"] = dead,
      ["survived"] = alive
    }
  }

--]=====]

function NewBuffer()
  return {
    ['action'] = "buffer",
    ['start_time'] = SERVER_START_TIME,
    ['prepare']= nil,
    ['start']= nil,
    ['actions']= {
      ['playertakesdamages']= {},
      ['playerdieds']= {},
      ['equipmentboughts']= {},
      ['itempickedups']= {},
      ['corpsecearchs']= {},
      ['founddnas']= {},
      ['defibrevives']= {},
    },
    ['end']= nil,
  }
end


-- Meta Class
local TTTStatistics = { roundid = "preparing", folderpath = TTT_STATS_FOLDER_NAME, file = ""}

function TTTStatistics:new(t)
  local tt = t  or {}
  tt =  setmetatable(tt, self)
  self.__index = self
  self.roundid = "preparing"
  self.logs = TTT_STATS_WRITING_LOGS:GetInt() > 0 
  self.dump = TTT_DUMP_AT_END
  self.db = TTT_STATS_WRITE_TO_DB:GetInt() > 0 
  self.folderpath = TTT_STATS_FOLDER_NAME
  self.dbLogSuccess = TTT_STATS_DB_PRINT_SUCCESSFUL:GetInt() > 0
  self.buffer = nil
  self.file = ""
  self.token = TTT_STATISTICS_TOKEN:GetString()
  return tt
end



-- Look up table to dissolbe the bit flag to a usable string
-- Note: that a damage can have multiple damage types
-- https://wiki.facepunch.com/gmod/Enums/DMG
local DAMAGE_TYPES = {
  [DMG_GENERIC] = "generic",
  [DMG_CRUSH] = "crush",
  [DMG_BULLET] = "bullet",
  [DMG_SLASH] = "slash",
  [DMG_BURN] = "burn",
  [DMG_VEHICLE] = "vehicle",
  [DMG_FALL] = "fall",
  [DMG_BLAST] = "blast",
  [DMG_CLUB] = "club", -- crowbar
  [DMG_SHOCK] = "shock",
  [DMG_SONIC] = "sonic",
  [DMG_ENERGYBEAM] = "enerybeam",
  [DMG_PREVENT_PHYSICS_FORCE] = "prevent physics force",
  [DMG_NEVERGIB] = "never gib", -- crossbow dmg
  [DMG_ALWAYSGIB] = "always gib", -- dunno
  [DMG_DROWN] = "drown",
  [DMG_PARALYZE] = "paralyze",
  [DMG_NERVEGAS] = "nerve gas",
  [DMG_POISON] = "poison",
  [DMG_RADIATION] = "radiation",
  [DMG_DROWNRECOVER] = "drown recover",
  [DMG_ACID] = "acid",
  [DMG_SLOWBURN] = "slow burn",
  [DMG_REMOVENORAGDOLL] = "remove no ragdoll",
  [DMG_PHYSGUN] = "physic gun",
  [DMG_PLASMA] = "plasma",
  [DMG_AIRBOAT] = "airboat",
  [DMG_DISSOLVE] = "dissolve",
  [DMG_BLAST_SURFACE] = "blast surface",
  [DMG_DIRECT] = "direct",
  [DMG_BUCKSHOT] = "buckshot",
  [DMG_SNIPER] = "sniper",
  [DMG_MISSILEDEFENSE] = "missile defense"
}



 -- Initialize called by the Initialize hook 
 -- Creates a directory under "data" and sets the Session filename to the current timestamp
function TTTStatistics:Initialize()

  self.file = "session_" .. os.date("%Y%m%d%H%M", os.time()) .. ".txt"
  print("TTTStatistics: " , "WRITING_LOGS " , self.logs , " WRITE_TO_DB: " ,  self.db)
  self:ServerStart()
end


-- ServerStart
-- Sends a serverstart request to the db host
function TTTStatistics:ServerStart() 
  local action = 'server start'
  local action_table = {
    ['action'] = action,
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
    ['map'] = game.GetMap()
  }
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/server', action_table, true)
end


-- ServerClose
-- Sends a ServerClose request to the db host to call the closing of a session
function TTTStatistics:ServerClose() 
  local action = "server shutting down"
  local action_table = {
    ['action'] = action,
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }
  self:Request(TTT_STATS_HTTP_METHOD_PATCH, '/api/v1/server', action_table, true)
end

-- PlayerJoins
-- Logs the event of a player connecting to the database
function TTTStatistics:PlayerJoin(ply)
  local action = 'player connect'
  local user_info = ExtractPlayerTable(ply)
  local action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }

  
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/actions/player/connect', action_table, true)
end

-- PlayerJoins
-- Logs the event of a player disconnecting from the server which includes
function TTTStatistics:PlayerDisconnect(ply)
  local action = 'player disconnect'
  local plyer = ExtractPlayerTable(ply)
  local user = {
    ['steam_id'] = plyer.steam_id,
    ['name'] =  plyer.name,
    ['reason'] =  data.reason
  }
  local action_table = {
    ['action'] = action,
    ['user'] =  user,
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/actions/player/disconnect', action_table, true)
end

-- PlayerTakesDamage
-- PlayerTakesDamage logs the event of any entity taking damage
-- A Guard is defined to only select player information
-- Note: We need to check if the player is alive in order to avoid the
--      logging of the spectator deathmatch
function TTTStatistics:PlayerTakesDamage(target, dmginfo)
  if not (target:IsPlayer() and target:IsActive() and dmginfo:GetDamage() > 0) then
    return
  end

  local inflictor = dmginfo:GetInflictor()
  local damage_info = {}
  -- Cases
  -- dmg_target = {}
  -- dmg_inflictor = {} --  player
  -- dmg_weapon = "" --     weapom | prop_physics | world | item
  -- dmg_info = "" --       bullet | crush        | fall  | explosive

  -- Get the information of the inflictor which can be a player
  if inflictor:IsPlayer() or dmginfo:GetAttacker():IsPlayer() then
    local weapon_used = {}
    local ply = {}
    
    if inflictor:IsPlayer() then
      -- if inflictor is player we know that a hand held weapon is used.
      ply = inflictor
      weapon_used =  GetWeaponName(util.WeaponFromDamage(dmginfo))
    else
      -- if inflictor is ent(weapon/item) damage maybe from item
      ply = dmginfo:GetAttacker()
      if IsValid(inflictor) then
        weapon_used = inflictor:GetClass()
      else
        weapon_used = 'unknown'
      end
    end

    damage_info = {
      ['target'] = {
          ['steam_id'] = UserIdentifier(target),
          ['health'] = target:Health(),
          ['position'] = VectorToList(target:GetPos()),
          ['velocity'] = VectorToList(target:GetVelocity()),
          ['ping'] = target:Ping(),

      },
      ['attacker'] = {
        ['steam_id'] = UserIdentifier(ply),
        ['position'] = VectorToList(ply:GetPos()),
        ['health'] = ply:Health(),
        ['velocity'] = VectorToList(ply:GetVelocity()),
        ['ping'] = ply:Ping(),
      },
      ['weapon'] = weapon_used,
      ['was_headshot'] = (target.was_headshot and dmginfo:IsBulletDamage()),
      ['damage_points'] = dmginfo:GetDamage(),
      ['damage_type'] = GetDMGTypesStr(dmginfo:GetDamageType())
    }
  else
    damage_info = {
      ['target'] = {
        ['steam_id'] = UserIdentifier(target),
        ['ping'] = target:Ping(),
        ['health'] = target:Health(),
        ['position'] = VectorToList(target:GetPos()),
        ['velocity'] = VectorToList(target:GetVelocity())
      },
      ['attacker'] = nil, -- sollte world sein
      ['weapon'] = dmginfo:GetInflictor():GetClass(),
      ['was_headshot'] = (target.was_headshot and dmginfo:IsBulletDamage()),
      ['damage_points'] = dmginfo:GetDamage(),
      ['damage_type'] = GetDMGTypesStr(dmginfo:GetDamageType())
    }
  end
  
  local roundid = self.roundid
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = 'player takes damge',
    ['target'] = damage_info['target'],
    ['attacker'] = damage_info['attacker'],
    ['weapon'] = damage_info["weapon"],
    ['damage_points'] = damage_info['damage_points'],
    ['damage_type'] = damage_info['damage_type'],
    ['was_headshot'] = damage_info['was_headshot'],
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }

  self.buffer.actions.playertakesdamages = table.ForceInsert(self.buffer.actions.playertakesdamages, action_table)
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/actions/player/damage', action_table)
end

-- PlayerDied
-- Logs the Event of a player who died
-- Gathers information of the victim, the weapon used and the attacker
-- Note: We need to check if the player is alive in order to avoid the
--      logging of the spectator deathmatch
function TTTStatistics:PlayerDied(victimPlayer, inflictorEntity, attackerEntity)
  if (not IsValid(victimPlayer)) or (not victimPlayer:IsPlayer()) then
    print("killed entity")
    return
  end
  print("killed player")

  local cause = "unknown"
  local attacker = nil

  -- overwrite the inflictor with the weapon
  if IsValid(inflictorEntity) and inflictorEntity == attackerEntity and ( inflictorEntity:IsPlayer() or inflictorEntity:IsNPC() )  then
    inflictorEntity = inflictorEntity:GetActiveWeapon()
    if (!IsValid( inflictorEntity ) ) then inflictorEntity = attackerEntity end
  end


  if IsValid(inflictorEntity) then
    if inflictorEntity:IsWeapon() then
      cause = inflictorEntity:GetPrintName()
    elseif inflictorEntity:IsPlayer() then
      cause = inflictorEntity:SteamID()
    elseif IsEntity(inflictorEntity) then
      cause = inflictorEntity:GetClass()
    else
      cause = inflictorEntity
    end
  end

  
  if attackerEntity:IsPlayer() then
    attacker = {
      ["steam_id"] = UserIdentifier(attackerEntity),
      ["ping"] =  attackerEntity:Ping()
    }
  end
  
  local roundid = self.roundid
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = 'player was killed',
    ['victim'] = {
      ["steam_id"] = UserIdentifier(victimPlayer),
      ["ping"] = victimPlayer:Ping(),
    },
    ['attacker'] = attacker,
    ['cause'] = cause,
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }

  self.buffer.actions.playerdieds = table.ForceInsert(self.buffer.actions.playerdieds, action_table)
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/actions/player/killed', action_table)
end

function TTTStatistics:DefibRevive(reviver)
  local roundid = self.roundid
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = 'player revived',
    ['reviver'] = UserIdentifier(reviver),
    ['revived'] = UserIdentifier(last_respawned),
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }

  self.buffer.actions.defibrevives = table.ForceInsert(self.buffer.actions.defibrevives, action_table)
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/actions/player/revive', action_table)
end

-- EquipmentBought
-- Logs the event of any entity buying something of the shop (traitor or detective, (and possibly an innocent shop))
function TTTStatistics:EquipmentBought(ply, equipment, is_item)
  if (not ply:IsTerror()) or (not ply:IsActive()) then
    return -- allow propegation of all the other hooks 
  end

  local action = 'equipment_bought'
  -- local user_info = extract_player_table(ply)
  local nameOfItem = ""
  -- returns class_name if weapon || returns id if equipment
  if is_item then
    nameOfItem = GetEquipmentItem(ply:GetRole(), is_item).name
  else
    nameOfItem = equipment
  end
  local roundid = self.roundid
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['steam_id'] = UserIdentifier(ply),
    ['role'] =  ply:GetRoleString(),
    ['ping'] = ply:Ping(),
    ['item'] = nameOfItem,
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }
  self.buffer.actions.equipmentboughts = table.ForceInsert(self.buffer.actions.equipmentboughts, action_table)
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/actions/items/bought', action_table)
end


-- ItemPickedUp
-- Logs the event of picking up an item
-- Note that the item type can be determined by the slot of the item f.e. 4 -> Primary Weapon
function TTTStatistics:ItemPickedUp(weapon, ply)
  if not ply:IsTerror() then
    return -- return nil to allow propegation of all the other hooks
  end


  local action = 'item pickup'
  local roundid = self.roundid
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['steam_id'] = UserIdentifier(ply),
    ['item'] = GetPickUpInfo(weapon),
    ['ping'] = ply:Ping(),
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }

    self.buffer.actions.itempickedups = table.ForceInsert(self.buffer.actions.itempickedups, action_table)
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/actions/items/pickup', action_table)
end

-- CorpseSearch
-- Logs the event of a CorpseSearch
-- Gathers the information CorpseSearch note that here there is a requirement of if the corpse can be searched
function TTTStatistics:CorpseSearch(ply, corpse, is_covert, is_long_range, was_traitor)
  if not ply:IsActive() or ply:IsBot() then return true end

  local action = 'corpse searched'
  local roundid = self.roundid
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['finder'] = UserIdentifier(ply),
    ['corpse'] = corpse.sid,
    ['is_covert'] = is_covert,
    ['is_long_range'] = is_long_range,
    ['corpse_was_traitor'] = was_traitor,
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }

  self.buffer.actions.corpsecearchs = table.ForceInsert(self.buffer.actions.corpsecearchs, action_table)
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/actions/search/corpse', action_table)
end


-- FoundDNA
-- Logs the event of a FoundDNA
-- Gathers the information FoundDNA
function TTTStatistics:FoundDNA(ply,dna_owner, ent)
  local scanned_ent = ""
  local isProp = false
  if ent:GetClass() == 'prop_ragdoll' then
    scanned_ent = ent.sid
  else
    scanned_ent = ent:GetClass()
  end

  local action = 'found dna'
  local roundid = self.roundid
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['investigator'] = UserIdentifier(ply),
    ['killer'] = UserIdentifier(dna_owner),
    ['victim'] = scanned_ent, -- corpse.sid (user:SteamI()) or equipment name
    ['is_prop'] = isProp,
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
  }

  self.buffer.actions.founddnas = table.ForceInsert(self.buffer.actions.founddnas, action_table)
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/actions/search/dna', action_table)
end


function Spawn(ply)
  if ply:IsActive() then
    last_respawned = ply
  end
end

-- PrepareRound
-- Logs the event of a PrepareRound
-- Gathers the information PrepareRound
function TTTStatistics:PrepareRound()
  self.roundid = tostring(os.time())
  local roundid = self.roundid
  local action_table = {
   ['roundid'] = roundid,
   ['action'] = 'round prepare',
   ['outcome'] = 'preparing',
   ['time'] = SERVER_START_TIME,
   ['delta_time'] = Now(),
   ['map'] = game.GetMap()
  }
  self.buffer = NewBuffer()
  self.buffer.prepare = action_table
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/round', action_table)
end

-- RoundBegin
-- Logs the event of a new round begin
-- Gathers the information for a new round 
function TTTStatistics:RoundBegin()
  local spectators_list = {}
  local traitors_list = {}
  local detectives_list = {}
  local innocents_list = {}

  for _, ply in pairs(player.GetAll()) do
    local user = {
      ['steam_id'] = UserIdentifier(ply),
      ['karma'] = ply:GetLiveKarma(),
      ['stats'] = {
        ["score"] = ply:Frags(),
        ["deaths"] = ply:Deaths(),
      },
      ['credits'] = ply:GetCredits(),
      ['ping'] = ply:Ping()
    }
    if ply:IsSpec() then
      spectators_list = table.ForceInsert(spectators_list, user) -- spectator roles are also innocent thats the wroason for this workaround
    elseif ply:IsTraitor() then
      traitors_list = table.ForceInsert(traitors_list, user)
    elseif ply:IsActiveDetective() then
      detectives_list = table.ForceInsert(detectives_list, user)
    else
      innocents_list = table.ForceInsert(innocents_list, user)
    end
  end

  
  local roundid = self.roundid
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = 'round start',
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
    ['traitors'] = traitors_list,
    ['detectives'] = detectives_list,
    ['innocents'] = innocents_list,
    ['spectators'] = spectators_list,
    ['map'] = game.GetMap()
  }

  self.buffer.start = action_table
  self:Request(TTT_STATS_HTTP_METHOD_PATCH, '/api/v1/round', action_table)
end


-- RoundEnd
-- Logs the event of a round end
-- Gathers the information of end round
function TTTStatistics:RoundEnd(result)
  local action = 'round end'
  win_reason = ''
  if result == WIN_TRAITOR then
    win_reason = 'win_traitor'
  elseif result == WIN_INNOCENT then
    win_reason = 'win_innocent'
  else
    win_reason = 'win_timelimit'
  end

  local dead = {}
  local alive = {}

  for _, ply in pairs(player.GetAll()) do
    local user = {
      ['steam_id'] = UserIdentifier(ply),
      ['karma'] = ply:GetLiveKarma(),
      ['stats'] = {
        ["score"] = ply:Frags(),    -- score on the other hand is important since it can reach negative values (would flatten this also)
        ["death"] = ply:Deaths(),   -- wouldn't like to save deaths here since we get it from the round actions
      },
      ['credits'] = ply:GetCredits(),
      ['ping'] = ply:Ping(),
      ['role'] = ply:GetRoleString()
    }

    if ply:Alive()
    then
      alive = table.ForceInsert(alive, user)
    else
      dead = table.ForceInsert(dead, user)
    end
  end

  local roundid = self.roundid -- maybe obstructed by racing condition
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['time'] = SERVER_START_TIME,
    ['delta_time'] = Now(),
    ['reason'] = win_reason,
    ['result'] = {
      ["dead"] = dead,
      ["survived"] = alive
    }
  }

  self.buffer['end'] = action_table
  self:Dump()
  self:Request(TTT_STATS_HTTP_METHOD_POST, '/api/v1/round/over', action_table)
end





-- //////   [helpers]   //////

function ExtractPlayerTable(ply)
  local user_info = {
    ['steam_id'] = UserIdentifier(ply),
    ['name'] =  ply:GetName()
  }
  return user_info
end

-- Helper function to turn a dmg flag into a string representation
function GetDMGTypesStr(flag)
 local dmges = {}
 local exponent = 0
 while (flag > 0)
  do
    if flag % 2 == 1 then
      dmges = table.ForceInsert(dmges, DAMAGE_TYPES[2 ^ exponent])
      flag = flag - 1
    end

    flag = flag / 2
    exponent = exponent + 1
  end
  return dmges
end

function UserIdentifier(user)
  if (user:SteamID() == "BOT") then
    return user:SteamID()  .. "_" .. user:GetName()
  end

  return user:SteamID()
end


function GetPickUpInfo(pickup)
  
  local name = pickup:GetClass()
  if pickup:IsWeapon() then
    name = GetWeaponName(pickup)
  end
  return  {
    ["name"] = name,
    ["slot"] = WEPS.TypeForWeapon(pickup:GetClass()), -- pickup slot index
    ["ammo"] = game.GetAmmoName(pickup:GetPrimaryAmmoType()) or "undefined"
  }
end

function TTTStatistics:Log(table)
  if self.file == "" then
    self.file =  "session_" .. os.date("%Y%m%d%H%M", os.time()) .. ".txt"
  end

  file.CreateDir(self.folderpath)
  local json = util.TableToJSON(table)
  local ss = json .. '\n'
  file.Append(self.folderpath .. "/" .. self.file, ss)
end

-- split a string by its separator into a list
function VectorToList(input)
  return input:ToTable()
end

-- Returns Time as Seconds
-- Delta from ServerStartTime
function Now()
  -- local rawTimeResult = util.NiceFloat(SERVER_START_TIME + RealTime() * 1000)
  -- local beg, index = string.find(rawTimeResult, "[.]")
  -- local result =  string.sub(rawTimeResult, 0, index-1)
  return SysTime()
end

-- [ Request ]

GMSTAT_HOOK="TTTSTATISTIC_MAKE_REQUEST"
GMSTAT_HOOKID="TTTSTATISTIC_MAKE_REQUESTID"

function TTTStatistics:Request(method, url, body, force)
  if TTT_STATS_WRITING_LOGS:GetInt() > 0  then
    self:Log(table.Copy(body))
  end

  if force == nil then 
    force = false
  end

  if !force and self.dump then
      return 
  end

  if TTT_STATS_WRITE_TO_DB:GetInt() > 0  and force then
    hook.Call(GMSTAT_HOOK, GMSTAT_HOOKID, method, url, body, TTT_STATISTICS_TOKEN:GetString())
  end
end


function TTTStatistics:Dump()
  if self.buffer == nil then
    return
  end

  if self.dump then
    if TTT_STATS_WRITING_LOGS:GetInt() > 0 then
      self:Log(table.Copy(self.buffer))
    end

    if TTT_STATS_WRITE_TO_DB:GetInt() > 0   then
      print("TTT STATISTICS: CALLING DUMP\n")
      hook.Call(GMSTAT_HOOK, GMSTAT_HOOKID, TTT_STATS_HTTP_METHOD_POST, "/api/v1/round/dump", self.buffer, self.token)
    end
  end
end


function AsyncRequest(method, url, body, token)
  local json = util.TableToJSON(body)
  if string.len(TTT_STATS_HOST:GetString()) == 0 then
    return
  end
  
  
  url = TTT_STATS_HOST:GetString() .. url
  local parameters = {
    ["failed"] = function (reason)
      error("TTTStatistics: Failed Request: " .. method .. " " ..  url ..": " ..reason)
    end,
    ["success"] = function (code, body, table)
      if not (code == 200) then
        print("TTTStatistics: Failed Request with body: " .. json)
        error("TTTStatistics: Failed Request: " .. method .. " " ..  url .. " ".. util.NiceFloat(code) .. " ".. body, 2)
      elseif TTT_STATS_DB_PRINT_SUCCESSFUL then
        print("TTTStatistics: Success Request: " ..  method .. " " ..  url .. "\n")
      end
    end,
    ["method"] = method , --case sensitive
    ["url"] = url,
    ["headers"] = {
      ["Content-Type"] = "application/json", 
      ['X-Token'] = "mytoken"},
    ["type"] = "application/json",
    ["body"] = json,
  }
  HTTP(parameters)
end



local collector = TTTStatistics:new(nil)



function GetWeaponName(weapon) 
  if weapon == nil then
    return "empty"
  end

  local name =  weapon:GetPrintName() 
  if name == "Scripted Weapon" or name == "..." then
    name = weapon:GetClass()
  end

  return name
end



  -- //////   [ hooks  ]   //////
-- Hooks need to be defined down here to make sure that the functions are in the scope
-- NOTE: that the hooks need to return nil or nothing to propate propably through


function CollectData()
    print("TTTStatistics:: hooks ready")
    concommand.Add( "tttstatistics_print_distance", CalcDistance)
    concommand.Add( "tttstatistics_debug", function ()
    
    end)
    gameevent.Listen("player_connect")
    gameevent.Listen("player_disconnect")
    hook.Add('Initialize', 'TTTStatisticsInitializeFile', function() collector:Initialize() end)
    hook.Add('PlayerInitialSpawn', 'TTTStatisticsPlayerJoin', function(ply) collector:PlayerJoin(ply) end)
    hook.Add('WeaponEquip', 'TTTStatisticsWeaponEquip', function(item, ply) collector:ItemPickedUp(item, ply) end)
    hook.Add('TTTPrepareRound', 'TTTStatisticsRoundPrepare', function()  collector:PrepareRound() end)
    hook.Add('TTTBeginRound', 'TTTStatisticsRoundBegin', function() collector:RoundBegin() end)
    hook.Add('TTTEndRound', 'TTTStatisticsRoundEnd', function(result) collector:RoundEnd(result);  end)
    hook.Add('TTTOrderedEquipment', 'TTTStatisticsEquipmentBought', function(ply, item, is_item) collector:EquipmentBought(ply, item, is_item) end)
    hook.Add('TTTFoundDNA', 'TTTStatisticsFoundDNA', function(ply, dna, ent) collector:FoundDNA(ply, dna, ent) end)
    hook.Add("EntityTakeDamage", "TTTStatisticsPlayerHurt", function(target, dmgInfo) collector:PlayerTakesDamage(target, dmgInfo) end)
    hook.Add('PlayerDeath', 'TTTStatisticsPlayerWasKilled', function(v, i, attacker) collector:PlayerDied(v, i, attacker) end)
    hook.Add('player_disconnect', 'TTTStatisticsPlayerDisconnect', function(ply) collector:PlayerDisconnect(ply) end)
    hook.Add('ShutDown', 'TTTStatisticsServerShuttingDown', function() collector:ServerClose() end)
    hook.Add(GMSTAT_HOOK, GMSTAT_HOOKID, AsyncRequest)
    -- hook.Add("PlayerSpawn", "TTTStatisticsPlayerSpawn", collector:Spawn)
    hook.Add('UsedDefib', 'TTTStatisticsUserWasRevived',  function(revive) collector:DefibRevive(revive) end)
    hook.Add('TTTCanSearchCorpse', 'TTTStatisticsCorpseSearchedExample', 
  function(ply, corpse, is_covert, is_long_range, was_traitor) 
    collector:CorpseSearch(ply, corpse, is_covert, is_long_range, was_traitor)
  end)
end 


-- Only call mod if Trouble in Terrorist Town is active
gamemode.Call("Trouble in Terrorist Town", CollectData())
