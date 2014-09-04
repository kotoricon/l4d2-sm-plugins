#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION "1.0"

#define IsValidClient(%0) (1 <= %0 <= MaxClients && IsClientInGame(%0))

#define SOUND_STEEL		"physics/metal/metal_solid_impact_hard5.wav"

public Plugin:myinfo = {
	name = "近战限制器",
	author = "Kirisame",
	description = "近战限制工具以及特殊特感生成器",
	version = PLUGIN_VERSION,
	url = "Undefined"
}

public OnPluginStart()
{
	HookEvent( "round_start", OnRoundStart);
	//HookEvent( "player_hurt", PlayerHurt);
}

public Action:OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	//decl String:model[36];
	
	new index = -1;
	while ((index = FindEntityByClassname(index, "weapon_chainsaw_spawn")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
	while ((index = FindEntityByClassname(index, "weapon_chainsaw")) != -1)
	{
		AcceptEntityInput(index, "Kill");
	}
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	decl String:sWeapon[64];
	GetEdictClassname(inflictor, sWeapon, sizeof(sWeapon));
    
	//attacker not valid/connected @ selfdamage 
	if(!IsValidClient(attacker) || victim == attacker) return Plugin_Continue;
	new AdminId:id = GetUserAdmin(attacker);
	
	if(StrEqual(sWeapon, "weapon_melee"))
	{
		if(id == INVALID_ADMIN_ID || !GetAdminFlag(id, Admin_Root) && !IsFakeClient(attacker))
		{
			if(GetEntProp(victim, Prop_Send, "m_zombieClass") == 2 || GetEntProp(victim, Prop_Send, "m_zombieClass") == 4 || GetEntProp(victim, Prop_Send, "m_zombieClass") == 8)
			{
				damage = 0.0;
				PrintToChat(attacker,"该特感无法使用近战进行攻击");
				EmitSoundToClient(attacker, SOUND_STEEL);
				//DoubleCommand(attacker, "sm_vomitplayer", "@me");
				DoubleCommand(attacker, "sm_charge", "@me");
				//DoubleCommand(attacker, "sm_incapplayer", "@me");
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

// public Action:PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
// {
	// new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	// new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	// new tank_health;
	
	//attacker not valid/connected @ selfdamage 
	// if(!IsValidClient(attacker) || victim == attacker) return Plugin_Continue; 
	// new AdminId:id = GetUserAdmin(attacker);
	
	// decl String:weapon[64];
	// GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	// if (StrEqual(weapon, "melee"))
	// {
		// if(GetEntProp(victim, Prop_Send, "m_zombieClass") == 8)
		// {
			// if(id == INVALID_ADMIN_ID || !GetAdminFlag(id, Admin_Root))
			// {
				// if(GetClientTeam(attacker)==2 && !IsFakeClient(attacker))
				// {
					//set 0.0 damage to victim and regen Tank HP
					// tank_health = GetEntProp(victim, Prop_Data, "m_iHealth") + 10000;
					// SetEntProp(victim, Prop_Data, "m_iHealth", tank_health);
					// PrintToChat(attacker,"\x01禁止对 \x04Tank\x01 使用近战武器! \n\x03Tank会额外获得 \x0510000HP\x03 并受到倒地惩罚\x01 !");
					// PrintToChatAll("\x03%N\x01 对Tank使用了近战武器! \n\x03如果多次恶意近战请输入 \x05!report\x03 进行举报\x01 !", attacker);
					//PrintToChat(attacker,"\x01Please don't use melee weapon on \x04Tank\x01! \n\x03Tank\x01 won't receive any damage and you will be down!");
					// EmitSoundToClient(attacker, SOUND_STEEL);
					// DoubleCommand(attacker, "sm_vomitplayer", "@me");
					// DoubleCommand(attacker, "sm_charge", "@me");
					// DoubleCommand(attacker, "sm_incapplayer", "@me");
					// ServerCommand("a4d_force_panic");
				// }
			// }
		// }
		// return Plugin_Changed; 
	// }
	// return Plugin_Continue;
// }

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