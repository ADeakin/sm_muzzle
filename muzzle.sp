#include <sourcemod>
#include <basecomm>
#include <clients>
#include <files>
#include <adt_array>

#define STEAMID_LENGTH 50
#define STEAMNAME_LENGTH 50

String:configFilePath[PLATFORM_MAX_PATH];
ArrayList:muzzledSteamIDs;
 
public Plugin myinfo =
{
	name = "Muzzle / Perma mute",
	author = "Emilio",
	description = "Auto mutes people and persists through maps, server restarts and sm_unmute",
	version = "1.0",
	url = "https://keet.pw/"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_muzzle", Command_Muzzle, ADMFLAG_GENERIC, "[SM] Usage: sm_muzzle <#userid|name> <on|off|check>");
	BuildPath(Path_SM,configFilePath,PLATFORM_MAX_PATH,"configs/muzzled_players.txt");
}

public Action Command_Muzzle(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_muzzle <#userid|name> <on|off|check>");
		return Plugin_Handled;
	}

	char target[65];
	char command[6];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, command, sizeof(command));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToCommand(client, "[SM] no targets found")
		return Plugin_Handled;
	}
	
	for (int i = 0; i < target_count; i++)
	{
		char name[STEAMID_LENGTH];
		name = GetName(target_list[i]);
		bool muzzled = IsPlayerMuzzled(target_list[i])
				
		if (strcmp(command,"on") == 0)
		{
			if (!muzzled)
			{
				muzzledSteamIDs.PushString(GetSteamID(target_list[i]));
				MutePlayer(target_list[i]);
				WriteConfigFile(configFilePath);				
			}			
			ReplyToCommand(client, "[SM] muzzled %s ", name)
			
		}
		else if (strcmp(command,"off") == 0)
		{
			if (muzzled)
			{
				UnmutePlayer(target_list[i])
				WriteConfigFile(configFilePath);
			}
			ReplyToCommand(client, "[SM] unmuzzled %s ", name) 
		}
		else if (strcmp(command,"check") == 0)
		{
			
			if(muzzled)
			{
				ReplyToCommand(client, "[SM] %s is muzzled", name)
			}
			else
			{
				ReplyToCommand(client, "[SM] %s is not muzzled", name)
			}
		}
		else
		{
			ReplyToCommand(client, "[SM] Usage: sm_muzzle <#userid|name> <on|off|check>");
		}
	}
	
	return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
	if(IsPlayerMuzzled(client))
	{
		MutePlayer(client);
	}
}

public void BaseComm_OnClientMute(int client, bool muteState)
{
	if(!muteState && IsPlayerMuzzled(client))
	{
		MutePlayer(client)
	}
}

bool IsPlayerMuzzled(int client)
{	
	if (FindStringInArray(muzzledSteamIDs,GetSteamID(client)) != -1)
	{
		return true;
	}
	return false;
}

char[] GetSteamID(int client)
{
	char steamID[STEAMID_LENGTH];
	if (GetClientAuthId(client, AuthId_Engine, steamID, sizeof(steamID)))
	{
		return steamID;
	}
	steamID = "notfound";
	return steamID;
}
 
char[] GetName(int client)
{
	char name[STEAMNAME_LENGTH];
	if (GetClientName(client, name, sizeof(name)))
	{
		return name;
	}
	name = "notfound";
	return name;
}

void MutePlayer(int client)
{
	if (!BaseComm_IsClientMuted(client))
	{
		BaseComm_SetClientMute(client, true);		
		char name[STEAMID_LENGTH];
		name = GetName(client);
		PrintToServer("Muzzled %s",name);
	}
}

void UnmutePlayer(int client)
{
	int arraySize = GetArraySize(muzzledSteamIDs);
	int index;
	if ((index = FindStringInArray(muzzledSteamIDs,GetSteamID(client))) != -1)
	{
		RemoveFromArray(muzzledSteamIDs,index);
		
		//adt_array cannot remove last element. Have to manually check for this and clear it.
		if(arraySize = 1)
		{
			ClearArray(muzzledSteamIDs);
		}
	}
	
	BaseComm_SetClientMute(client, false);		
	char name[STEAMID_LENGTH];
	name = GetName(client);
	PrintToServer("Unmuzzled %s",name);
}

void WriteConfigFile(char[] FilePath)
{
	new Handle:configFileHandle = OpenFile(FilePath,"w+")	
	
	int arraySize = GetArraySize(muzzledSteamIDs);
	for (int i = 0;i<arraySize;i++)
	{
		char steamID[STEAMID_LENGTH];
		muzzledSteamIDs.GetString(i,steamID,STEAMID_LENGTH);
		bool writeSuccess = WriteFileLine(configFileHandle, "%s", steamID)
		if (writeSuccess)
		{
			PrintToServer("Wrote out muzzled_players.txt");
		}
		else
		{
			PrintToServer("Unable to write muzzled_players.txt");
		}
	}	
	delete configFileHandle;
}

void ReadConfigFile(char[] FilePath)
{
	muzzledSteamIDs = new ArrayList(ByteCountToCells(STEAMID_LENGTH));
	if (FileExists(FilePath))
	{
		new Handle:configFileHandle = OpenFile(FilePath,"r");
		
		int i = 0;
		while(!IsEndOfFile(configFileHandle))
		{
			char steamID[STEAMID_LENGTH];
			ReadFileLine(configFileHandle,steamID,STEAMID_LENGTH);
			TrimString(steamID)
			muzzledSteamIDs.PushString(steamID);
			i++;
		}
		
		delete configFileHandle;
	}
	else
	{
		PrintToServer("Config file %s doesn't exist, didn't read any IDs", FilePath);
	}	
}

public void OnMapStart()
{
	ReadConfigFile(configFilePath);
}
