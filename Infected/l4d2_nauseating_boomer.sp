#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define L4D2 Nauseating Boomer
#define PLUGIN_VERSION "1.11"

#define STRING_LENGHT								56
#define ZOMBIECLASS_BOOMER 							2

static const String:GAMEDATA_FILENAME[]				= "l4d2addresses";
static const String:VELOCITY_ENTPROP[]				= "m_vecVelocity";
static const Float:SLAP_VERTICAL_MULTIPLIER			= 1.5;

new Handle:cvarBileBlast;
new Handle:cvarBileBlastInnerPower;
new Handle:cvarBileBlastOuterPower;
new Handle:cvarBileBlastInnerDamage;
new Handle:cvarBileBlastOuterDamage;
new Handle:cvarBileBlastInnerRange;
new Handle:cvarBileBlastOuterRange;
new rangeBileBlast[MAXPLAYERS+1];

new Handle:cvarBileFeet;
new Handle:cvarBileFeetSpeed;
new Handle:cvarBileFeetTimer[MAXPLAYERS+1] = INVALID_HANDLE;

new Handle:cvarBilePimple;
new Handle:cvarBilePimpleChance;
new Handle:cvarBilePimpleDamage;
new Handle:cvarBilePimpleRange;
new Handle:cvarBilePimpleTimer[MAXPLAYERS+1] = INVALID_HANDLE;

new Handle:cvarBileThrow;
new Handle:cvarBileThrowCooldown;
new Handle:cvarBileThrowDamage;
new Handle:cvarBileThrowRange;

new Handle:cvarBileBelly;
new Handle:cvarBileBellyAmount;

new Handle:PluginStartTimer = INVALID_HANDLE;
static Handle:sdkCallVomitOnPlayer = 	INVALID_HANDLE;
static Handle:sdkCallFling			 = 	INVALID_HANDLE;

new bool:isBileBlast = false;
new bool:isBilePimple = false;
new bool:isBileBelly = false;
new bool:isBileThrow = false;
new bool:isBileFeet = false;

new Float:cooldownBileThrow[MAXPLAYERS+1] = 0.0;
static laggedMovementOffset = 0;

public Plugin:myinfo = 
{
    name = "[L4D2] Nauseating Boomer",
    author = "Mortiegama",
    description = "Allows for unique Boomer abilities to spread its nauseating bile.",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?p=2094483#post2094483"
}

	//Special Thanks:
	//AtomicStryker - Boomer Bit** Slap:
	//https://forums.alliedmods.net/showthread.php?t=97952
	
public OnPluginStart()
{
	CreateConVar("l4d_nbm_version", PLUGIN_VERSION, "Nauseating Boomer Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	cvarBileBlast = CreateConVar("l4d_nbm_bileblast", "1", "Enables the ability for the Smoker to create a Methane Blast upon its death, damaging survivors and sending them flying. (Def 1)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileBlastInnerPower = CreateConVar("l4d_nbm_bileblastinnerpower", "150.0", "Power behind the inner range of Methane Blast. (Def 200.0)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileBlastOuterPower = CreateConVar("l4d_nbm_bileblastouterpower", "100.0", "Power behind the outer range of Methane Blast. (Def 100.0)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileBlastInnerDamage = CreateConVar("l4d_nbm_bileblastinnerdamage", "15", "Amount of damage caused in the inner range of Methane Blast. (Def 15)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileBlastOuterDamage = CreateConVar("l4d_nbm_bileblastouterdamage", "5", "Amount of damage caused in the outer range of Methane Blast. (Def 5)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileBlastInnerRange = CreateConVar("l4d_nbm_bileblastinnerrange", "150.0", "Range the inner blast radius will extend from Methane Blast. (Def 200.0)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileBlastOuterRange = CreateConVar("l4d_nbm_bileblastouterrange", "200.0", "Range the outer blast radius will extend from Methane Blast. (Def 300.0)", FCVAR_PLUGIN, true, 0.0, false, _);
	
	cvarBileBelly = CreateConVar("l4d_nbm_bilebelly", "1", "The Boomer's belly becomes so overfilled with bile that it reduces damage taken. (Def 1)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileBellyAmount = CreateConVar("l4d_nbm_bilebellyamount", "0.5", "Percent of damage the Boomer avoids thanks to it's belly. (Def 0.5)", FCVAR_PLUGIN, true, 0.0, false, _);

	cvarBileFeet = CreateConVar("l4d_vts_bilefeet", "1", "Increases the movement speed of the Boomer. (Def 1)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileFeetSpeed = CreateConVar("l4d_vts_bilefeetspeed", "1.5", "How much does Bile Feet increase the Boomer movement speed. (Def 1.5)", FCVAR_PLUGIN, true, 0.0, false, _);

	cvarBilePimple = CreateConVar("l4d_nbm_bilepimple", "1", "Enables the ability for the Smoker to whip its tongue when broken, sending the breaker flying and damaging both survivors. (Def 1)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBilePimpleChance = CreateConVar("l4d_nbm_bilepimplechance", "5", "Chance that a Survivor will be hit with Bile from an exploding Pimple. (Def 5)(5 = 5%)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBilePimpleDamage = CreateConVar("l4d_nbm_bilepimpledamage", "10", "Amount of damage the Bile from an exploding Pimple will cause. (Def 10)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBilePimpleRange = CreateConVar("l4d_nbm_bilepimplerange", "500.0", "Distance Bile will reach from an Exploding Pimple. (Def 500.0)", FCVAR_PLUGIN, true, 0.0, false, _);

	cvarBileThrow = CreateConVar("l4d_nbm_bilethrow", "0", "Enables the ability for the Boomer to throw Bile at Survivors. (Def 1)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileThrowCooldown = CreateConVar("l4d_nbm_bilethrowcooldown", "8.0", "Amount of time between Bile throws. (Def 8.0)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileThrowDamage = CreateConVar("l4d_nbm_bilethrowdamage", "10", "Amount of damage the Bile Throw deals to Survivors that are hit. (Def 10)", FCVAR_PLUGIN, true, 0.0, false, _);
	cvarBileThrowRange = CreateConVar("l4d_nbm_bilethrowrange", "700", "Distance the Boomer is able to throw Bile. (Def 700)", FCVAR_PLUGIN, true, 0.0, false, _);

	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	//AutoExecConfig(true, "plugin.L4D2.NauseatingBoomer");
	PluginStartTimer = CreateTimer(3.0, OnPluginStart_Delayed);
	
	new Handle:ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
	laggedMovementOffset = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkCallVomitOnPlayer = EndPrepSDKCall();
	
	if (sdkCallVomitOnPlayer == INVALID_HANDLE)
	{
		SetFailState("Cant initialize OnVomitedUpon SDKCall");
		return;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallFling = EndPrepSDKCall();
	
	if (sdkCallFling == INVALID_HANDLE)
	{
		SetFailState("Cant initialize Fling SDKCall");
		return;
	}
	
	CloseHandle(ConfigFile);
}

public Action:OnPluginStart_Delayed(Handle:timer)
{	
	if (GetConVarInt(cvarBileBlast))
	{
		isBileBlast = true;
	}
	
	if (GetConVarInt(cvarBileFeet))
	{
		isBileFeet = true;
	}
	
	if (GetConVarInt(cvarBilePimple))
	{
		isBilePimple = true;
	}
	
	if (GetConVarInt(cvarBileBelly))
	{
		isBileBelly = true;
	}
	
	if (GetConVarInt(cvarBileThrow))
	{
		isBileThrow = true;
	}
	
	if(PluginStartTimer != INVALID_HANDLE)
	{
 		KillTimer(PluginStartTimer);
		PluginStartTimer = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}

public Event_PlayerSpawn (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event,"userid"));

	if (IsValidClient(client) && GetClientTeam(client) == 3)
	{
		new class = GetEntProp(client, Prop_Send, "m_zombieClass");
		if (class == ZOMBIECLASS_BOOMER)
		{
			if (isBilePimple)
			{
			cvarBilePimpleTimer[client] = CreateTimer(0.5, Timer_BilePimple, client, TIMER_REPEAT);
			}
			
			if (isBileFeet)
			{
				cvarBileFeetTimer[client] = CreateTimer(0.5, Event_BoomerBileFeet, client);
			}
		}
	}
}

public Action:Event_BoomerBileFeet(Handle:timer, any:client) 
{
	if (IsValidClient(client))
	{
		PrintHintText(client, "Bile Feet has granted you increased movement speed!");
		SetEntDataFloat(client, laggedMovementOffset, 1.0*GetConVarFloat(cvarBileFeetSpeed), true);
		SetConVarFloat(FindConVar("z_vomit_fatigue"),0.0,false,false);
	}
	
	if(cvarBileFeetTimer[client] != INVALID_HANDLE)
	{
 		KillTimer(cvarBileFeetTimer[client]);
		cvarBileFeetTimer[client] = INVALID_HANDLE;
	}
		
	return Plugin_Stop;	
}

public Action:Timer_BilePimple(Handle:timer, any:client)
{
	if (!IsValidClient(client) || GetClientTeam(client) != 3)
	{
		if (cvarBilePimpleTimer[client] != INVALID_HANDLE)
		{
			KillTimer(cvarBilePimpleTimer[client]);
			cvarBilePimpleTimer[client] = INVALID_HANDLE;
		}	
	
		return Plugin_Stop;
	}

	for (new victim=1; victim<=MaxClients; victim++)
	
	if (IsValidClient(victim) && IsValidClient(client) && GetClientTeam(victim) == 2)
	{
		new BilePimpleChance = GetRandomInt(0, 99);
		new BilePimplePercent = (GetConVarInt(cvarBilePimpleChance));
		
		if (BilePimpleChance < BilePimplePercent)
		{
			decl Float:v_pos[3];
			GetClientEyePosition(victim, v_pos);		
			decl Float:targetVector[3];
			decl Float:distance;
			new Float:range = GetConVarFloat(cvarBilePimpleRange);
			GetClientEyePosition(client, targetVector);
			distance = GetVectorDistance(targetVector, v_pos);
			//PrintToChatAll("Distance: %f Client: %n", distance, victim);
			
			if (distance <= range)
			{
				Damage_BilePimple(client, victim);
			}
		}
	}
	
	return Plugin_Continue;
}

public Event_PlayerHurt (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidClient(client) && GetClientTeam(client) == 3 && isBileBelly)
	{
		new class = GetEntProp(client, Prop_Send, "m_zombieClass");
		
		if (class == ZOMBIECLASS_BOOMER)
		{
			new damage = GetEventInt(event, "dmg_health");
			new hp = GetEntProp(client, Prop_Data, "m_iHealth");	
			new Float:multiplier = GetConVarFloat(cvarBileBellyAmount);
			new dmgadjust = RoundToZero(damage * multiplier);
			new dmgdiff = damage - dmgadjust;
			new dmgpoints = damage - dmgdiff;
			//PrintToChatAll("Damage: %i.", dmgpoints);
			
			if (damage < 1 || hp < 1) return; // exclude zero damage calculations
			
			new health = hp + dmgdiff;
			SetEntProp(client, Prop_Data, "m_iHealth", health);
			SetEventInt(event, "amount", dmgpoints);
		}
	}
}

public Event_PlayerDeath (Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (IsValidDeadClient(client))
	{
		new class = GetEntProp(client, Prop_Send, "m_zombieClass");
		
		if (class == ZOMBIECLASS_BOOMER && isBileBlast)
		{
			BileBlast(client);
			
			if (cvarBilePimpleTimer[client] != INVALID_HANDLE)
			{
				KillTimer(cvarBilePimpleTimer[client]);
				cvarBilePimpleTimer[client] = INVALID_HANDLE;
			}			
		}
	}
}

public BileBlast(client)
{
	for (new victim=1; victim<=MaxClients; victim++)
	{
		if (IsValidClient(victim) && GetClientTeam(victim) != 3)
		{
			decl Float:s_pos[3];
			GetClientEyePosition(client, s_pos);
			decl Float:targetVector[3];
			decl Float:distance;
			new Float:range1 = GetConVarFloat(cvarBileBlastInnerRange);
			new Float:range2 = GetConVarFloat(cvarBileBlastOuterRange);
			GetClientEyePosition(victim, targetVector);
			distance = GetVectorDistance(targetVector, s_pos);
			//PrintToChatAll("Distance: %f.", distance);
			
			if (distance < range1)
			{
				decl Float:HeadingVector[3], Float:AimVector[3];
				new Float:power = GetConVarFloat(cvarBileBlastInnerPower);
				
				GetClientEyeAngles(client, HeadingVector);
				AimVector[0] = FloatMul( Cosine( DegToRad(HeadingVector[1])  ) , power);
				AimVector[1] = FloatMul( Sine( DegToRad(HeadingVector[1])  ) , power);
				
				decl Float:current[3];
				GetEntPropVector(victim, Prop_Data, VELOCITY_ENTPROP, current);
				
				decl Float:resulting[3];
				resulting[0] = FloatAdd(current[0], AimVector[0]);	
				resulting[1] = FloatAdd(current[1], AimVector[1]);
				resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
				
				rangeBileBlast[victim] = 1;
				Radius_BileBlast(victim, resulting, client);
			}
				
			if (distance < range2 && distance > range1)
			{
				decl Float:HeadingVector[3], Float:AimVector[3];
				new Float:power = GetConVarFloat(cvarBileBlastOuterPower);
				
				GetClientEyeAngles(client, HeadingVector);
				AimVector[0] = FloatMul( Cosine( DegToRad(HeadingVector[1])  ) , power);
				AimVector[1] = FloatMul( Sine( DegToRad(HeadingVector[1])  ) , power);
				
				decl Float:current[3];
				GetEntPropVector(victim, Prop_Data, VELOCITY_ENTPROP, current);
				
				decl Float:resulting[3];
				resulting[0] = FloatAdd(current[0], AimVector[0]);	
				resulting[1] = FloatAdd(current[1], AimVector[1]);
				resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
				
				rangeBileBlast[victim] = 2;
				Radius_BileBlast(victim, resulting, client);
			}
			
			if (distance > range2)
			{
				rangeBileBlast[victim] = 0;
			}
		}
	}
}

stock Radius_BileBlast(target, Float:vector[3], attacker, Float:incaptime = 3.0)
{
	new Handle:MySDKCall = INVALID_HANDLE;
	new Handle:ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
	
	StartPrepSDKCall(SDKCall_Player);
	new bool:bFlingFuncLoaded = PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	if(!bFlingFuncLoaded)
	{
		LogError("Could not load the Fling signature");
	}
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);

	MySDKCall = EndPrepSDKCall();
	if(MySDKCall == INVALID_HANDLE)
	{
		LogError("Could not prep the Fling function");
	}
	
	SDKCall(MySDKCall, target, vector, 76, attacker, incaptime); //76 is the 'got bounced' animation in L4D2 // 96 95 98 80 81 back  82 84  jump 86 roll 87 88 91 92 jump 93 
	Damage_BileBlast(attacker, target);
}

public Action:Damage_BileBlast(client, victim)
{
	new damage = 0;
	if(rangeBileBlast[victim] == 1){damage = GetConVarInt(cvarBileBlastInnerDamage);}
	if(rangeBileBlast[victim] == 2){damage = GetConVarInt(cvarBileBlastOuterDamage);}
	decl Float:victimPos[3], String:strDamage[16], String:strDamageTarget[16];
			
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	
	new entPointHurt = CreateEntityByName("point_hurt");
	if(!entPointHurt) return;

	// Config, create point_hurt
	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
	DispatchSpawn(entPointHurt);
	
	// Teleport, activate point_hurt
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (client && client < MaxClients && IsClientInGame(client)) ? client : -1);
	
	// Config, delete point_hurt
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	RemoveEdict(entPointHurt);
}

public Action:Damage_BilePimple(client, victim)
{
	new damage = GetConVarInt(cvarBilePimpleDamage);
	decl Float:victimPos[3], String:strDamage[16], String:strDamageTarget[16];
			
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	
	new entPointHurt = CreateEntityByName("point_hurt");
	if(!entPointHurt) return;

	// Config, create point_hurt
	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
	DispatchSpawn(entPointHurt);
	
	// Teleport, activate point_hurt
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (client && client < MaxClients && IsClientInGame(client)) ? client : -1);
	
	// Config, delete point_hurt
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	RemoveEdict(entPointHurt);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(buttons & IN_ATTACK2 && IsValidClient(client) && GetClientTeam(client) == 3 && IsValidBoomer(client))
	{
		if (isBileThrow && IsBileThrowReady(client))
		{
			new Float:range = GetConVarFloat(cvarBileThrowRange);
			for (new victim=1; victim<=MaxClients; victim++)
			
			if (IsValidClient(victim) && GetClientTeam(victim) == 2 && ClientViews(client, victim, range))
			{
				decl Float:attackerPos[3];
				decl Float:victimPos[3];
				GetClientEyePosition(client, attackerPos);
				GetClientEyePosition(victim, victimPos);
				ShowParticle(attackerPos, "boomer_vomit", 3.0);	
				ShowParticle(victimPos, "boomer_vomit", 3.0);	
				SDKCall(sdkCallVomitOnPlayer, victim, client, true);
				cooldownBileThrow[client] = GetEngineTime();
				Damage_BileThrow(client, victim);
			}
		}
	}
}

public Action:Damage_BileThrow(client, victim)
{
	new damage = GetConVarInt(cvarBileThrowDamage);
	decl Float:victimPos[3], String:strDamage[16], String:strDamageTarget[16];
			
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	
	new entPointHurt = CreateEntityByName("point_hurt");
	if(!entPointHurt) return;

	// Config, create point_hurt
	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
	DispatchSpawn(entPointHurt);
	
	// Teleport, activate point_hurt
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (client && client < MaxClients && IsClientInGame(client)) ? client : -1);
	
	// Config, delete point_hurt
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	RemoveEdict(entPointHurt);
	
	PrintHintText(client, "Your Bile Throw inflicted %i damage.", damage);
	PrintHintText(victim, "You were hit with Bile Throw, causing %i damage.", damage);
}


// ----------------------------------------------------------------------------
// ClientViews()
// ----------------------------------------------------------------------------
stock bool:ClientViews(Viewer, Target, Float:fMaxDistance=0.0, Float:fThreshold=0.73)
{
	// Retrieve view and target eyes position
	decl Float:fViewPos[3];   GetClientEyePosition(Viewer, fViewPos);
	decl Float:fViewAng[3];   GetClientEyeAngles(Viewer, fViewAng);
	decl Float:fViewDir[3];
	decl Float:fTargetPos[3]; GetClientEyePosition(Target, fTargetPos);
	decl Float:fTargetDir[3];
	decl Float:fDistance[3];

	// Calculate view direction
	fViewAng[0] = fViewAng[2] = 0.0;
	GetAngleVectors(fViewAng, fViewDir, NULL_VECTOR, NULL_VECTOR);

	// Calculate distance to viewer to see if it can be seen.
	fDistance[0] = fTargetPos[0]-fViewPos[0];
	fDistance[1] = fTargetPos[1]-fViewPos[1];
	fDistance[2] = 0.0;
	new Float:fMinDistance = 100.0;
	
	if (fMaxDistance != 0.0)
	{
		if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) >= (fMaxDistance*fMaxDistance))
			return false;
	}
	
	if (((fDistance[0]*fDistance[0])+(fDistance[1]*fDistance[1])) < (fMinDistance*fMinDistance))
			return false;

	// Check dot product. If it's negative, that means the viewer is facing
	// backwards to the target.
	NormalizeVector(fDistance, fTargetDir);
	if (GetVectorDotProduct(fViewDir, fTargetDir) < fThreshold) return false;

	// Now check if there are no obstacles in between through raycasting
	new Handle:hTrace = TR_TraceRayFilterEx(fViewPos, fTargetPos, MASK_PLAYERSOLID_BRUSHONLY, RayType_EndPoint, ClientViewsFilter);
	if (TR_DidHit(hTrace)) { CloseHandle(hTrace); return false; }
	CloseHandle(hTrace);

	// Done, it's visible
	return true;
}

// ----------------------------------------------------------------------------
// ClientViewsFilter()
// ----------------------------------------------------------------------------
public bool:ClientViewsFilter(Entity, Mask, any:Junk)
{
	if (Entity >= 1 && Entity <= MaxClients) return false;
	return true;
} 

public ShowParticle(Float:victimPos[3], String:particlename[], Float:time)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, victimPos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
	} 
}
 
public PrecacheParticle(String:particlename[])
{
	new particle = CreateEntityByName("info_particle_system");
	
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:DeleteParticles(Handle:timer, any:particle)
{
	if (IsValidEntity(particle))
	{
		decl String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			AcceptEntityInput(particle, "stop");
			AcceptEntityInput(particle, "kill");
			RemoveEdict(particle);
		}
	}
}

public OnMapEnd()
{
    for (new client=1; client<=MaxClients; client++)
	{
	if (IsValidClient(client))
		{
			rangeBileBlast[client] = 0;
		}
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

public IsValidBoomer(client)
{
	new class = GetEntProp(client, Prop_Send, "m_zombieClass");
	
	if (class == ZOMBIECLASS_BOOMER)
		return true;
	
	return false;
}

public IsBileThrowReady(client)
{
	return ((GetEngineTime() - cooldownBileThrow[client]) > GetConVarFloat(cvarBileThrowCooldown));
}