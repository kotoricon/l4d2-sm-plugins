#include <sdktools>
#include <sourcemod>
#include <sdkhooks>

#define IsValidClient(%0) (1 <= %0 <= MaxClients && IsClientInGame(%0))

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo = 
{
	name = "Damage Shield",
	author = "Kirisame",
	description = "Chance to anti infected damage",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
}

public OnClientPutInServer(id) 
{ 
	SDKHook(id, SDKHook_OnTakeDamage, OnTakeDamage) 
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) 
{
	//attacker not valid/connected @ selfdamage 
	if(!IsValidClient(attacker) || victim == attacker) return Plugin_Continue; 
	new AdminId:id = GetUserAdmin(victim);
	
	new Float:damage1 = damage * 10.0;
	new Float:damage2 = damage * 20.0;
	
	//special anti-damage addons 100% admins and 20% for normal player
	if(GetClientTeam(victim) != GetClientTeam(attacker) && GetClientTeam(attacker) == 3 && GetClientTeam(victim) == 2) 
	{
		//PrintToChatAll("1");
		if(id == INVALID_ADMIN_ID || !GetAdminFlag(id, Admin_Root))
		{
			if(GetRandomInt(0,4)==1)
			{
				PrintHintText(victim, "反伤系统成功启用, 伤害已反弹");
				damage = 0.0;
				return Plugin_Changed;
			}
		}
		if(IsFakeClient(victim)))
		{
			if(GetRandomInt(0,1)==1)
			{
				SDKHooks_TakeDamage(attacker, 0, 0, damage1, damagetype);
				damage = 0.0;
				return Plugin_Changed;
			}
		}
		else
		{
			//PrintToChat(victim, "反伤系统成功启用, 感染者被反弹 %.1f 伤害", damage1);
			if(GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8)
			{
				SDKHooks_TakeDamage(attacker, 0, 0, damage2, damagetype);
				damage = 2.0;
				return Plugin_Changed;
			}
			else
			{
				if(GetRandomInt(0,1)==1)
				{
					SDKHooks_TakeDamage(attacker, 0, 0, damage1, damagetype);
					damage = damage;
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Changed;
}