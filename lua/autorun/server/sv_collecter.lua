FILE_PATH = "data_collector/storage.txt"
FOLDER_NAME = "data_collector"
DAMAGE_TYPES = {
  [DMG_GENERIC] = "generic",
  [DMG_CRUSH] = "crush",
  [DMG_BULLET] = "bullet",
  [DMG_SLASH] = "slash",
  [DMG_BURN] = "burn",
  [DMG_VEHICLE] = "vehicle",
  [DMG_FALL] = "fall",
  [DMG_BLAST] = "blast",
  [DMG_CLUB] = "club",
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
players_alive = {}

function Initialize() -- creates a data_collector directory on server start if there is none
  if not file.IsDir(FOLDER_NAME, "DATA") then
    file.CreateDir(FOLDER_NAME, "DATA")
  end
  if not file.Exists(FILE_PATH, "DATA") then
    file.Write(FILE_PATH, "// Initial Row // \n")
  end
end

function ServerStart() -- saves server starting information
  local action = 'server_start'
  local action_table = {
    ['action'] = action,
    ['time'] = os.time()
  }
  add_table_to_file(action_table)
end

function PlayerJoin(ply) -- saves player join information
  local action = 'player_join'
  local user_info = extract_player_table(ply)
  local action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['time'] = os.time()
  }
  add_table_to_file(action_table)
end

function WeaponPickedUp(weapon, ply)
  if (not ply:IsTerror()) or (not ply:IsActive()) then
    return false
  end
  local action = 'weapon_pickup'
  local weapon_info = extract_equipment_table(weapon)
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = ply:SteamID(),
    ['weapon'] = weapon_info,
    ['time'] = os.time()
  }
  add_table_to_file(action_table)
end

function RoundBegin()
  local spectator_list = {}
  local traitors_list = {}
  local detectives_list = {}
  local innocents_list = {}

  for _, ply in ipairs(player.GetAll()) do
    local user = {
      ['user_steam_id'] = ply:SteamID(),
      ['karma'] = ply:GetLiveKarma(),
      ['credits'] = ply:GetCredits()
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
  add_table_to_file(action_table)
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
  local action_table = {
    ['action'] = action,
    ['time'] = os.time(),
    ['result'] = win_reason
  }
  add_table_to_file(action_table)
end

function EquipmentBought(ply, equipment, is_item)
  if (not ply:IsTerror()) or (not ply:IsAlive()) then
    return true
  end

  local action = 'equipment_bought'
  -- local user_info = extract_player_table(ply)
  local equipment_info = {
    ['name'] = equipment, -- returns class_name if weapon || returns id if equipment
    ['role'] = ply:GetRoleString()
  }
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = ply:SteamID(),
    ['equipment'] = equipment_info,
    ['is_item'] = is_item       -- returns equipment_id if eqipment || returns nil if weapon
  }
  add_table_to_file(action_table)
end

function CorpseSearch(ply, corpse, is_covert, is_long_range, was_traitor)
  if not ply:IsActive() then return true end

  local action = 'corpse_searched'
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = ply:SteamID(),
    ['corpse_steam_id'] = corpse.sid,
    ['is_covert'] = is_covert,
    ['is_long_range'] = is_long_range,
    ['was_traitor'] = was_traitor
  }
  add_table_to_file(action_table)
end

function FoundDNA(ply, dna_owner, ent)
  local action = 'found_dna'
  local action_table = {
    ['action'] = action,
    ['user_steam_id'] = ply:SteamID(),
    ['suspect_steam_id'] = dna_owner:SteamID(),
  }
  add_table_to_file(action_table)
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
  add_table_to_file(action_table)
end )

hook.Add( "EntityTakeDamage", "EntityDamageExample2", function(target, dmginfo)
  if target:IsPlayer() and target:IsActive() then
    local inflictor = dmginfo:GetInflictor()
    local damage_info = {}
    -- dmg_target = {}
    -- dmg_inflictor = {} --  player
    -- dmg_weapon = "" --     weapom | prop_physics | world | item
    -- dmg_info = "" --       bullet | crush        | fall  | explosive

    if inflictor:IsPlayer() or dmginfo:GetAttacker():IsPlayer() then
      local inf_steam_id = ""
      if inflictor:IsPlayer() then
        inf_steam_id = inflictor:SteamID()
      else
        inf_steam_id = dmginfo:GetAttacker():SteamID()
      end

      damage_info = {
        ['target'] = {
            ['steam_id'] = target:SteamID(),
            ['health'] = target:Health(),
            ['position'] = target:GetPos()
        },
        ['inflictor'] = {
          ['steam_id'] = inf_steam_id,
          ['position'] = inflictor:GetPos()
        },
        ['weapon'] = util.WeaponFromDamage(dmginfo),
        ['damage_points'] = dmginfo:GetDamage(),
        ['damage_type'] = GetDMGTypeStr(dmginfo:GetDamageType())
      }
    else
      damage_info = {
        ['target'] = {
          ['steam_id'] = target:SteamID(),
          ['health'] = target:Health()
        },
        ['inflictor'] = nil, -- sollte world sein
        ['weapon'] = util.WeaponFromDamage(dmginfo),
        ['damage_points'] = dmginfo:GetDamage(),
        ['damage_type'] = GetDMGTypeStr(dmginfo:GetDamageType())
      }
    end

    local action_table = {
      ['action'] = action,
      ['target'] = damage_info['target'],
      ['inflictor'] = damage_info['inflictor'],
      ['weapon'] = damage_info['weapon'],
      ['damage_points'] = damage_info['damage_points'],
      ['damage_type'] = damage_info['damage_type'],
      ['time'] = os.time()
    }
    add_table_to_file(action_table)
  end
end )

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

-- //////   [helpers]   //////

function add_table_to_file(table)
  local json = util.TableToJSON(table)
  local string = json .. '\n'
  file.Append(FILE_PATH, string)
end

function extract_player_table(ply)
  local user_info = {
    ['steam_id'] = ply:SteamID(),
    ['name'] =  ply:GetName(),
    ['bot'] = ply:IsBot(),
    ['user_id'] = ply:UserID()
  }
  return user_info
end

function extract_equipment_table(equip)
  local equipment_info = {
    ['name'] = equip:GetClass(),
    ['index'] = equip:EntIndex()
  }
  return equipment_info
end

-- Helper function to turn a dmg flag into a string representation
function GetDMGTypeStr(flag)
  return DAMAGE_TYPES[flag]
end




-- this shall provide some useful commands
--[[
  include("NAME DES RELATIVEN DATEIPFADES") -- einfügen von abhängigkeiten

  isValid()

  ply: (https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/terrortown/gamemode/player.lua)
  (https://github.com/Facepunch/garrysmod/blob/master/garrysmod/gamemodes/terrortown/gamemode/player_ext_shd.lua)
  :GetPos()  --
  :GetCredits() -- credits from the player
  :GetEquipmentItems() -- items from the player
  :GetMaxHealth()
  :Health()
  :IsPlayer()  -- KA wo ich das her hab
  :IsActive() -- Spieler noch am Leben?
  :IsTerror() -- Im Spiel?
  :IsSpec() -- Im Spectator
  :IsActiveDetective()
  :IsTraitor()
  :IsDeadTerror()

  ragdolls:
  rag.player_ragdoll : bool -- true if player ragdoll else false


  util.GetAlivePlayers() -- Alle lebenden Players


  Eigenene Hooks Können mit:
  hook.Run("HOOK_NAME", parameter...)

  ENT:
  :Initalize() -- Konstruktor funktionen???
  self:Function() -- selbst aufruf
  ]]