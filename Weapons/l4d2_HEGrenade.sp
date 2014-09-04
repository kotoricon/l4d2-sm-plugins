#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0"
#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define MOLOTOV 0
#define EXPLODE 1

new ChargeLock[65];
new ReleaseLock[65];
new CurrentWeapon;
new ClipSize;
new ChargeEndTime[65];
new Handle:ClientTimer[65];
new g_sprite;
new Float:myPos[3], Float:trsPos[3], Float:trsPos002[3];

/* Sound */
#define CHARGESOUND 	"ambient/spacial_loops/lights_flicker.wav"
#define CHARGEDUPSOUND	"level/startwam.wav"
#define AWPSHOT			"weapons/awp/gunfire/awp1.wav"
#define EXPLOSIONSOUND	"animation/bombing_run_01.wav"

/* Sprite */
#define SPRITE_BEAM		"materials/sprites/laserbeam.vmt"

new Handle:l4d2_nuclearmissile		= INVALID_HANDLE;
new Handle:l4d2_nuclearmissiledamage		= INVALID_HANDLE;
new Handle:l4d2_nuclearforce			= INVALID_HANDLE;
new Handle:l4d2_chargetime		= INVALID_HANDLE;
new Handle:l4d2_shootonce		= INVALID_HANDLE;
new Handle:l4d2_check				= INVALID_HANDLE;
new Handle:l4d2_grenadelauncher			= INVALID_HANDLE;
new Handle:l4d2_flash			= INVALID_HANDLE;
new Handle:l4d2_chargingsound	= INVALID_HANDLE;
new Handle:l4d2_chargedsound		= INVALID_HANDLE;
new Handle:l4d2_moveandcharge	= INVALID_HANDLE;
new Handle:l4d2_chargeparticle	= INVALID_HANDLE;
new Handle:l4d2_useammocount			= INVALID_HANDLE;
new Handle:l4d2_shake			= INVALID_HANDLE;
new Handle:l4d2_nm_shake_intensity	= INVALID_HANDLE;
new Handle:l4d2_nm_shake_shooteronly= INVALID_HANDLE;
new Handle:l4d2_laseroffset		= INVALID_HANDLE;

new Handle:w_pushforce_mode ;
new Handle:w_pushforce_vlimit ;
new Handle:w_pushforce_factor ;
new Handle:w_pushforce_tankfactor ;
new Handle:w_pushforce_survivorfactor ;

public Plugin:myinfo = 
{
	name = "聚合型高爆弹发射器",
	author = "Kirisame",
	description = "使用蓄力发射更高伤害的榴弹",
	version = PLUGIN_VERSION,
	url = "Undefined"
}

public OnPluginStart()
{
	// ConVars
	l4d2_nuclearmissile	= CreateConVar("l4d2_lw_lethalweapon","1", "开启聚合型高爆弹发射器 (0:OFF 1:ON 2:SIMPLE)", CVAR_FLAGS);
	l4d2_nuclearmissiledamage	= CreateConVar("l4d2_lw_lethaldamage","1500.0", "聚合型高爆弹发射器基本伤害", CVAR_FLAGS);
	l4d2_nuclearforce			= CreateConVar("l4d2_lw_lethalforce","1000.0", "聚合型高爆弹击飞力量", CVAR_FLAGS);
	l4d2_chargetime		= CreateConVar("l4d2_chargetime","10", "聚合型高爆弹装填时间", CVAR_FLAGS);
	l4d2_shootonce		= CreateConVar("l4d2_shootonce","0", "每关只能使用一次", CVAR_FLAGS);
	l4d2_check				= CreateConVar("l4d2_check","0", "可以对其他生还者造成伤害", CVAR_FLAGS);
	l4d2_grenadelauncher		= CreateConVar("l4d2_lw_scout","1", "开启榴弹发射器发射聚合型高爆弹", CVAR_FLAGS);
	l4d2_laseroffset		= CreateConVar("l4d2_laseroffset", "36", "坐标修正", FCVAR_NOTIFY);

	w_pushforce_mode = CreateConVar("l4d_weapon_pushforce_mode", "0", "pushforce mode 0:disable, 1:mode one, 2:mode two, 3: both", FCVAR_PLUGIN);
	w_pushforce_vlimit = CreateConVar("l4d_weapon_pushforce_vlimit", "200", "voilicity limit", FCVAR_PLUGIN);
	w_pushforce_factor = CreateConVar("l4d_weapon_pushforce_factor", "0.8", "pushforce factor", FCVAR_PLUGIN);
	w_pushforce_tankfactor = CreateConVar("l4d_weapon_pushforce_tankfactor", "0.15", "pushforce factor for Tank", FCVAR_PLUGIN);
	w_pushforce_survivorfactor = CreateConVar("l4d_weapon_pushforce_survivorfactor", "0.4", "pushforce factor for Survivors", FCVAR_PLUGIN);
	
	// Additional ConVars
	l4d2_flash				= CreateConVar("l4d2_flash", "1", "开启屏幕晃动");
	l4d2_chargingsound		= CreateConVar("l4d2_chargingsound", "1", "开启装填声音");
	l4d2_chargedsound		= CreateConVar("l4d2_chargedsound", "1", "开启准备完毕声音");
	l4d2_moveandcharge		= CreateConVar("l4d2_moveandcharge", "1", "开启移动装填");
	l4d2_chargeparticle		= CreateConVar("l4d2_chargeparticle", "1", "是否显示装填状态");
	l4d2_useammocount				= CreateConVar("l4d2_useammocount", "1", "开启使用额外弹药");
	l4d2_shake				= CreateConVar("l4d2_shake", "1", "爆炸时进行屏幕晃动");
	l4d2_nm_shake_intensity		= CreateConVar("l4d2_nm_shake_intensity", "50.0", "屏幕晃动比率");
	l4d2_nm_shake_shooteronly	= CreateConVar("l4d2_nm_shake_shooteronly", "1", "是否只有发射者感觉到晃动");
	
	// Hooks
	HookEvent("player_spawn", Event_Player_Spawn);
	HookEvent("weapon_fire", Event_Weapon_Fire);
	HookEvent("bullet_impact", Event_Bullet_Impact);
	HookEvent("player_incapacitated", Event_Player_Incap, EventHookMode_Pre);
	HookEvent("player_hurt", Event_Player_Hurt, EventHookMode_Pre);
	HookEvent("player_death", Event_Player_Hurt, EventHookMode_Pre);
	HookEvent("infected_death", Event_Infected_Hurt, EventHookMode_Pre);
	HookEvent("infected_hurt", Event_Infected_Hurt, EventHookMode_Pre);
	HookEvent("round_end", Event_Round_End, EventHookMode_Pre);
	
	// Weapon stuff
	CurrentWeapon	= FindSendPropOffs ("CTerrorPlayer", "m_hActiveWeapon");
	ClipSize	= FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
	
	InitCharge();
	
	//AutoExecConfig(true, "l4d2_HEGrenade");
}

public OnMapStart()
{
	InitPrecache();
}

public OnConfigsExecuted()
{
	InitPrecache();
}

InitCharge()
{
	/* Initalize charge parameter */
	new i;
	for (i = 1; i <= GetMaxClients(); i++)
	{
		ChargeEndTime[i] = 0;
		ReleaseLock[i] = 0;
		ChargeLock[i] = 0;
		ClientTimer[i] = INVALID_HANDLE;
	}
	for (i = 1; i <= GetMaxClients(); i++)
	{
		if (IsValidEntity(i) && IsClientInGame(i))
		{
			if (GetClientTeam(i) == 2)
				ClientTimer[i] = CreateTimer(0.5, ChargeTimer, i, TIMER_REPEAT);
		}
	}
}

InitPrecache()
{
	/* Precache models */
	PrecacheModel("models/props_junk/propanecanister001a.mdl", true);
	PrecacheModel("models/props_junk/gascan001a.mdl", true);
	
	/* Precache sounds */
	PrecacheSound(CHARGESOUND, true);
	PrecacheSound(CHARGEDUPSOUND, true);
	PrecacheSound(AWPSHOT, true);
	PrecacheSound(EXPLOSIONSOUND, true);
	
	/* Precache particles */
	PrecacheParticle("gas_explosion_main");
	PrecacheParticle("electrical_arc_01_cp0");
	PrecacheParticle("electrical_arc_01_system");
	
	g_sprite = PrecacheModel(SPRITE_BEAM);
}

public Action:Event_Round_End(Handle:event, String:event_name[], bool:dontBroadcast)
{
	/* Timer end */
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (ClientTimer[i] != INVALID_HANDLE)
		{
			CloseHandle(ClientTimer[i]);
			ClientTimer[i] = INVALID_HANDLE;
		}
		if (IsValidEntity(i) && IsClientInGame(i))
		{
			ChargeEndTime[i] = 0;
			ReleaseLock[i] = 0;
			ChargeLock[i] = 0;
		}
	}
}

public Action:Event_Player_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Timer start */
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client > 0 && client <= GetMaxClients())
	{
		if (IsValidEntity(client) && IsClientInGame(client))
		{
			if (GetClientTeam(client) == 2)
			{
				if (ClientTimer[client] != INVALID_HANDLE)
					CloseHandle(ClientTimer[client]);
				ChargeLock[client] = 0;
				ClientTimer[client] = CreateTimer(0.5, ChargeTimer, client, TIMER_REPEAT);
			}
		}
	}
}

public Action:Event_Player_Incap(Handle:event, const String:name[], bool:dontBroadcast)
{
	/* Reset client condition */
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ReleaseLock[client] = 0;
	ChargeEndTime[client] = RoundToCeil(GetGameTime()) + GetConVarInt(l4d2_chargetime);
}

public Action:Event_Bullet_Impact(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (ReleaseLock[client])
	{
		decl Float:TargetPosition[3];
		
		TargetPosition[0] = GetEventFloat(event,"x");
		TargetPosition[1] = GetEventFloat(event,"y");
		TargetPosition[2] = GetEventFloat(event,"z");
		
		/* Explode effect */
		ExplodeMain(TargetPosition);
	}
	return Plugin_Continue;
}

public Action:Event_Infected_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (ReleaseLock[client])
	{
		decl Float:TargetPosition[3];
		new target = GetClientAimTarget(client, false);
		if (target < 0)
			return Plugin_Continue;
		GetEntityAbsOrigin(target, TargetPosition);
		
		/* Explode effect */
		EmitSoundToAll(EXPLOSIONSOUND, target);
		ExplodeMain(TargetPosition);
		
		/* Reset Lethal Weapon lock */
		ReleaseLock[client] = 0;
	}
	return Plugin_Continue;
}

public Action:Event_Player_Hurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "attacker"));
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	new dtype = GetEventInt(event, "type");
	
	if (ReleaseLock[client] && dtype != 268435464)
	{
		new health = GetEventInt(event,"health");
		new damage = GetConVarInt(l4d2_nuclearmissiledamage);
		
		decl Float:AttackPosition[3];
		decl Float:TargetPosition[3];
		GetClientAbsOrigin(client, AttackPosition);
		GetClientAbsOrigin(target, TargetPosition);
		
		/* Explode effect */
		EmitSoundToAll(EXPLOSIONSOUND, target);
		ExplodeMain(TargetPosition);
		
		/* Smash target */
		if (GetConVarInt(l4d2_nuclearmissile) != 2)
			Smash(client, target, GetConVarFloat(l4d2_nuclearforce	), 1.5, 2.0);
		
		/* Deal lethal damage */
		if ((GetClientTeam(client) != GetClientTeam(target)) || GetConVarInt(l4d2_check))
			SetEntProp(target, Prop_Data, "m_iHealth", health - damage);
		
		/* Reset Lethal Weapon lock */
		ReleaseLock[client] = 0;
	}
	return Plugin_Continue;
}

public Action:Event_Weapon_Fire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ChargeEndTime[client] = RoundToCeil(GetGameTime()) + GetConVarInt(l4d2_chargetime);
	
	if (ReleaseLock[client])
	{
		/* Flash screen */
		if (GetConVarInt(l4d2_flash))
		{
			ScreenFade(client, 200, 200, 255, 255, 100, 1);
		}

		if (GetConVarInt(l4d2_shake))
		{
			ScreenShake(client);
		}
		
		/* Laser effect */
		GetTracePosition(client);
		CreateLaserEffect(client, 0, 0, 200, 230, 2.0, 1.00);
		
		/* Emit sound */
		EmitSoundToAll(
			AWPSHOT, client,
			SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL,
			125, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
		
		/* Reset client condition */
		CreateTimer(0.2, ReleaseTimer, client);
		if (GetConVarInt(l4d2_shootonce))
		{
			ChargeLock[client] = 1;
			PrintToChat(client, "\x03聚合型高爆弹在每关只能发射一次\x01");
		}
		else
		{
			// Enable shooting more than once per round again
			ChargeLock[client] = 0;
		}
	}
}

public Action:ReleaseTimer(Handle:timer, any:client)
{
	/* Set ammo after using */
	if (GetConVarInt(l4d2_useammocount))
	{
		new Weapon = GetEntDataEnt2(client, CurrentWeapon);
		new iAmmo = FindDataMapOffs(client,"m_iAmmo");
		SetEntData(Weapon, ClipSize, 0);
		SetEntData(client, iAmmo+999,  RoundToFloor(GetEntData(client, iAmmo+999)  / 2.0));
		SetEntData(client, iAmmo+999, RoundToFloor(GetEntData(client, iAmmo+999) / 2.0));
		SetEntData(client, iAmmo+999, RoundToFloor(GetEntData(client, iAmmo+999) / 2.0));
	}

	/* Reset flags */
	ReleaseLock[client] = 0;
	ChargeEndTime[client] = RoundToCeil(GetGameTime()) + GetConVarInt(l4d2_chargetime);
}

public Action:ChargeTimer(Handle:timer, any:client)
{
	// Make sure we remove the lock if this ConVar is later disabled
	if (GetConVarInt(l4d2_shootonce) < 1)
	{
		ChargeLock[client] = 0;
	}

	StopSound(client, SNDCHAN_AUTO, CHARGESOUND);
	if (!GetConVarInt(l4d2_nuclearmissile) || ChargeLock[client])
		return Plugin_Continue;

	if (!IsValidEntity(client) || !IsClientInGame(client))
	{
		ClientTimer[client] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	/* Get data */
	new gt = RoundToCeil(GetGameTime());
	new ct = GetConVarInt(l4d2_chargetime);
	new buttons = GetClientButtons(client);
	new WeaponClass = GetEntDataEnt2(client, CurrentWeapon);
	new String:weapon[32];
	GetClientWeapon(client, weapon, 32);
	
	/* These weapons allow you to start charging */
	/* Now allowed: Hunting Rifle, G3SG1, Scout, AWP */
	if (!(StrEqual(weapon, "weapon_grenade_launcher") && GetConVarInt(l4d2_grenadelauncher)))
	{
		StopSound(client, SNDCHAN_AUTO, CHARGESOUND);
		ReleaseLock[client] = 0;
		ChargeEndTime[client] = gt + ct;
		return Plugin_Continue;
	}

	// Base case to be overridden, just in case someone messes with the ConVar
	new inCharge = ((GetEntityFlags(client) & FL_DUCKING) &&
					(GetEntityFlags(client) & FL_ONGROUND) &&
					!(buttons & IN_ATTACK) &&
					!(buttons & IN_ATTACK2));
	
        if (GetConVarInt(l4d2_moveandcharge) < 1)
        {
		/* Ducked, not moving, not attacking, not incapaciated */
		inCharge = ((GetEntityFlags(client) & FL_DUCKING) &&
					(GetEntityFlags(client) & FL_ONGROUND) &&
					!(buttons & IN_FORWARD) &&
					!(buttons & IN_MOVERIGHT) &&
					!(buttons & IN_MOVELEFT) &&
					!(buttons & IN_BACK) &&
					!(buttons & IN_ATTACK) &&
					!(buttons & IN_ATTACK2));
        }
        else
        {
		/* Ducked, moving, not attacking, not incapaciated */
		inCharge = ((GetEntityFlags(client) & FL_DUCKING) &&
					(GetEntityFlags(client) & FL_ONGROUND) &&
					!(buttons & IN_ATTACK) &&
					!(buttons & IN_ATTACK2));
        }
	
	/* If in charging, display charge bar */
	if (inCharge && GetEntData(WeaponClass, ClipSize))
	{
		if (ChargeEndTime[client] < gt)
		{
			/* Charge end, ready to fire */
			PrintCenterText(client, "*****************聚合型高爆弹装填完毕,准备发射 *****************");
			if (ReleaseLock[client] != 1)
			{
				decl Float:pos[3];
				GetClientAbsOrigin(client, pos);
				if (GetConVarInt(l4d2_chargedsound))
				{
					EmitSoundToAll(CHARGEDUPSOUND, client);
				}
				if (GetConVarInt(l4d2_chargeparticle))
				{
					ShowParticle(pos, "electrical_arc_01_system", 5.0);
				}
			}
			ReleaseLock[client] = 1;
		}
		else
		{
			/* Not charged yet. Display charge gauge */
			new i, j;
			new String:ChargeBar[50];
			new String:Gauge1[2] = "|";
			new String:Gauge2[2] = " ";
			new Float:GaugeNum = (float(ct) - (float(ChargeEndTime[client] - gt))) * (100.0/float(ct))/2.0;
			ReleaseLock[client] = 0;
			if(GaugeNum > 50.0)
				GaugeNum = 50.0;
			
			for(i=0; i<GaugeNum; i++)
				ChargeBar[i] = Gauge1[0];
			for(j=i; j<50; j++)
				ChargeBar[j] = Gauge2[0];
			if (GaugeNum >= 15)
			{
				/* Gauge meter is 30% or more */
				decl Float:pos[3];
				GetClientAbsOrigin(client, pos);
				pos[2] += 45;
				if (GetConVarInt(l4d2_chargeparticle))
				{
					ShowParticle(pos, "electrical_arc_01_cp0", 5.0);
				}
				if (GetConVarInt(l4d2_chargingsound))
				{
					EmitSoundToAll(CHARGESOUND, client);
				}
			}
			/* Display gauge */
			PrintCenterText(client, "           << 聚合型高爆弹正在装填 >>\n0%% %s %3.0f%%", ChargeBar, GaugeNum*2);
		}
	}
	else
	{
		/* Not matching condition */
		StopSound(client, SNDCHAN_AUTO, CHARGESOUND);
		ReleaseLock[client] = 0;
		ChargeEndTime[client] = gt + ct;
	}
	return Plugin_Continue;
}

public ExplodeMain(Float:pos[3])
{
	/* Main effect when hit */
	if (GetConVarInt(l4d2_chargeparticle))
	{
		ShowParticle(pos, "electrical_arc_01_system", 5.0);
	}
	LittleFlower(pos, EXPLODE);
	
	if (GetConVarInt(l4d2_nuclearmissile) == 1)
	{
		ShowParticle(pos, "gas_explosion_main", 5.0);
		LittleFlower(pos, MOLOTOV);
	}
}

public ShowParticle(Float:pos[3], String:particlename[], Float:time)
{
	/* Show particle effect you like */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}  
}

public PrecacheParticle(String:particlename[])
{
	/* Precache particle */
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		DispatchKeyValue(particle, "effect_name", particlename);
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(0.01, DeleteParticles, particle);
	}  
}

public Action:DeleteParticles(Handle:timer, any:particle)
{
	/* Delete particle */
    if (IsValidEntity(particle))
	{
		new String:classname[64];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
            		RemoveEdict(particle);
	}
}

public LittleFlower(Float:pos[3], type)
{
	/* Cause fire(type=0) or explosion(type=1) */
	new entity = CreateEntityByName("prop_physics");
	if (IsValidEntity(entity))
	{
		pos[2] += 10.0;
		if (type == 0)
			/* fire */
			DispatchKeyValue(entity, "model", "models/props_junk/gascan001a.mdl");
		else
			/* explode */
			DispatchKeyValue(entity, "model", "models/props_junk/propanecanister001a.mdl");
		DispatchSpawn(entity);
		SetEntData(entity, GetEntSendPropOffs(entity, "m_CollisionGroup"), 1, 1, true);
		TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(entity, "break");
	}
}

public Action:GetEntityAbsOrigin(entity,Float:origin[3])
{
	/* Get target posision */
	decl Float:mins[3], Float:maxs[3];
	GetEntPropVector(entity,Prop_Send,"m_vecOrigin",origin);
	GetEntPropVector(entity,Prop_Send,"m_vecMins",mins);
	GetEntPropVector(entity,Prop_Send,"m_vecMaxs",maxs);
	
	origin[0] += (mins[0] + maxs[0]) * 0.5;
	origin[1] += (mins[1] + maxs[1]) * 0.5;
	origin[2] += (mins[2] + maxs[2]) * 0.5;
}

Smash(client, target, Float:power, Float:powHor, Float:powVec)
{
	/* Smash target */
	// Check so that we don't "smash" other Survivors (only if "l4d2_check" is 0)
	if (GetConVarInt(l4d2_check) || GetClientTeam(target) != 2)
	{
		decl Float:HeadingVector[3], Float:AimVector[3];
		GetClientEyeAngles(client, HeadingVector);
	
		AimVector[0] = FloatMul(Cosine(DegToRad(HeadingVector[1])) ,power * powHor);
		AimVector[1] = FloatMul(Sine(DegToRad(HeadingVector[1])) ,power * powHor);
	
		decl Float:current[3];
		GetEntPropVector(target, Prop_Data, "m_vecVelocity", current);
	
		decl Float:resulting[3];
		resulting[0] = FloatAdd(current[0], AimVector[0]);	
		resulting[1] = FloatAdd(current[1], AimVector[1]);
		resulting[2] = power * powVec;
	
		TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, resulting);
	}
}

public ScreenFade(target, red, green, blue, alpha, duration, type)
{
	new Handle:msg = StartMessageOne("Fade", target);
	BfWriteShort(msg, 500);
	BfWriteShort(msg, duration);
	if (type == 0)
	{
		BfWriteShort(msg, (0x0002 | 0x0008));
	}
	else
	{
		BfWriteShort(msg, (0x0001 | 0x0010));
	}
	BfWriteByte(msg, red);
	BfWriteByte(msg, green);
	BfWriteByte(msg, blue);
	BfWriteByte(msg, alpha);
	EndMessage();
}

public ScreenShake(target)
{
	new Handle:msg;
	if (GetConVarInt(l4d2_nm_shake_shooteronly))
	{
		msg = StartMessageAll("Shake");
	}
	else
	{
		msg = StartMessageOne("Shake", target);
	}
	BfWriteByte(msg, 0);
 	BfWriteFloat(msg, GetConVarFloat(l4d2_nm_shake_intensity));
 	BfWriteFloat(msg, 10.0);
 	BfWriteFloat(msg, 3.0);
	EndMessage();
}

public GetTracePosition(client)
{
	decl Float:myAng[3];
	GetClientEyePosition(client, myPos);
	GetClientEyeAngles(client, myAng);
	new Handle:trace = TR_TraceRayFilterEx(myPos, myAng, CONTENTS_SOLID|CONTENTS_MOVEABLE, RayType_Infinite, TraceEntityFilterPlayer, client);
	if(TR_DidHit(trace))
		TR_GetEndPosition(trsPos, trace);
	CloseHandle(trace);
	for(new i = 0; i < 3; i++)
		trsPos002[i] = trsPos[i];
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
	return entity > GetMaxClients() || !entity;
}

public CreateLaserEffect(client, colRed, colGre, colBlu, alpha, Float:width, Float:duration)
{
	decl Float:tmpVec[3];
	SubtractVectors(myPos, trsPos, tmpVec);
	NormalizeVector(tmpVec, tmpVec);
	ScaleVector(tmpVec, GetConVarFloat(l4d2_laseroffset));
	SubtractVectors(myPos, tmpVec, trsPos);
	
	decl color[4];
	color[0] = colRed; 
	color[1] = colGre;
	color[2] = colBlu;
	color[3] = alpha;
	TE_SetupBeamPoints(myPos, trsPos002, g_sprite, 0, 0, 0, duration, width, width, 1, 0.0, color, 0);
	TE_SendToAll();
}

public DeleteEntity(any:ent, String:name[])
{
	 if (IsValidEntity(ent))
	 {
		 decl String:classname[64];
		 GetEdictClassname(ent, classname, sizeof(classname));
		 if (StrEqual(classname, name, false))
		 {
			AcceptEntityInput(ent, "Kill"); 
			RemoveEdict(ent);
		 }
	 }
}

public Action:Explode2(Handle:timer, Handle:h)
{
	ResetPack(h);
 	new userid=ReadPackCell(h);
	new ent1=ReadPackCell(h);
	new ent2=ReadPackCell(h);
	new ent3=ReadPackCell(h);
	new chaseent=ReadPackCell(h);
	new explode = ReadPackCell(h);
	new shotgun = ReadPackCell(h);
	decl Float:pos[3];
	pos[0]=ReadPackFloat(h);
	pos[1]=ReadPackFloat(h);
	pos[2]=ReadPackFloat(h);
	new Float:damage=ReadPackFloat(h);
	new Float:radius=ReadPackFloat(h);
	new Float:force=ReadPackFloat(h);
	CloseHandle(h);
	
 	if(ent1>0 && IsValidEntity(ent1))
	{
		decl Float:pos1[3];
		GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", pos1)
		if(shotgun==1)
		{
			pos[0]=pos1[0];
			pos[1]=pos1[1];
			pos[2]=pos1[2];
		}
			
		if(explode==1)
		{
 			AcceptEntityInput(ent1, "break", userid);
			RemoveEdict(ent1);
 			if(ent2>0 && IsValidEntity(ent2))
			{
				AcceptEntityInput(ent2, "break",  userid);
				RemoveEdict(ent2);
			}
 			if(ent3>0 && IsValidEntity(ent3))
			{
				AcceptEntityInput(ent3, "break",  userid);
				RemoveEdict(ent3);
			}
		
		}
		else
		{
 			AcceptEntityInput(ent1, "kill", userid);
			RemoveEdict(ent1);
 			if(ent2>0 && IsValidEntity(ent2))
			{
				AcceptEntityInput(ent2, "kill",  userid);
				RemoveEdict(ent2);
			}
 			if(ent3>0 && IsValidEntity(ent3))
			{
				AcceptEntityInput(ent3, "kill",  userid);
				RemoveEdict(ent3);
			}
		}
		if(chaseent!=0)
		{
			DeleteEntity(chaseent, "info_goal_infected_chase");
 		}
	}
	//if(explode==0)
	{
		ShowParticle(pos, "gas_explosion_pump", 3.0);	
	}
 	new pointHurt = CreateEntityByName("point_hurt");   
 	
 	DispatchKeyValueFloat(pointHurt, "Damage", damage);        
	DispatchKeyValueFloat(pointHurt, "DamageRadius", radius);     
 	DispatchKeyValue(pointHurt, "DamageDelay", "0.0");   
	DispatchSpawn(pointHurt);
	TeleportEntity(pointHurt, pos, NULL_VECTOR, NULL_VECTOR);  
	AcceptEntityInput(pointHurt, "Hurt", userid);    
	CreateTimer(0.1, DeletePointHurt, pointHurt); 
 
	new pushmode=GetConVarInt(w_pushforce_mode);

	if(pushmode==1 || pushmode==3)
	{
		new push = CreateEntityByName("point_push");         
  		DispatchKeyValueFloat (push, "magnitude", force);                     
		DispatchKeyValueFloat (push, "radius", radius*1.0);                     
  		SetVariantString("spawnflags 24");                     
		AcceptEntityInput(push, "AddOutput");
 		DispatchSpawn(push);   
		TeleportEntity(push, pos, NULL_VECTOR, NULL_VECTOR);  
 		AcceptEntityInput(push, "Enable", userid, userid);
		CreateTimer(0.5, DeletePushForce, push);
	}
	if(pushmode==2 || pushmode==3)
	{
		PushAway(pos, force, radius);
	}
 
	return;
}

public Action:DeletePointHurt(Handle:timer, any:ent)
{
	 if (IsValidEntity(ent))
	 {
		 decl String:classname[64];
		 GetEdictClassname(ent, classname, sizeof(classname));
		 if (StrEqual(classname, "point_hurt", false))
				{
					AcceptEntityInput(ent, "Kill"); 
					RemoveEdict(ent);
				}
		 }

}

public Action:DeletePushForce(Handle:timer, any:ent)
{
	 if (IsValidEntity(ent))
	 {
		 decl String:classname[64];
		 GetEdictClassname(ent, classname, sizeof(classname));
		 if (StrEqual(classname, "point_push", false))
				{
 					//AcceptEntityInput(ent, "Disable");
					AcceptEntityInput(ent, "Kill"); 
					RemoveEdict(ent);
				}
	 }
}

PushAway( Float:pos[3], Float:force, Float:radius)
{
	pos[2]-=100;
	new Float:limit=GetConVarFloat(w_pushforce_vlimit);
	new Float:normalfactor=GetConVarFloat(w_pushforce_factor);
	new Float:tankfactor=GetConVarFloat(w_pushforce_tankfactor);
	new Float:survivorfactor=GetConVarFloat(w_pushforce_survivorfactor);
	new Float:factor;
	new Float:r;


	for (new target = 1; target <= MaxClients; target++)
	{
		if (IsClientInGame(target))
		{
			if (IsPlayerAlive(target))
			{
					decl Float:targetVector[3]
					GetClientEyePosition(target, targetVector)
													
					new Float:distance = GetVectorDistance(targetVector, pos);

					if(GetClientTeam(target)==2)
					{
						factor=survivorfactor;
						r=radius*0.8;
 					}
					else if(GetClientTeam(target)==3)
					{
 						new class = GetEntProp(target, Prop_Send, "m_zombieClass");
						if(class==5)
						{
							factor=tankfactor;
							r=radius*1.0;
						}
						else
						{
							factor=normalfactor;
							r=radius*1.3;
						}
					}
							
					if (distance < r )
					{
						decl Float:vector[3];
					
						MakeVectorFromPoints(pos, targetVector, vector);
								
						NormalizeVector(vector, vector);
						ScaleVector(vector, force);
						if(vector[2]<0.0)vector[2]=10.0;

						vector[0]*=factor;
						vector[1]*=factor;
						vector[2]*=factor;

						vector[0]*=factor;
						vector[1]*=factor;
						vector[2]*=factor;
						if(vector[0]>limit)
						{
							vector[0]=limit;
						}
						if(vector[1]>limit)
						{
							vector[1]=limit;
						}
						if(vector[2]>limit)
						{
							vector[2]=limit;
						}

						if(vector[0]<-limit)
						{
							vector[0]=-limit;
						}
						if(vector[1]<-limit)
						{
							vector[1]=-limit;
						}
						if(vector[2]<-limit)
						{
							vector[2]=-limit;
						}
 						TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, vector);				
				 
 					}
			 
			}
		}
	}

}