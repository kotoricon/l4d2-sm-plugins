#include <sdktools>

#pragma semicolon			1

#define PLUGIN_VERSION		"1.0"
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define MAX_DOORS			4

new stuckWarnings[MAXPLAYERS];
new maxWarningTime = 10;

static	Handle:g_hCvarAllow, Handle:g_hCvarModes, bool:g_bCvarAllow,
		Handle:g_hMPGameMode, g_iAccessCount, bool:g_iLateLoad, g_iRoundStart, g_iPlayerSpawn,
		g_iSafeDoor;


public Plugin:myinfo =
{
	name = "[L4D & L4D2] Safe Door Once Open",
	author = "SilverShot",
	description = "Only allows the saferoom door to be opened once for all gamemodes, the same way it's handled in Versus.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t="
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
	g_iLateLoad = late;

public OnPluginStart()
{
	g_hCvarAllow = CreateConVar(	"l4d_safe_once_allow",		"1",			"0=Plugin off, 1=Plugin on.",													CVAR_FLAGS);
	g_hCvarModes = CreateConVar(	"l4d_safe_once_modes",		"",				"Which game modes to enable the plugin.",										CVAR_FLAGS);
	CreateConVar(					"l4d_safe_once_version",	PLUGIN_VERSION,	"Saferoom Key plugin version",	CVAR_FLAGS|FCVAR_REPLICATED|FCVAR_DONTRECORD);

	g_hMPGameMode = FindConVar("mp_gamemode");
	HookConVarChange(g_hMPGameMode,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarAllow,		ConVarChanged_Allow);
	HookConVarChange(g_hCvarModes,		ConVarChanged_Allow);

	if( g_iLateLoad )
	{
		IsAllowed();
	}
}



// ====================================================================================================
//					C V A R S
// ====================================================================================================
public OnConfigsExecuted()
{
	IsAllowed();
}

public ConVarChanged_Allow(Handle:convar, const String:oldValue[], const String:newValue[])
{
	IsAllowed();
}

IsAllowed()
{
	new bool:bAllow = GetConVarBool(g_hCvarAllow);
	new bool:bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		InitPlugin();
		HookEvents(true);
	}
	else if( g_bCvarAllow == true && (bAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		HookEvents(false);
	}
}

bool:IsAllowedGameMode()
{
	if( g_hMPGameMode == INVALID_HANDLE )
		return false;

	// Get game mode cvars, if empty allow.
	decl String:sGameMode[32], String:sGameModes[64];
	GetConVarString(g_hCvarModes, sGameModes, sizeof(sGameModes));
	if( strlen(sGameModes) == 0 )
		return true;

	// Better game mode check: ",versus," instead of "versus", which would return true for "teamversus" for example.
	GetConVarString(g_hMPGameMode, sGameMode, sizeof(sGameMode));
	Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);
	return (StrContains(sGameModes, sGameMode, false) != -1);
}

HookEvents(bool:hook)
{
	if( hook )
	{
		HookEvent("round_end",						Event_RoundEnd,		EventHookMode_PostNoCopy);
		HookEvent("round_start",					Event_RoundStart,	EventHookMode_PostNoCopy);
		HookEvent("player_spawn",					Event_PlayerSpawn);
		HookEvent("player_use",						Event_PlayerUse,	EventHookMode_Pre);
	}
	else
	{
		UnhookEvent("round_end",					Event_RoundEnd,		EventHookMode_PostNoCopy);
		UnhookEvent("round_start",					Event_RoundStart,	EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn",					Event_PlayerSpawn);
		UnhookEvent("player_use",					Event_PlayerUse,	EventHookMode_Pre);
	}
}



public OnMapEnd()
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iRoundStart == 0 && g_iPlayerSpawn == 1 )
		InitPlugin();
	g_iRoundStart = 1;
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_iRoundStart = 0;
	g_iPlayerSpawn = 0;
}


InitPlugin()
{
	if( g_bCvarAllow )
	{
		g_iSafeDoor = 0;
		g_iAccessCount = 1;

		new ent = -1;
		while( (ent = FindEntityByClassname(ent, "prop_door_rotating_checkpoint")) != -1 )
		{
			if( g_iSafeDoor == 0 && GetEntProp(ent, Prop_Send, "m_bLocked") == 1 && GetEntProp(ent, Prop_Send, "m_eDoorState") == 0 )
			{
				g_iSafeDoor = EntIndexToEntRef(ent);

				SetVariantString("OnOpen !self:Lock::0.0:-1");
				AcceptEntityInput(ent, "AddOutput");
			}
		}
	}
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( g_iRoundStart == 1 && g_iPlayerSpawn == 0 )
		InitPlugin();
	g_iPlayerSpawn = 1;
}

public Action:Event_PlayerUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	if( !g_iAccessCount )
		return;

	new entity = GetEventInt(event, "targetid");
	new entref = EntIndexToEntRef(entity);

	if( g_iSafeDoor == entref )
	{
		AcceptEntityInput(entity, "Open");
		AcceptEntityInput(entity, "Lock");
		SetEntProp(entity, Prop_Send, "m_bLocked", 1);
		SetEntProp(entity, Prop_Send, "m_eDoorState", 0);
		g_iSafeDoor = 0;
	}
}