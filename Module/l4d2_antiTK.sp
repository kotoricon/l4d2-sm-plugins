#include <sdktools>
#include <sourcemod>
#include <sdkhooks>

#define IsValidClient(%0) (1 <= %0 <= MaxClients && IsClientInGame(%0))

#define DMG_BURN                                    (1 << 3)    /**< heat burned */

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "Anti Team Killer",
	author = "Kirisame",
	description = "Anti TK",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
}

public OnPluginStart()
{
	HookEvent("witch_harasser_set", Player_HarasserWitch);
}

public OnClientPutInServer(id) 
{ 
	SDKHook(id, SDKHook_OnTakeDamage, OnTakeDamage) 
}

public Action:Player_HarasserWitch(Handle:event, const String:name[], bool:dontBroadcast)
{
	new harasser = GetClientOfUserId(GetEventInt(event, "userid"));

	if(IsValidClient(harasser))
	{
		new AdminId:id = GetUserAdmin(harasser);
		if(id == INVALID_ADMIN_ID || !GetAdminFlag(id, Admin_Root) && !IsFakeClient(harasser) && GetClientTeam(harasser) == 2 && IsPlayerAlive(harasser))
		{
			NewCommand(harasser, "sm_vomitplayer", "@me");
			PrintToChat(harasser, "\x03禁止恶意惊扰 \x04Witch\x01");
		}
	}
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) 
{
	//attacker not valid/connected @ selfdamage 
	if(!IsValidClient(attacker) || victim == attacker) return Plugin_Continue; 
	new AdminId:id = GetUserAdmin(attacker);
	
	decl String:sWeapon[64];
	GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));
	
	//ok he is TK you 
	if(GetClientTeam(victim) == GetClientTeam(attacker)) 
	{
		if(id == INVALID_ADMIN_ID || !GetAdminFlag(id, Admin_Root))
		{
			//SDKHooks_TakeDamage(entity, inflictor, attacker, Float:damage, damageType=DMG_GENERIC, weapon=-1, const Float:damageForce[3]=NULL_VECTOR, const Float:damagePosition[3]=NULL_VECTOR);  
			//do damage to attacker 
			if(damagetype != DMG_BURN)
			{
				SDKHooks_TakeDamage(attacker, 0, 0, damage, damagetype);
				PrintHintText(attacker, "禁止恶意或非恶意TK, 所有对队友造成的伤害会返回自身!");
				damage = 0.0;
				//set 0.0 damage to victim 
			}
			return Plugin_Changed;
		}
		else
		{
			damage = 0.0;
			SDKHooks_TakeDamage(attacker, 0, 0, 0.0, damagetype);
			return Plugin_Changed;
		}
	}
	
	// if(!StrEqual(sWeapon, "weapon_melee"))
	// {
		// if(GetEntProp(victim, Prop_Send, "m_zombieClass") == 8)
		// {
			// if(id == INVALID_ADMIN_ID || !GetAdminFlag(id, Admin_Root))
			// {
				// if(GetRandomInt(0,90)<79)
				// {
					// damage = damage * 0.25;
					// return Plugin_Changed;
				// }
				// else if(GetRandomInt(0,50)<39)
				// {
					// damage = damage * 0.35;
					// return Plugin_Changed;
				// }
				// else if(GetRandomInt(0,40)<29)
				// {
					// damage = damage * 0.5;
					// return Plugin_Changed;
				// }
				// else if(GetRandomInt(0,19)==1)
				// {
					// new Float:tankft = damage / 10;
					// SDKHooks_TakeDamage(attacker, 0, 0, tankft, damagetype);
					// damage = damage - tankft;
					//PrintCenterText(attacker, "Tank 发动了伤害反弹返回了你刚才造成的10%伤害!");
				// }
				// else
				// {
					// damage = damage;
				// }
			// }
		// }
	// }
	return Plugin_Continue;
}

stock NewCommand(client, String:command[], String:arguments[]="")
{
	new userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}