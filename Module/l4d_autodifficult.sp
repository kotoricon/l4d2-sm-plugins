#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#define DEBUG 0

#define PLUGIN_VERSION "1.00"
#define CVAR_FLAGS          FCVAR_PLUGIN|FCVAR_NOTIFY
 

new Handle:l4d_boss_zombieslimitadd;
new Handle:l4d_boss_zombieshealthadd ;
new Handle:l4d_boss_ajustdiff ;


public Plugin:myinfo = 
{
	name = "自动难度",
	author = " 小海，QQ 759674417",
	description = "自动难度",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
}


public OnPluginStart()
{


	HookEvent("player_spawn", Event_Player_Spawn); 

	l4d_boss_zombieslimitadd = CreateConVar("l4d_boss_zombieslimitadd", "5", "每多一个人增加的僵尸数量", CVAR_FLAGS); 	//HookEvent("tank_spawn", Event_Tank_Spawn); //, EventHookMode_PostNoCopy
	l4d_boss_zombieshealthadd = CreateConVar("l4d_boss_zombieshealthadd", "10", "每多一个人增加的僵尸血量", CVAR_FLAGS); 	//HookEvent("tank_spawn", Event_Tank_Spawn); //, EventHookMode_PostNoCopy
	l4d_boss_ajustdiff = CreateConVar("l4d_boss_ajustdiff", "1", "根据人数设置僵尸血量与数量", CVAR_FLAGS); 	//HookEvent("tank_spawn", Event_Tank_Spawn); //, EventHookMode_PostNoCopy


 
	AutoExecConfig(true, "l4d_autodifficult");
 
	RegAdminCmd("sm_zlimit", ZLimit, ADMFLAG_ROOT, "Increase Zombie amount (-1 off, 1 on)");
	RegAdminCmd("sm_zhealth", ZHealth, ADMFLAG_ROOT, "Increase Zombie amount (-1 off, 1 on)");

  
	 
}
StripAndChangeServerConVarInt(String:command[], value)
{
	// LogAction(0, -1, "DEBUG:stripandchangeserverconvarint 段落");
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	SetConVarInt(FindConVar(command), value, false, false);
	SetCommandFlags(command, flags);
}
 
public Action:ZLimit(client, args) 
{
	// LogAction(0, -1, "DEBUG:l8dhardzombies 段落");
 	new String:arg[8];
	GetCmdArg(1,arg,8);
	new Input=StringToInt(arg[0]);
	if(Input==0)
	{
		StripAndChangeServerConVarInt("z_common_limit", 30); // Default
		StripAndChangeServerConVarInt("z_mob_spawn_min_size", 10); // Default
		StripAndChangeServerConVarInt("z_mob_spawn_max_size", 30); // Default
		StripAndChangeServerConVarInt("z_mob_spawn_finale_size", 20); // Default
		StripAndChangeServerConVarInt("z_mega_mob_size", 50); // Default
		PrintToChatAll("普通僵尸数量还原");
	}
	else if(Input==1)
	{
		StripAndChangeServerConVarInt("z_common_limit", 50); // Default
		StripAndChangeServerConVarInt("z_mob_spawn_min_size", 30); // Default
		StripAndChangeServerConVarInt("z_mob_spawn_max_size", 50); // Default
		StripAndChangeServerConVarInt("z_mob_spawn_finale_size", 40); // Default
		StripAndChangeServerConVarInt("z_mega_mob_size", 70); // Default
		PrintToChatAll("普通僵尸数量增强+");
	}	
	else if(Input==2)
	{
		StripAndChangeServerConVarInt("z_common_limit", 70); // Default
		StripAndChangeServerConVarInt("z_mob_spawn_min_size", 50); // Default
		StripAndChangeServerConVarInt("z_mob_spawn_max_size", 70); // Default
		StripAndChangeServerConVarInt("z_mob_spawn_finale_size", 60); // Default
		StripAndChangeServerConVarInt("z_mega_mob_size", 90); // Default
		PrintToChatAll("普通僵尸数量增强++");
	}		
	else if(Input>1&&Input<7)
	{
		StripAndChangeServerConVarInt("z_common_limit", 30*Input); // Default 30
		StripAndChangeServerConVarInt("z_mob_spawn_min_size", 30*Input); // Default 10
		StripAndChangeServerConVarInt("z_mob_spawn_max_size", 30*Input); // Default 30
		StripAndChangeServerConVarInt("z_mob_spawn_finale_size", 30*Input); // Default 20
		StripAndChangeServerConVarInt("z_mega_mob_size", 30*Input); // Default 50
		PrintToChatAll("普通僵尸数量增强+++");
	}
	else
	{
		ReplyToCommand(client, "\x01[sea]:你需要多少僵尸?. (倍率为 30. 参数从: 1 ~ 7)");
		ReplyToCommand(client, "\x01[sea]:怪物太多即会LAG,推荐值为不超过3.");
	}
	return Plugin_Handled;
}
public Action:ZHealth(client, args) 
{
	// LogAction(0, -1, "DEBUG:l8dhardzombies 段落");
 	new String:arg[8];
	GetCmdArg(1,arg,8);
	new Input=StringToInt(arg[0]);
	if(Input==0)
	{
		StripAndChangeServerConVarInt("z_health", 50); // Default
 		PrintToChatAll("普通僵尸血量还原");
	}
	else if(Input==1)
	{
		StripAndChangeServerConVarInt("z_health", 100); // Default
 		PrintToChatAll("普通僵尸血量增强+");
	}	
	else if(Input==2)
	{
		StripAndChangeServerConVarInt("z_health", 150); // Default
		PrintToChatAll("普通僵尸血量增强++");
	}		
	else if(Input>1&&Input<7)
	{
		StripAndChangeServerConVarInt("z_health", 50*Input); // Default
		PrintToChatAll("普通僵尸血量增强+++");
	}
 	return Plugin_Handled;
}

 

public Action:Event_Player_Spawn(Handle:event, String:event_name[], bool:dontBroadcast)
{
 	//PrintToChatAll("player_spawn");
	new ClientId   = 0;
	ClientId = GetClientOfUserId(GetEventInt(event, "userid"));
	if (ClientId == 0) 
	{
 		return Plugin_Continue;
	}
 	if(GetClientTeam(ClientId) == 3)
	{
	}
	new	survivornum=0;
 	if(GetClientTeam(ClientId) == 2)
	{
		
		for(new client = 1; client <= MaxClients; client++)
		{
			if(IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client)==2 && !IsFakeClient(client))
			{
				survivornum++;
			}
		}
		 
		new count=survivornum-4;
		if(count<0)count=0;
		if(GetConVarInt(l4d_boss_ajustdiff)>0)
		{
			StripAndChangeServerConVarInt("z_common_limit", 30+GetConVarInt(l4d_boss_zombieslimitadd)*count); 
			StripAndChangeServerConVarInt("z_mob_spawn_min_size", 10+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_mob_spawn_max_size", 30+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_mob_spawn_finale_size", 20+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_mega_mob_size", 50+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			//StripAndChangeServerConVarInt("z_health", 50+GetConVarInt(l4d_boss_zombieshealthadd)*count); // Default
		}
	}
 	return Plugin_Continue;
}
public PlayerConnectFull(Handle:event, const String:name[], bool:dontBroadcast)
{
		new survivornum=0;
		for(new client = 1; client <= MaxClients; client++)
		{
			if(IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client)==2 && !IsFakeClient(client))
			{
				survivornum++;
			}
		}
		 
		new count=survivornum-4;
		if(count<0)count=0;
	 	if(GetConVarInt(l4d_boss_ajustdiff)>0)
		{

			StripAndChangeServerConVarInt("z_common_limit", 30+GetConVarInt(l4d_boss_zombieslimitadd)*count); 
			StripAndChangeServerConVarInt("z_mob_spawn_min_size", 10+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_mob_spawn_max_size", 30+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_mob_spawn_finale_size", 20+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_mega_mob_size", 50+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			//StripAndChangeServerConVarInt("z_health", 50+GetConVarInt(l4d_boss_zombieshealthadd)*count); // Default
		}

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

public OnClientDisconnect(client)
{
		new count=GetInGamePlayerCount()-4;
		if(count<0)count=0;
	 
		if(GetConVarInt(l4d_boss_ajustdiff)>0)
		{
			StripAndChangeServerConVarInt("z_common_limit", 30+GetConVarInt(l4d_boss_zombieslimitadd)*count); 
			StripAndChangeServerConVarInt("z_mob_spawn_min_size", 10+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_mob_spawn_max_size", 30+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_mob_spawn_finale_size", 20+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_mega_mob_size", 50+GetConVarInt(l4d_boss_zombieslimitadd)*count); // Default
			StripAndChangeServerConVarInt("z_health", 50+GetConVarInt(l4d_boss_zombieshealthadd)*count); // Default
		}		

}
