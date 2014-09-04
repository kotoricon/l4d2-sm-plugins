#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

#define IsPlayer(%0) (1<=%0<=MaxClients && IsClientInGame(%0))

public Plugin:myinfo = {
	name = "删除医疗品",
	author = "Kirisame",
	description = "删除所有地图内医疗品",
	version = PLUGIN_VERSION,
	url = "Undefined"
}

public OnPluginStart()
{
	HookEvent( "round_start", OnRoundStart);
	
	RemoveItem();
}

public RemoveItem()
{
	CreateTimer(2.0, KillItem, _, TIMER_REPEAT);
}

public Action:KillItem(Handle:timer)
{
	new index = -1;
	while ((index = FindEntityByClassname(index, "weapon_chainsaw")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	
	//remove spawn event
	while ((index = FindEntityByClassname(index, "weapon_chainsaw_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_adrenaline_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_defibrillator_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_first_aid_kit_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_pain_pills_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_molotov_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_pipe_bomb_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_vomitjar_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_upgradepack_explosive_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_upgradepack_incendiary_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	new index = -1;
	while ((index = FindEntityByClassname(index, "weapon_chainsaw_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_chainsaw")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_adrenaline")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_defibrillator")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_first_aid_kit")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_pain_pills")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_molotov")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_pipe_bomb")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_vomitjar")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_upgradepack_explosive")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_upgradepack_incendiary")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	
	//remove spawn event
	while ((index = FindEntityByClassname(index, "weapon_chainsaw_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_adrenaline_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_defibrillator_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_first_aid_kit_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_pain_pills_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_molotov_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_pipe_bomb_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_vomitjar_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_upgradepack_explosive_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_upgradepack_incendiary_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
}

stock DoubleCommand(client, String:command[], String:arguments[]="")
{
	new userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}