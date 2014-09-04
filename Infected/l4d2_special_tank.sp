#include <sourcemod>
#include <sdktools>

#define DEAD -1

#define PLUGIN_VERSION "1.0"

new TANKS = DEAD;

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1) && GetClientTeam(%1) == 3)

new Float:ftlPos[3];
new bool:Rockenable = false;
//new Handle:special_tank_enable = INVALID_HANDLE;
new Handle:tank_warp_interval = INVALID_HANDLE;

public Plugin:myinfo = 
{
	name = "[L4D2] Special Tank",
	author = "Kirisame",
	description = "Tank special functions.",
	version = "1.0",
	url = "http://www.moeth.net"
}

public OnPluginStart()
{
	CreateConVar("l4d2_tankwarp_version", PLUGIN_VERSION, "Version of the Tank Warp System plugin", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	//special_tank_enable  = CreateConVar("specialtank_enable", "1", "Is Tank Warp enable? (0:OFF 1:ON)", FCVAR_NOTIFY);
	tank_warp_interval = CreateConVar("tankwarp_interval", "30.0", "Tank Warp Delay (Default: 20.0, Must bigger than 5.0)", FCVAR_PLUGIN, true, 5.0, true, 60.0);
	
	HookEvent("tank_spawn", Event_Tank_Spawn);
	HookEvent("round_start", Event_Round_Start);
}

InitData()
{
	TANKS = DEAD;
}

public OnMapStart()
{
	Rockenable = true;
	InitData();
}

public OnMapEnd()
{
	Rockenable = false; 
	InitData();
}

public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	InitData();	
}

public Action:Event_Tank_Spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new idTankSpawn = GetClientOfUserId(GetEventInt(event, "userid"));
	TANKS = idTankSpawn;
	
	CreateTimer(3.0, GetSurvivorPosition, _, TIMER_REPEAT);
	CreateTimer(GetConVarFloat(tank_warp_interval), FatalMirror, _, TIMER_REPEAT);
}

public Action:GetSurvivorPosition(Handle:timer)
{
	if(IsValidEntity(TANKS) && IsClientInGame(TANKS) && TANKS != DEAD)
	{
		new count = 0;
		new idAlive[MAXPLAYERS+1];
		
		for(new i = 1; i <= MaxClients; i++)
		{
			if(!IsValidEntity(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 2)
				continue;
			idAlive[count] = i;
			count++;
		}
		if(count == 0) return;
		new clientNum = GetRandomInt(0, count-1);
		GetClientAbsOrigin(idAlive[clientNum], ftlPos);
	}
	else
	{
		KillTimer(timer);
	}
}

public Action:FatalMirror(Handle:timer)
{
	decl String:CurrentMap[64];
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	
	if(!StrEqual(CurrentMap, "l4d_mordor_serious"))
	{
		if(IsValidEntity(TANKS) && IsClientInGame(TANKS) && TANKS != DEAD)
		{
			SetEntityMoveType(TANKS, MOVETYPE_NONE);
			SetEntProp(TANKS, Prop_Data, "m_takedamage", 0, 1);
			
			CreateTimer(1.0, WarpTimer);
		}
		else
		{
			KillTimer(timer);
		}
	}
}

public Action:WarpTimer(Handle:timer)
{
	if(IsValidEntity(TANKS) && IsClientInGame(TANKS) && TANKS != DEAD)
	{
		decl Float:pos[3];
		
		for(new i = 1; i <= GetMaxClients(); i++)
		{
			if(!IsValidEntity(i) || !IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) != 2)
				continue;
		}
		GetClientAbsOrigin(TANKS, pos);
		TeleportEntity(TANKS, ftlPos, NULL_VECTOR, NULL_VECTOR);
		SetEntityMoveType(TANKS, MOVETYPE_WALK);
		SetEntProp(TANKS, Prop_Data, "m_takedamage", 2, 1);
	}
	else
	{
		KillTimer(timer);
	}
}

//Check is tank or not
stock bool:IsTank(iEntity)
{
    if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
    {
        decl String:strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "Tank");
    }
    return false;
}

//=============================
// FIRE ROCK FUNCTIONS
//=============================
public OnEntityCreated(entity, const String:classname[])
{
	if (!IsServerProcessing()) return;
	
	if (StrEqual(classname, "tank_rock", true))
	{
		CreateTimer(0.1, RockThrowTimer, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public OnEntityDestroyed(entity)
{
	if (!IsServerProcessing()) return;
	
	if(Rockenable)
	{
		if (entity > 32 && IsValidEntity(entity))
		{
			new String:classname[32];
			GetEdictClassname(entity, classname, sizeof(classname));
			if (StrEqual(classname, "tank_rock", true))
			{
				new prop = CreateEntityByName("prop_physics");
				if (prop > 32 && IsValidEntity(prop))
				{
					new Float:Pos[3];
					GetEntPropVector(entity, Prop_Send, "m_vecOrigin", Pos);
					Pos[2] += 10.0;
					DispatchKeyValue(prop, "model", "models/props_junk/gascan001a.mdl");
					DispatchSpawn(prop);
					SetEntData(prop, GetEntSendPropOffs(prop, "m_CollisionGroup"), 1, 1, true);
					TeleportEntity(prop, Pos, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(prop, "break");
				}
			}
		}
	}
}

public Action:RockThrowTimer(Handle:timer)
{
	new entity = -1;
	while ((entity = FindEntityByClassname(entity, "tank_rock")) != INVALID_ENT_REFERENCE)
	{
		new thrower = GetEntPropEnt(entity, Prop_Data, "m_hThrower");
		if (thrower > 0 && thrower < 33 && IsTank(thrower))
		{
			SetEntityRenderColor(entity, 128, 0, 0, 255);
			CreateTimer(0.8, Timer_AttachFIRE_Rock, entity, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Timer_AttachFIRE_Rock(Handle:timer, any:entity)
{
	if (IsValidEntity(entity))
	{
		decl String: classname[32];
		GetEdictClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "tank_rock"))
		{
			IgniteEntity(entity, 100.0);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}