#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"
//#define BANNED_LOG_PATH	"configs\\kick_names.ini"

//static String:logfilepath[256];

// Plugin definitions
public Plugin:myinfo = 
{
	name = "[L4D2]禁用服务器",
	author = "Kirisame",
	description = "让一个服务器停止工作",
	version = PLUGIN_VERSION,
	url = "undefined"
};

public OnPluginStart() 
{
    AddTempEntHook("Player Decal", PlayerSpray);
}

public Action:PlayerSpray(const String:szTempEntName[], const arrClients[], iClientCount, Float:flDelay) 
{
    new client = TE_ReadNum("m_nPlayer");
	
	new String:sAuthString[32];
	GetClientName(client, sAuthString, sizeof(sAuthString));
	
    if(IsValidClient(client)) 
    {
        PrintToChatAll("\x03%N\x01 使用了喷漆", client);
    }
}

public bool:IsValidClient(client) 
{
    if(client <= 0)
        return false;
    if(client > MaxClients)
        return false;

    return IsClientInGame(client);
}