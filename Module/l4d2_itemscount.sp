//sdk tools
#include <sourcemod>
#include <sdktools>

//plugin version
#define PLUGIN_VERSION "1.0 beta"

//plugin info
public Plugin:myinfo = 
{
	name		= "提升物品拿取次数",
	author		= "Kirisame",
	description	= "增加物品的可拿取次数为一定倍",
	version		= PLUGIN_VERSION,
	url			= "Undefined"
}

public OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart);
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    CreateTimer(3.0, UpdateCounts);
}

public Action:UpdateCounts(Handle:timer)
{
    UpdateEntCount("weapon_first_aid_kit_spawn", "4");
	UpdateEntCount("weapon_spawn", "4");
} 

public UpdateEntCount(const String:entname[], const String:count[])
{
    new edict_index = -1;
    
    while( (edict_index = FindEntityByClassname(edict_index, entname)) != -1 )
        DispatchKeyValue(edict_index, "count", count);
}