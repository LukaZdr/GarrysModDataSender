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
  action = '[ServerStart]'
  time = CurTime()
  string = action .. ' time: ' .. time .. '\n'
  file.Append(FILE_PATH, string)
end

function PlayerJoin( ply ) -- saves player join information
  action = '[PlayerJoin]'
  player = ply:UniqueID()
  time = CurTime()
  string = action .. ' player: ' .. player .. ', time: ' .. time .. '\n'
  file.Append(FILE_PATH, string)
  -- [ TODO ] Send User Infos with join so webapp can make profile
end

gameevent.Listen( "player_disconnect" )
hook.Add( "player_disconnect", "player_disconnect_example", function( data )
	local name = data.name			// Same as Player:Nick()
	local steamid = data.networkid		// Same as Player:SteamID()
	local id = data.userid			// Same as Player:UserID()
	local bot = data.bot			// Same as Player:IsBot()
	local reason = data.reason		// Text reason for disconnected such as "Kicked by console!", "Timed out!", etc...

  file.Append(FILE_PATH, 'Test')
end )

-- //////   [ events ]   //////

-- //////   [ hooks ]   //////
hook.Add("Initialize", "InitializeFile", Initialize)
hook.Add("Initialize", "ServerStart", ServerStart)
hook.Add("PlayerInitialSpawn", "PlayerJoin", PlayerJoin)
