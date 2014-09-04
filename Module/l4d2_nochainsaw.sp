#include <sourcemod>
#include <sdktools>
#pragma semicolon 1
#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY

#define PLUGIN_VERSION "1.0"


public Plugin:myinfo = 
{
	name = "禁用电锯",
	author = "Kirisame",
	description = "使用电锯一律踢出服务器",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
}

public OnPluginStart()
{
	HookEvent("weapon_fire", Event_PlayerFire);
}

public Action:Event_PlayerFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	decl String:weapon[25];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	if(StrEqual(weapon, "chainsaw"))
	{
		KickClient(client, "禁止使用电锯造成服务器崩溃, 谢谢合作");
	}
}