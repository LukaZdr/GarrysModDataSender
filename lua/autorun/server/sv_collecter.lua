FILE_PATH = "data_collector/storage.txt"
FOLDER_NAME = "data_collector"

function Initialize() -- creates a data_collector directory on server start if there is none
  if not file.IsDir(FOLDER_NAME, "DATA") then
    file.CreateDir(FOLDER_NAME, "DATA")
  end
  if not file.Exists(FILE_PATH, "DATA") then
    file.Write(FILE_PATH, "// Initial Row // \n")
  end
end

function ServerStart() -- saves server starting information
  action = 'server_start'
  action_table = {
    ['action'] = action,
    ['time'] = os.date()
  }
  action_json = util.TableToJSON(action_table)
  string = action_json .. '\n'
  file.Append(FILE_PATH, string)
end

function PlayerJoin(ply) -- saves player join information
  action = 'player_join'
  user_info = {
    ['steam_id'] = ply:SteamID(),
    ['name'] =  ply:GetName(),
    ['bot'] = ply:IsBot()
  }
  action_table = {
    ['action'] = action,
    ['user'] = user_info,
    ['time'] = os.date()
  }
  action_json = util.TableToJSON(action_table)
  string = action_json .. '\n'
  file.Append(FILE_PATH, string)
end

gameevent.Listen('player_disconnect')
hook.Add( 'player_disconnect', 'player_disconnect_example', function(data)
  action = 'player_disconnect'
  user = {
    ['steam_id'] = data.networkid,
    ['name'] =  data.name,
    ['reason'] =  data.reason,
    ['user_id'] =  data.userid,
    ['bot'] = data.bot
  }
  action_table = {
    ['action'] = action,
    ['user'] =  user,
    ['time'] = os.date()
  }
  action_json = util.TableToJSON(action_table)
  string = action_json .. '\n'
  file.Append(FILE_PATH, string)
end )

-- //////   [ hooks ]   //////
hook.Add('Initialize', 'InitializeFile', Initialize)
hook.Add('Initialize', 'ServerStart', ServerStart)
hook.Add('PlayerInitialSpawn', 'PlayerJoin', PlayerJoin)

-- //////   [helpers]   //////

