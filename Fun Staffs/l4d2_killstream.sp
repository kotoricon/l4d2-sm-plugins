#include <sdktools>
#include <sourcemod>
#include <sdktools_functions>

#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_NOTIFY

#define ATTACKER new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
#define CLIENT new client = GetClientOfUserId(GetEventInt(event, "userid"));

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))

new playerSKill[MAXPLAYERS+1];

//static String:logfilepath[256];

//new Handle:PlayerStatsSave = INVALID_HANDLE;
//new Handle:CleanSaveFileDays	=	INVALID_HANDLE;
//new bool:IsAdmin[MAXPLAYERS+1]	=	{false, ...};

public Plugin:myinfo =
{
	name = "连杀奖励系统",
	author = "Kirisame",
	description = "如题",
	version = PLUGIN_VERSION,
	url = "Undefined"
}

public OnPluginStart()
{	
	CreateConVar("l4d2_ks_version", PLUGIN_VERSION, "插件版本", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_start", Event_Round_Start);
	HookEvent("round_end", Event_Round_End);
	//HookEvent("player_incapacitated", Event_Incapacitated);
}

public OnClientPutInServer(client)
{
	playerSKill[client] = 0;
}

public OnClientDisconnect(client)
{
	playerSKill[client] = 0;
}

// public Action:Event_Incapacitated(Handle:event, const String:name[], bool:dontBroadcast)
// {
	// new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// playerSKill[victim] = 0;
	// PrintHintText(victim, "因倒地造成连杀清空为 0 , 请继续努力!");
// }

public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i=1; i<=MaxClients; i++)
	{
		playerSKill[i] = 0;
	}
}
public Action:Event_Round_End(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i=1; i<=MaxClients; i++)
	{
		playerSKill[i] = 0;
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	decl String:CurrentDifficulty[64];
	GetConVarString(FindConVar("z_difficulty"), CurrentDifficulty, sizeof(CurrentDifficulty));

	if(IsValidClient(victim))
	{
		if(GetClientTeam(victim) == 2)
		{
			playerSKill[victim] = 0;
			PrintHintText(victim, "因死亡造成连杀清空为 0 , 请继续努力!");
		}
		if(GetClientTeam(victim) == 3)
		{
			if(IsValidClient(attacker))
			{
				if(GetClientTeam(attacker) == 2)
				{
					if(!IsFakeClient(attacker) && attacker != 0)
					{
						playerSKill[attacker] += 1;
						PrintHintText(attacker, "目前特殊感染者连杀数:    %d", playerSKill[attacker]);
						new count = playerSKill[attacker];
						
						switch(count)
						{
							case 5:
							{
								if(GetRandomInt(0,1)==1)
								{
									CheatCommand(attacker, "upgrade_add", "INCENDIARY_AMMO");
								}
								else
								{
									CheatCommand(attacker, "upgrade_add", "EXPLOSIVE_AMMO");
								}
								PrintToChat(attacker, "\x01成功获得第一阶段\x04 5 \x01连杀奖励!奖励为 \x03特殊弹药\x01");
							}
							case 10:
							{
								if(GetRandomInt(0,1)==1)
								{
									CheatCommand(attacker, "give", "pain_pills");
								}
								else
								{
									CheatCommand(attacker, "give", "adrenaline");
								}
								PrintToChat(attacker, "\x01成功获得第二阶段\x04 10 \x01连杀奖励!奖励为 \x03药品补给\x01");
							}
							case 15:
							{
								if(GetRandomInt(0,1)==1)
								{
									CheatCommand(attacker, "give", "pain_pills");
								}
								else
								{
									CheatCommand(attacker, "give", "adrenaline");
								}
								CheatCommand(attacker, "give", "give ammo");
								PrintToChat(attacker, "\x01成功获得第三阶段\x04 15 \x01连杀奖励!奖励为 \x03双重补给\x01");
							}
							case 25:
							{
								CheatCommand(attacker, "give", "first_aid_kit");
								if(GetRandomInt(0,1)==1)
								{
									CheatCommand(attacker, "upgrade_add", "INCENDIARY_AMMO");
								}
								else
								{
									CheatCommand(attacker, "upgrade_add", "EXPLOSIVE_AMMO");
								}
								CheatCommand(attacker, "give", "give ammo");
								PrintToChat(attacker, "\x01成功获得第四阶段\x04 25 \x01连杀奖励!奖励为 \x03补给大包\x01 !");
							}
							case 35:
							{
								if(StrEqual(CurrentDifficulty, "Hard", false) || StrEqual(CurrentDifficulty, "Impossible", false))
								{
									CheatCommand(attacker, "give", "rifle_m60");
									CheatCommand(attacker, "give", "first_aid_kit");
									if(GetRandomInt(0,1)==1)
									{
										CheatCommand(attacker, "upgrade_add", "INCENDIARY_AMMO");
										CheatCommand(attacker, "give", "pipe_bomb");
									}
									else
									{
										CheatCommand(attacker, "upgrade_add", "EXPLOSIVE_AMMO");
										CheatCommand(attacker, "give", "molotov");
									}
									CheatCommand(attacker, "give", "give ammo");
									PrintToChat(attacker, "\x01成功获得最终阶段\x04 35 \x01连杀奖励!奖励为 \x03特别装备包\x01 ! \x05已重设连杀奖励\x04\x01");
									playerSKill[attacker] = 0;
								}
								else
								{
									return Plugin_Continue;
								}
							}
							case 50:
							{
								if(StrEqual(CurrentDifficulty, "Easy", false) || StrEqual(CurrentDifficulty, "Normal", false))
								{
									CheatCommand(attacker, "give", "rifle_m60");
									CheatCommand(attacker, "give", "first_aid_kit");
									if(GetRandomInt(0,1)==1)
									{
										CheatCommand(attacker, "upgrade_add", "INCENDIARY_AMMO");
										CheatCommand(attacker, "give", "pipe_bomb");
									}
									else
									{
										CheatCommand(attacker, "upgrade_add", "EXPLOSIVE_AMMO");
										CheatCommand(attacker, "give", "molotov");
									}
									CheatCommand(attacker, "give", "give ammo");
									PrintToChat(attacker, "\x01成功获得最终阶段\x04 50 \x01连杀奖励!奖励为 \x03特别装备包\x01 ! \x05已重设连杀奖励\x04\x01");
									playerSKill[attacker] = 0;
								}
								else
								{
									playerSKill[attacker] = 0;
									return Plugin_Continue;
								}
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

stock CheatCommand(client, String:command[], String:arguments[]="")
{
	new userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}