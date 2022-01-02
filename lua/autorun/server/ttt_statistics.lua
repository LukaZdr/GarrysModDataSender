--[=====[
TTTStatistics
  Created by github.com/LukaZdr and github.com/P0werE


Gathers information oabout the game



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
-- We know globals are bad code, but we didnt see a better way to achieve this which was simple enough

-- //////   [ File DB Flags ]   ////// 
--    Flag to allow game logs to be written
WRITING_LOGS = true
--    Flag to allow game to send the logs to the host via http
WRITE_TO_DB = false


--  //////   [ File IO Flags ]   //////
--    Foldername where statistics will be written to
--    filename will be "session" followed by the timestamp in YEARMONTHDAYHOURMINUTE
FOLDER_NAME = "ttt_statistics"
--    global variable which will be written over by the Initialize Hook
--    points to the current file to which the logs will be written to
SESSION_FILE=""



-- //////   [ File DB Flags ]   //////
-- Host to send the data to
HOST="http://testpost.gmod:8080"
-- Http Methods as globals which need to be uppercase
HTTP_METHOD_POST = 'POST'
HTTP_METHOD_PATCH = 'PATCH'
HTTP_METHOD_GET = 'GET'
-- allow to write the data to the database
DB_PRINT_SUCCESSFUL = true

-- Round_ID will point to the current round of the game+
-- This global will be overwritten
ROUND_ID = "preparing"




-- //////   [ hooks ]   ////// [ROUND_ID = "preparing" ]
-- This global will be overwritten  by the whenever a new round start or ends 
-- (f.e PrepareRound RoundStart RoundOver)
ROUND_ID = "preparing"


-- Look up table to dissolbe the bit flag to a usable string
-- Note: that a damage can have multiple damage types
-- https://wiki.facepunch.com/gmod/Enums/DMG
DAMAGE_TYPES = {
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



-- //////   [ hooks  ]   //////
-- NOTE: that the hooks need to return nil or nothing to propate propably through
gameevent.Listen('player_disconnect')
hook.Add('Initialize', 'TTTStatisticsInitializeFile', Initialize)
hook.Add('PlayerInitialSpawn', 'TTTStatisticsPlayerJoin', PlayerJoin)
hook.Add('WeaponEquip', 'TTTStatisticsWeaponEquipExample', ItemPickedUp)
hook.Add('TTTBeginRound', 'TTTStatisticsRoundBegin', RoundBegin)
hook.Add('TTTEndRound', 'TTTStatisticsRoundEnd', RoundEnd)
hook.Add('TTTPrepareRound', 'TTTStatisticsRoundPrepare',  PrepareRound)
hook.Add('TTTOrderedEquipment', 'TTTStatisticsEquipmentBought', EquipmentBought)
-- hook.Add('TTTCanSearchCorpse', 'TTTStatisticsCorpseSearchedExample', CorpseSearch) This hook is being weird, regarding identifying of corpse and the confirmed dead table
hook.Add('TTTFoundDNA', 'TTT_StatisticsFoundDna', FoundDNA)
hook.Add("EntityTakeDamage", "TTTStatisticsPlayerHurt", PlayerTakesDamage)
hook.Add('UsedDefib', 'TTTStatisticsUserWasRevived', DefibRevive)
hook.Add('PlayerDeath', 'TTTStatisticsPlayerWasKilled', PlayerDied)
hook.Add( "PlayerSpawn", "TTTStatisticsPlayerSpawn", Spawn)
hook.Add( 'player_disconnect', 'TTTStatisticsPlayerDisconnect', PlayerDisconnect)
hook.Add('ShutDown', 'TTTStatisticsServerShuttingDown', ServerClose)



 -- Initialize called by the Initialize hook 
 -- Creates a directory under "data" and sets the Session filename to the current timestamp
function Initialize()
  SESSION_FILE = FOLDER_NAME .. "/session_" .. os.date("%Y%m%d%H%M", os.time()) .. ".txt"
  ServerLog("TTTStatistics Active:: " , "WRITING_LOGS" , WRITING_LOGS , " WRITE_TO_DB: " ,  WRITE_TO_DB )
  ServerStart()
end


-- ServerStart
-- Sends a serverstart request to the db host
function ServerStart() 
  local action = 'server start'
  local action_table = {
    ['action'] = action,
    ['time'] = EpochTime(),
    ['map'] = game.GetMap()
  }
  Request(HTTP_METHOD_POST, '/api/v1/server', action_table)
end


-- ServerClose
-- Sends a ServerClose request to the db host to call the closing of a session
function ServerClose() 
  local action = "server shutting down"
  local action_table = {
    ['action'] = action,
    ['time'] = EpochTime()
  }
  Request(HTTP_METHOD_PATCH, '/api/v1/server', action_table)
end

-- PlayerJoins
-- Logs the event of a player connecting to the database
function PlayerJoin(ply)
  local action = 'player connect'
  local user_info = ExtractPlayerTable(ply)
  local action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['time'] = EpochTime()
  }
  Request(HTTP_METHOD_POST, '/api/v1/actions/player/connect', action_table)
end

-- PlayerJoins
-- Logs the event of a player disconnecting from the server which includes
function PlayerDisconnect(data)
  local action = 'player disconnect'
  local user = {
    ['steam_id'] = data.networkid,
    ['name'] =  data.name,
    ['reason'] =  data.reason
  }
  local action_table = {
    ['action'] = action,
    ['user'] =  user,
    ['time'] = EpochTime()
  }
  Request(HTTP_METHOD_POST, '/api/v1/actions/player/disconnect', action_table)
end

-- PlayerTakesDamage
-- PlayerTakesDamage logs the event of any entity taking damage
-- A Guard is defined to only select player information
-- Note: We need to check if the player is alive in order to avoid the
--      logging of the spectator deathmatch
function PlayerTakesDamage(target, dmginfo)
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
      weapon_used = util.WeaponFromDamage(dmginfo):GetClass()
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
          ['volicity'] = VectorToList(target:GetVelocity()),
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
  
  local roundid = ROUND_ID
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = 'player takes damge',
    ['target'] = damage_info['target'],
    ['attacker'] = damage_info['attacker'],
    ['weapon'] = damage_info["weapon"],
    ['damage_points'] = damage_info['damage_points'],
    ['damage_type'] = damage_info['damage_type'],
    ['was_headshot'] = damage_info['was_headshot'],
    ['time'] = EpochTime()
  }

  Request(HTTP_METHOD_POST, '/api/v1/actions/player/damage', action_table)
end

-- PlayerDied
-- Logs the Event of a player who died
-- Gathers information of the victim, the weapon used and the attacker
-- Note: We need to check if the player is alive in order to avoid the
--      logging of the spectator deathmatch
function PlayerDied(victimPlayer, inflictorEntity, attackerEntity)
  if IsValid(victimPlayer) and not victimPlayer:IsActive()  then
    return nil
  end

  local cause = "unknown"
  local attacker = nil

  -- overwrite the inflictor with the weapon
  if IsValid(inflictorEntity) and inflictorEntity == attackerEntity and ( inflictorEntity:IsPlayer() or inflictorEntity:IsNPC() )  then
    inflictorEntity = inflictorEntity:GetActiveWeapon()
    if (!IsValid( inflictorEntity ) ) then inflictorEntity = attackerEntity end
  end


  if IsValid(inflictorEntity) then
    if inflictorEntity:IsWeapon() then
      cause = inflictorEntity:GetClass()
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
  
  local roundid = ROUND_ID
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = 'player was killed',
    ['victim'] = {
      ["steam_id"] = UserIdentifier(victimPlayer),
      ["ping"] = victimPlayer:Ping(),
    },
    ['attacker'] = attacker,
    ['cause'] = cause,
    ['time'] = EpochTime()
  }


  Request(HTTP_METHOD_POST, '/api/v1/actions/player/killed', action_table)
end

function DefibRevive(reviver)
  local roundid = ROUND_ID
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = 'player revived',
    ['reviver'] = UserIdentifier(reviver),
    ['revived'] = UserIdentifier(last_respawned),
    ['time'] = EpochTime()
  }
  Request(HTTP_METHOD_POST, '/api/v1/actions/player/revive', action_table)
end

-- EquipmentBought
-- Logs the event of any entity buying something of the shop (traitor or detective, (and possibly an innocent shop))
function EquipmentBought(ply, equipment, is_item)
  if (not ply:IsTerror()) or (not ply:IsActive()) then
    return nil -- allow propegation of all the other hooks 
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
  local roundid = ROUND_ID
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['steam_id'] = UserIdentifier(ply),
    ['role'] =  ply:GetRoleString(),
    ['ping'] = ply:Ping(),
    ['item'] = nameOfItem,
    ['time'] = EpochTime()
  }
  Request(HTTP_METHOD_POST, '/api/v1/actions/items/bought', action_table)
end


-- ItemPickedUp
-- Logs the event of picking up an item
-- Note that the item type can be determined by the slot of the item f.e. 4 -> Primary Weapon
function ItemPickedUp(weapon, ply)
  if not ply:IsTerror() then
    return nil -- return nil to allow propegation of all the other hooks
  end

  local action = 'item pickup'
  local roundid = ROUND_ID
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['steam_id'] = UserIdentifier(ply),
    ['item'] = GetPickUpInfo(weapon),
    ['ping'] = ply:Ping(),
    ['time'] = EpochTime()
  }
  Request(HTTP_METHOD_POST, '/api/v1/actions/items/pickup', action_table)
end


-- RoundBegin
-- Logs the event of a new round begin
-- Gathers the information for a new round 
function RoundBegin()
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

  
  ROUND_ID = tostring(EpochTime())
  local roundid = ROUND_ID
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = 'round start',
    ['time'] = EpochTime(),
    ['traitors'] = traitors_list,
    ['detectives'] = detectives_list,
    ['innocents'] = innocents_list,
    ['spectators'] = spectators_list,
    ['map'] = game.GetMap()
  }
  Request(HTTP_METHOD_POST, ' /api/v1/round', action_table)
end


-- RoundEnd
-- Logs the event of a round end
-- Gathers the information of end round
function RoundEnd(result)
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
        ["score"] = ply:Frags(),  -- score on the other hand is importatnt since it can reach negative values (would flatten this also)
        ["deaths"] = ply:Deaths(),  -- wouldn't like to save deaths here since we get it from the round actions
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

  local roundid = ROUND_ID -- maybe obstructed by racing condition
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['time'] = EpochTime(),
    ['reason'] = win_reason,
    ['result'] = {
      ["dead"] = dead,
      ["survived"] = alive
    }
  }

  ROUND_ID = "preparing" -- GLOBAL VARIALE which propegate the round id of the current run
  
  Request(HTTP_METHOD_PATCH, '/api/v1/round', action_table)
  RoundOver() 
end

-- CorpseSearch
-- Logs the event of a CorpseSearch
-- Gathers the information CorpseSearch note that here there is a requirement of if the corpse can be searched
function CorpseSearch(ply, corpse, is_covert, is_long_range, was_traitor)
  if not ply:IsActive() then return true end

  local action = 'corpse searched'
  local roundid = ROUND_ID
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['finder'] = UserIdentifier(ply),
    ['corpse'] = corpse.sid,
    ['is_covert'] = is_covert,
    ['is_long_range'] = is_long_range,
    ['corpse_was_traitor'] = was_traitor,
    ['time'] = EpochTime()
  }
  Request(HTTP_METHOD_POST, '/api/v1/actions/search/corpse', action_table)
  return true
end


-- FoundDNA
-- Logs the event of a FoundDNA
-- Gathers the information FoundDNA
function FoundDNA(ply,dna_owner, ent)
  local scanned_ent = ""
  local isProp = false
  if ent:GetClass() == 'prop_ragdoll' then
    scanned_ent = ent.sid
  else
    scanned_ent = ent:GetClass()
  end

  local action = 'found dna'
  local roundid = ROUND_ID
  local action_table = {
    ['roundid'] = roundid,
    ['action'] = action,
    ['investigator'] = UserIdentifier(ply),
    ['killer'] = UserIdentifier(dna_owner),
    ['victim'] = scanned_ent, -- corpse.sid (user:SteamI()) or equipment name
    ['is_prop'] = isProp,
    ['time'] = EpochTime()
  }
  Request(HTTP_METHOD_POST, '/api/v1/actions/search/dna', action_table)
end


function Spawn( ply )
  if ply:IsActive() then
    last_respawned = ply
  end
end

-- PrepareRound
-- Logs the event of a PrepareRound
-- Gathers the information PrepareRound
function PrepareRound()
  ROUND_ID = tostring(EpochTime())
  local roundid = ROUND_ID
  local action_table = {
   ['roundid'] = roundid,
   ['action'] = 'round prepare',
   ['outcome'] = 'preparing',
   ['time'] = EpochTime(),
   ['map'] = game.GetMap()
  }
  Request(HTTP_METHOD_POST, ' /api/v1/round/prepare', action_table)
end

-- RoundOver
-- Logs the event of a RoundOver
-- Gathers the information RoundOver
function RoundOver() 
  ROUND_ID = tostring(EpochTime())
  local roundid = ROUND_ID
  local action_table = {
   ['roundid'] = roundid,
   ['action'] = 'round prepare',
   ['outcome'] = 'round over',
   ['time'] = EpochTime(),
   ['map'] = game.GetMap()
  }
  Request(HTTP_METHOD_POST, ' /api/v1/round/over', action_table)
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
  return user:SteamID()
end


function GetPickUpInfo(pickup)
  return  {
    ["name"] = pickup:GetClass(),
    ["slot"] = WEPS.TypeForWeapon(pickup:GetClass()), -- pickup slot index
    ["ammo"] = game.GetAmmoName(pickup:GetPrimaryAmmoType()) or "undefined"
  }
end


function Log(table)
  file.CreateDir(FOLDER_NAME)
  local json = util.TableToJSON(table)
  local string = json .. '\n'
  file.Append(SESSION_FILE, string)
end

-- split a string by its separator into a list
function VectorToList(input)
  return input:ToTable()
end


function EpochTime()
  return util.NiceFloat(os.time())
end

-- [ Request ]

GMSTAT_HOOK="GMSTATISTIC_MAKE_REQUEST"
GMSTAT_HOOKID="GMSTATISTIC_MAKE_REQUESTID"

hook.Add(GMSTAT_HOOK, GMSTAT_HOOKID, AsyncRequest)


function Request(method, url, body)
  if WRITING_LOGS  then
    Log(table.Copy(body))
  end

  if WRITE_TO_DB then
    hook.Call(GMSTAT_HOOK, GMSTAT_HOOKID, method, url, body, "my_auth_token")
  end
end

function AsyncRequest(method, url, body, token)
  local json = util.TableToJSON(body)
  url = HOST .. url
  local parameters = {
    ["failed"] = function (reason)
      error("TTTStatistics: Failed Request: " .. method .. " " ..  url ..": " ..reason)
    end,
    ["success"] = function (code, body, table)
      if not (code == 200) then
        ServerLog("TTTStatistics: Failed Request with body: " .. json)
        error("TTTStatistics: Failed Request: " .. method .. " " ..  url .. " ".. util.NiceFloat(code) .. " ".. body, 2)
      elseif DB_PRINT_SUCCESSFUL then
        ServerLog("TTTStatistics: Success Request: " ..  method .. " " ..  url .. "\n")
      end
    end,
    ["method"] = method , --case sensitive
    ["url"] = url,
    ["headers"] = {
      ["Content-Type"] = "application/json", 
      ['X-Token'] = token},
    ["type"] = "application/json",
    ["body"] = json,
  }
  HTTP(parameters)
end