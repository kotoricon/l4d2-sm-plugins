#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

#define L4D2 Spitter Supergirl
#define PLUGIN_VERSION "1.4"

#define ZOMBIECLASS_SPITTER 4

new bool:isAcidicSlobber;
new bool:isHydraStrike;
new bool:isSupergirl = false;
new bool:isSupergirlSpeed = false;
new bool:isHydraStrikeActive[MAXPLAYERS+1] = false;

new Handle:cvarHydraStrike;
new Handle:cvarHydraStrikeCooldown;
new Handle:cvarHydraStrikeTimer[MAXPLAYERS+1] = INVALID_HANDLE;

new Handle:cvarSupergirl;
new Handle:cvarSupergirlSpeed;
new Handle:cvarSupergirlDuration;
new Handle:cvarSupergirlSpeedDuration;
new Handle:cvarSupergirlTimer[MAXPLAYERS +1];
new Handle:cvarSupergirlSpeedTimer[MAXPLAYERS +1];

new Handle:PluginStartTimer = INVALID_HANDLE;

static laggedMovementOffset = 0;

public Plugin:myinfo = 
{
    name = "[L4D2] Spitter Supergirl",
    author = "Mortiegama",
    description = "Allows temporary invulnerability for Spitter after spitting.",
    version = PLUGIN_VERSION,
    url = ""
}

public OnPluginStart()
{
	CreateConVar("l4d_ssg_version", PLUGIN_VERSION, "Spitter Supergirl Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	cvarHydraStrike = CreateConVar("l4d_ssg_hydrastrike", "1", "Enables the ability for the Spitter to fire off a second shot at a decreased cooldown. (Def 10)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarHydraStrikeCooldown = CreateConVar("l4d_ssg_hydrastrikecooldown", "0.1", "Recharge time before the Hydra Strike allows another spit. (Def 0.1)", FCVAR_PLUGIN, true, 0.1, false, _);

	cvarSupergirl = CreateConVar("l4d_ssg_supergirl", "1", "Temporary invulnerability after Spitter spits. (Def 1)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarSupergirlSpeed = CreateConVar("l4d_ssg_supergirlspeed", "0", "Removes speed loss after Spitter spits. (Def 1)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarSupergirlDuration = CreateConVar("l4d_ssg_supergirlduration", "2", "How long the Spitter is invulnerable. (Def 4)", FCVAR_PLUGIN, true, 1.0, false, _);
	cvarSupergirlSpeedDuration = CreateConVar("l4d_ssg_supergirlspeedduration", "2", "How long the Spitter is invulnerable. (Def 4)", FCVAR_PLUGIN, true, 1.0, false, _);
	
	HookEvent("spit_burst", Event_SpitBurst);
	
	laggedMovementOffset = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");
	
	//AutoExecConfig(true, "plugin.L4D2.Supergirl");
	PluginStartTimer = CreateTimer(3.0, OnPluginStart_Delayed);
}

public Action:OnPluginStart_Delayed(Handle:timer)
{
	if (GetConVarInt(cvarHydraStrike))
	{
		isHydraStrike = true;
	}
	
	if (GetConVarInt(cvarSupergirl))
	{
		isSupergirl = true;
	}
	
	if (GetConVarInt(cvarSupergirlSpeed))
	{
		isSupergirlSpeed = true;
	}
	
	if(PluginStartTimer != INVALID_HANDLE)
	{
 		KillTimer(PluginStartTimer);
		PluginStartTimer = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}

//Spitter: Supergirl
public Event_SpitBurst (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));
		
	if (isHydraStrike)
	{
		cvarHydraStrikeTimer[client] = CreateTimer(0.6, Timer_HydraStrike, client);
	}
	
	if (isSupergirl && IsValidClient(client))
	{
		PrintHintText(client, "You are temporarily invulnerable!");
		cvarSupergirlTimer[client] = CreateTimer(GetConVarFloat(cvarSupergirlDuration), Supergirl, client);	
		SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	}
	
	if (isSupergirlSpeed && IsValidClient(client))
	{
		cvarSupergirlSpeedTimer[client] = CreateTimer(GetConVarFloat(cvarSupergirlSpeedDuration), SupergirlSpeed, client);	
		SetEntDataFloat(client, laggedMovementOffset, 1.7, true);
	}
}

public Action:Timer_HydraStrike(Handle:timer, any:client)
{
	if (IsValidClient(client))
	{
		CallResetAbility(client);
	}
		
	if (cvarHydraStrikeTimer[client] != INVALID_HANDLE)
	{
		KillTimer(cvarHydraStrikeTimer[client]);
		cvarHydraStrikeTimer[client] = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}

public Action:Supergirl(Handle:timer, any:client)
{
	if (IsValidClient(client))
	{
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		PrintHintText(client, "You are no longer invulnerable!");
	}
		
	if (cvarSupergirlTimer[client] != INVALID_HANDLE)
	{
		KillTimer(cvarSupergirlTimer[client]);
		cvarSupergirlTimer[client] = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}

public Action:SupergirlSpeed(Handle:timer, any:client)
{
	if (IsValidClient(client))
	{
		SetEntDataFloat(client, laggedMovementOffset, 1.0, true);
	}
	
	if (cvarSupergirlSpeedTimer[client] != INVALID_HANDLE)
	{
		KillTimer(cvarSupergirlSpeedTimer[client]);
		cvarSupergirlSpeedTimer[client] = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}

CallResetAbility(client)
{
	if (!isHydraStrikeActive[client])
	{
		new ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
		new Float:cooldown = GetConVarFloat(cvarHydraStrikeCooldown);

		if (ability > 0)
		{
			SetEntPropFloat(ability, Prop_Send, "m_duration", cooldown);
			SetEntPropFloat(ability, Prop_Send, "m_timestamp", GetGameTime() + cooldown);
		}
		
		isHydraStrikeActive[client] = true;
	}
	
	else
	{
		isHydraStrikeActive[client] = false;
	}
}

public IsValidClient(client)
{
	if (client <= 0)
		return false;
		
	if (client > MaxClients)
		return false;
		
	if (!IsClientInGame(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	return true;
}

public IsValidDeadClient(client)
{
	if (client <= 0)
		return false;
		
	if (client > MaxClients)
		return false;
		
	if (!IsClientInGame(client))
		return false;
		
	if (IsPlayerAlive(client))
		return false;

	return true;
}