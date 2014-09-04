#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

// Plugin definitions
public Plugin:myinfo = 
{
	name = "[L4D2] 记录器",
	author = "Kirisame",
	description = "屏蔽命令/玩家记录器",
	version = PLUGIN_VERSION,
	url = "undefined"
};

public OnPluginStart(){
	
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say2", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
}

stock GetInGamePlayerCount()
{
	new count = 0;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && (GetClientTeam(i) == 2) && !IsFakeClient(i))
			count++;
	}
	return count;
}

public Action:Command_Say(client,args)
{
	decl String:szText[192];
	GetCmdArgString(szText, sizeof(szText));
	StripQuotes(szText);
	
	if(szText[0] == '/' || szText[0] == '!')
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
