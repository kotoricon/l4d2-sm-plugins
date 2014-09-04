#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0"
#pragma semicolon 1

new Handle:g_hHard_hpmult;

static g_iCvarHealth;

new Float:g_flHard_hpmult;

public Plugin:myinfo = 
{
	name = "[L4D2]特殊配置器",
	author = "Kirisame",
	description = "修改一些特殊配置",
	version = PLUGIN_VERSION,
	url = "undefined"
};

public OnPluginStart()
{
	HookEvent("player_incapacitated", Event_Incap);
	HookEvent("tank_spawn", tank_spawn);
	HookEvent("tank_frustrated", Event_TankDeath);
	g_hHard_hpmult = CreateConVar("l4d_incap_healthmultiplier" , "5.0" , "修改倒地时的生命值倍数 (值必须在 0.01 到 200倍之间)" , FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY );
	HookConVarChange(g_hHard_hpmult, Convar_Hard);
	g_flHard_hpmult = GetConVarFloat(g_hHard_hpmult);
	
	RegAdminCmd("sm_stats", Endless_Push, ADMFLAG_ROOT);

	AutoExecConfig(true, "l4d_special_setup");
}

public OnClientDisconnect(client)
{
	if(GetInGamePlayerCount() < 1)
	{
		ServerCommand("exec server");
	}
}

public OnConfigsExecuted()
{
	new Handle:temp = FindConVar("z_tank_health");
	if( temp == INVALID_HANDLE) SetFailState("Tank Health & Burning Time Handle == -1, plugin failed");
	g_iCvarHealth = GetConVarInt(temp);
}

public tank_spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	CreateTimer(0.1, tmrHealth, userid);
}

public Action:tmrHealth(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	new extra = 625 * GetInGamePlayerCount();
	new extime = 20 * GetInGamePlayerCount();
	
	decl String:CurrentDifficulty[64];
	GetConVarString(FindConVar("z_difficulty"), CurrentDifficulty, sizeof(CurrentDifficulty));
	if(StrEqual(CurrentDifficulty, "Easy", false))
	{
		if(client && IsClientInGame(client) && GetClientHealth(client) > g_iCvarHealth)
		{
			SetEntityHealth(client, (g_iCvarHealth + extra * 4));
			ServerCommand("sm_cvar tank_burn_duration %d", (extime + 200));
		}
	}
	if(StrEqual(CurrentDifficulty, "Normal", false))
	{
		if(client && IsClientInGame(client) && GetClientHealth(client) > g_iCvarHealth)
		{
			SetEntityHealth(client, (g_iCvarHealth + extra * 3));
			ServerCommand("sm_cvar tank_burn_duration %d", (extime + 250));
		}
	}
	if(StrEqual(CurrentDifficulty, "Hard", false))
	{
		if(client && IsClientInGame(client) && GetClientHealth(client) > g_iCvarHealth)
		{
			SetEntityHealth(client, (g_iCvarHealth + extra * 2));
			ServerCommand("sm_cvar tank_burn_duration_hard %d", (extime * 1.5 + 280));
		}
	}
}

public Event_TankDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	ServerCommand("a4d_force_panic");
}

public Action:Endless_Push(client,args)
{
	DoubleCommand(client, "z_gun_swing_vs_cooldown", "0.01");
	return Plugin_Handled;
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

//no dead
public Convar_Hard (Handle:convar, const String:oldValue[], const String:newValue[])
{
	new Float:flF=StringToFloat(newValue);
	if (flF<0.01)
		flF=0.01;
	else if (flF>999.0)
		flF=999.0;
	g_flHard_hpmult = flF;
}

public Event_Incap (Handle:event, const String:name[], bool:dontBroadcast)
{
	new String:gmode[32];
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));
	
	if(StrEqual(gmode, "coop") || StrEqual(gmode, "survival"))
	{
		new iCid=GetClientOfUserId(GetEventInt(event,"userid"));
		HardToKill_OnIncap(iCid);
	}
}

HardToKill_OnIncap (iCid)
{
	if (GetClientTeam(iCid)!=2)
		return;

	CreateTimer(0.5,HardToKill_Delayed,iCid);
}

public Action:HardToKill_Delayed (Handle:timer, any:iCid)
{
	if (IsValidEntity(iCid)==true
		&& IsClientInGame(iCid)==true
		&& GetClientTeam(iCid)==2)
	{
		new AdminId:id = GetUserAdmin(iCid);
		if(id == INVALID_ADMIN_ID || !GetAdminFlag(id, Admin_Root))
		{
			if(!IsFakeClient(iCid))
			{
				return Plugin_Handled;
			}
		}
		else
		{
			new iHP=GetEntProp(iCid,Prop_Data,"m_iHealth");

			SetEntProp(iCid,Prop_Data,"m_iHealth", iHP + RoundToNearest(iHP*g_flHard_hpmult) );

			iHP = RoundToNearest( 300*(g_flHard_hpmult+1) );
			if (GetEntProp(iCid,Prop_Data,"m_iHealth") > iHP)
				SetEntProp(iCid,Prop_Data,"m_iHealth", iHP);
		}
	}

	KillTimer(timer);
	return Plugin_Stop;
}