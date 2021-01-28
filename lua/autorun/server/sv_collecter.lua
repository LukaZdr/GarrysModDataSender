FILE_PATH = "data_collector/storage.txt"
FOLDER_NAME = "data_collector"
DEBUG = false
WRITING_LOGS = false
DOMAIN="localhost:3000"
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
last_respawned = {}

function Initialize() -- creates a data_collector directory on server start if there is none
  if not file.IsDir(FOLDER_NAME, "DATA") then
    file.CreateDir(FOLDER_NAME, "DATA")
  end
  if not file.Exists(FILE_PATH, "DATA") then
    file.Write(FILE_PATH, "")
  end
end

function ServerStart() -- saves server starting information
  local action = 'server_start'
  local action_table = {
    ['action'] = action,
    ['time'] = os.time()
  }
  log(action_table, "/api/v1/server_start")
end

function PlayerJoin(ply) -- saves player join information
  local action = 'player_join'
  local user_info = extract_player_table(ply)
  local action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['time'] = os.time()
  }
  log(action_table, "/api/v1/users")
end

function WeaponPickedUp(weapon, ply)
  if not ply:IsTerror() then
    return false
  end
  local action = 'weapon_pickup'
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = user_identifier(ply),
    ['picked_up'] = get_pickup_info(weapon),
    ['ping'] = ply:Ping(),
    ['time'] = os.time()
  }
  log(action_table, "endpoint")
end

function RoundBegin()
  local spectator_list = {}
  local traitors_list = {}
  local detectives_list = {}

  for _, ply in pairs(player.GetAll()) do
    local user = {
      ['user_steam_id'] = user_identifier(ply),
      ['karma'] = ply:GetLiveKarma(),
      ['stats'] = {
        ["score"] = ply:Frags(),
        ["deaths"] = ply:Deaths(),
      },
      ['credits'] = ply:GetCredits(),
      ['items'] = ply:GetEquipmentItems(),
      ['ping'] = ply:Ping()
    }
    if ply:IsSpec() then
      spectator_list = table.ForceInsert(spectator_list, user) -- spectator roles are also innocent thats the wroason for this workaround
    elseif ply:IsTraitor() then
      traitors_list = table.ForceInsert(traitors_list, user)
    elseif ply:IsActiveDetective() then
      detectives_list = table.ForceInsert(detectives_list, user)
    else
      innocents_list = table.ForceInsert(innocents_list, user)
    end
  end

  local action_table = {
    ['action'] = 'round_start',
    ['time'] = os.time(),
    ['traitors'] = traitors_list,
    ['detectives'] = detectives_list,
    ['innocent'] = innocents_list,
    ['spectator'] = spectator_list,
    ['map'] = game.GetMap()
  }
  log(action_table, "endpoint")
end

function RoundEnd(result)
  local action = 'round_end'
  win_reason = ''
  if result == WIN_TRAITOR then
    win_reason = 'win_traitor'
  elseif result == WIN_INNOCENT then
    win_reason = 'win_innocent'
  else
    win_reason = 'win_timelimit'
  end

  local result = {}
  local dead = {}
  local alive = {}

  for _, ply in pairs(player.GetAll()) do
    if ply:IsSpec() and not ply:IsTerror() then
      role = "spectator"
    elseif ply:IsTraitor() then
      role = "traitor"
    elseif ply:IsActiveDetective() then
      role = "detective"
    else
      role = "innocent"
    end

    local user = {
      ['user_steam_id'] = user_identifier(ply),
      ['karma'] = ply:GetLiveKarma(),
      ['stats'] = {
        ["score"] = ply:Frags(),
        ["deaths"] = ply:Deaths(),
      },
      ['credits'] = ply:GetCredits(),
      ['items'] = ply:GetEquipmentItems(),
      ['ping'] = ply:Ping(),
      ['role'] = role
    }

    if ply:Alive()
    then
      alive = table.ForceInsert(alive, user)
    else
      dead = table.ForceInsert(dead, user)
    end
  end

  local action_table = {
    ['action'] = action,
    ['time'] = os.time(),
    ['reason'] = win_reason,
    ['result'] = {
      ["dead"] = dead,
      ["survived"] = alive
    }
  }
  log(action_table, "endpoint")
end

function EquipmentBought(ply, equipment, is_item)
  if (not ply:IsTerror()) or (not ply:IsActive()) then
    return true
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

  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = user_identifier(ply),
    ['is_traitor'] = ply:IsTraitor(),
    ['ping'] = ply:Ping(),
    ['bought_equipment'] = nameOfItem
  }
  log(action_table, "endpoint")
end

function CorpseSearch(ply, corpse, is_covert, is_long_range, was_traitor)
  if not ply:IsActive() then return true end

  local action = 'corpse_searched'
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = user_identifier(ply),
    ['corpse_steam_id'] = corpse.sid,
    ['is_covert'] = is_covert,
    ['is_long_range'] = is_long_range,
    ['corpse_was_traitor'] = was_traitor
  }
  log(action_table, "endpoint")
end

function FoundDNA(ply,dna_owner, ent)
  local scanned_ent = ""
  if ent:GetClass() == 'prop_ragdoll' then
    scanned_ent = ent.sid
  else
    scanned_ent = ent:GetClass()
  end

  local action = 'found_dna'
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = user_identifier(ply),
    ['suspect_steam_id'] = user_identifier(dna_owner),
    ['scanned_ent'] = scanned_ent, -- corpse.sid (user:SteamI()) or equipment name
    ['time'] = os.time()
  }
  log(action_table, "endpoint")
end

gameevent.Listen('player_disconnect')
hook.Add( 'player_disconnect', 'player_disconnect_example', function(data)
  local action = 'player_disconnect'
  local user = {
    ['steam_id'] = data.networkid,
    ['name'] =  data.name,
    ['reason'] =  data.reason,
    ['user_id'] =  data.userid,
    ['bot'] = data.bot
  }
  local action_table = {
    ['action'] = action,
    ['user'] =  user,
    ['time'] = os.time()
  }
  log(action_table, "endpoint")
end )

function UserTakesDamage(target, dmginfo)
  if target:IsPlayer() and target:IsActive() and dmginfo:GetDamage() > 0 then
    local inflictor = dmginfo:GetInflictor()
    local damage_info = {}
    -- dmg_target = {}
    -- dmg_inflictor = {} --  player
    -- dmg_weapon = "" --     weapom | prop_physics | world | item
    -- dmg_info = "" --       bullet | crush        | fall  | explosive

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
            ['steam_id'] = user_identifier(target),
            ['health_before_hurt'] = target:Health(),
            ['position'] = target:GetPos(),
            ['volicity'] = target:GetVelocity(),
            ['ping'] = target:Ping(),

        },
        ['inflictor'] = {
          ['steam_id'] = user_identifier(ply),
          ['position'] = ply:GetPos(),
          ['volicity'] = ply:GetVelocity(),
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
          ['steam_id'] = user_identifier(target),
          ['ping'] = target:Ping(),
          ['health_before_hurt'] = target:Health(),
          ['position'] = target:GetPos(),
          ['volicity'] = target:GetVelocity()
        },
        ['inflictor'] = nil, -- sollte world sein
        ['weapon'] = dmginfo:GetInflictor():GetClass(),
        ['was_headshot'] = (target.was_headshot and dmginfo:IsBulletDamage()),
        ['damage_points'] = dmginfo:GetDamage(),
        ['damage_type'] = GetDMGTypesStr(dmginfo:GetDamageType())
      }
    end
    local action_table = {
      ['action'] = 'player_hurt',
      ['target'] = damage_info['target'],
      ['inflictor'] = damage_info['inflictor'],
      ['weapon'] = damage_info["weapon"],
      ['damage_points'] = damage_info['damage_points'],
      ['damage_type'] = damage_info['damage_type'],
      ['was_headshot'] = damage_info['was_headshot'],
      ['time'] = os.time()
    }
    log(action_table, "endpoint")
  end
end

function DefibRevive(reviver)
  local action_table = {
    ['action'] = 'player_revived',
    ['reviver'] = user_identifier(reviver),
    ['revived'] = user_identifier(last_respawned),
    ['time'] = os.time()
  }
  log(action_table, "endpoint")
end

function HandleDeath(victim, inflictor, attacker)
  if not IsValid(victim) or victim:IsActive() then
    local cause = "unknown"
    if IsValid(inflictor) then
      if inflictor:IsPlayer() then
        cause = inflictor:SteamID()
      elseif inflictor:IsWeapon() then
        cause = inflictor:GetClass()
      elseif IsEntity(inflictor) then
        cause = inflictor:GetClass()
      else
        cause = inflictor
      end
    end

    if attacker:IsPlayer() then
      attacker = {
        ["steam_id"] = user_identifier(attacker),
        ["ping"] =  attacker:Ping()
      }
    end

    local action_table = {
      ['action'] = 'player_was_killed',
      ['victim'] = {
        ["steam_id"] = user_identifier(victim),
        ["ping"] = victim:Ping(),
      },
      ['attacker'] = attacker,
      ['cause'] = cause,
      ['time'] = os.time()
    }

    log(action_table, "endpoint")
  end
end


function Spawn( ply )
  if ply:IsActive() then
    last_respawned = ply
  end
end

hook.Add( "PlayerSpawn", "some_unique_name", Spawn )
-- //////   [ hooks ]   //////
hook.Add('Initialize', 'InitializeFile', Initialize)
hook.Add('Initialize', 'ServerStart', ServerStart)
hook.Add('PlayerInitialSpawn', 'PlayerJoin', PlayerJoin)
hook.Add('WeaponEquip', 'WeaponEquipExample', WeaponPickedUp)
hook.Add('TTTBeginRound', 'round_begin', RoundBegin)
hook.Add('TTTEndRound', 'round_end', RoundEnd)
hook.Add('TTTOrderedEquipment', 'equipment_bought', EquipmentBought)
hook.Add('TTTCanSearchCorpse', 'corpse_searched', CorpseSearch)
hook.Add('TTTFoundDNA', 'found_dna', FoundDNA)
hook.Add("EntityTakeDamage", "player_hurt", UserTakesDamage)
hook.Add('UsedDefib', 'user_was_revived', DefibRevive)
hook.Add('PlayerDeath', 'player_was_killed', HandleDeath)

-- //////   [helpers]   //////


function log(table, endpoint)
  local json = util.TableToJSON(table)
  if WRITING_LOGS then
    local string = json .. '\n'
    file.Append(FILE_PATH, string)
  else
    local url = DOMAIN .. endpoint
    print(url)
    LaunchJSONRequest(url, json)
  end
end

function extract_player_table(ply)
  local user_info = {
    ['steam_id'] = user_identifier(ply),
    ['name'] =  ply:GetName(),
    ['bot'] = ply:IsBot()
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

function user_identifier(user)
  if DEBUG then
    return user:GetName()
  else
    return user:SteamID()
  end
end


function get_pickup_info(pickup)
  return  {
    ["name"] = pickup:GetClass(),
    ["type"] = WEPS.TypeForWeapon(pickup:GetClass()), -- pickup slot index
    ["ammo"] = game.GetAmmoName(pickup:GetPrimaryAmmoType()) or "undefined",
    ["is_weapon"] = pickup:IsWeapon()
  }
end

-- full url, with the json payload
function LaunchJSONRequest(url, json)
  -- enconding already defined as default
  parameters = {
    ["failed"] = HandleBadRequest,
    ["success "] = HandleSuccessRequest,
    ["method"] = "POST", --case sensitive
    ["url"] = url,
    ["headers"] = {["Content-Type"] = "application/json"},
    ["body"] = json
  }
  return HTTP(parameters)
end

-- test connection
function Ping(url)
  print("starting ping...")
  parameters = {
    ["failed"] = HandleBadRequest,
    ["success "] = HandleSuccessRequest,
    ["method"] = "GET", --case sensitive
    ["url"] = url,
  }
  return HTTP(parameters)
end

function HandleSuccessRequest(code, body, table)
  print("success ", code, " ", body, " ", table)
end

function HandleBadRequest(reason)
    print("failed ", reason)
end
