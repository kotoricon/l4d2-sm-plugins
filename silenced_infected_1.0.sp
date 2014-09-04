/*======================================================================================
	Plugin Info:

*	Name	:	[L4D / L4D2] Silenced Infected
*	Version	:	1.0
*	Author	:	SilverShot
*	Desc	:	Disable common, special, tank and witch sounds.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=137397

========================================================================================
	Change Log:

*	1.0
	- Initial release.

======================================================================================*/

#include <sourcemod>
#include <sdktools>
#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

new const String:g_Common[5][] =
{
	"npc/infected/action/",
	"npc/infected/alert/",
	"npc/infected/hit/",
	"npc/infected/idle/",
	"npc/infected/miss/"
};
new const String:g_Infected[6][] =
{
	"player/boomer/",
	"player/charger/",
	"player/hunter/",
	"player/jockey/",
	"player/smoker/",
	"player/spitter/"
};
new const String:g_Tank[1][] =
{
	"player/tank/"
};
new const String:g_Witch[1][] =
{
	"npc/witch/"
};

new i_Common;
new i_Infected;
new i_Tank;
new i_Witch;
new Handle:h_Enable = INVALID_HANDLE;
new Handle:h_Common = INVALID_HANDLE;
new Handle:h_Infect = INVALID_HANDLE;
new Handle:h_Tank = INVALID_HANDLE;
new Handle:h_Witch = INVALID_HANDLE;



/*======================================================================================
#####################			P L U G I N   I N F O				####################
======================================================================================*/
public Plugin:myinfo =
{
	name = "[L4D & L4D2] Silenced Infected",
	author = "SilverShot",
	description = "Disable common, special, tank and witch sounds.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=137397"
}


/*======================================================================================
#####################			P L U G I N   S T A R T				####################
======================================================================================*/
public OnPluginStart()
{
	// Game check.
	decl String:s_GameName[128];
	GetGameFolderName(s_GameName, sizeof(s_GameName));
	if (StrContains(s_GameName, "left4dead") < 0) SetFailState("This plugin only supports Left4Dead");

	// Cvars
	h_Enable = CreateConVar("l4d_silenced_enable", "1", "0=Disables plugin, 1=Enables plugin.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
	h_Common = CreateConVar("l4d_silenced_common", "0", "0=Enables sounds, 1=Disables common infected sounds.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
	h_Infect = CreateConVar("l4d_silenced_special", "1", "0=Enables sounds, Disables special infected sounds.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
	h_Tank = CreateConVar("l4d_silenced_tank", "0", "0=Enables sounds, 1=Disables tank sounds.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
	h_Witch = CreateConVar("l4d_silenced_witch", "0", "0=Enables sounds, 1=Disables witch sounds.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY);
	//AutoExecConfig(true, "l4d_silenced_infected");

	HookConVarChange(h_Enable, ConVarChanged_Enable);
	HookConVarChange(h_Common, ConVarChanged_Infected);
	HookConVarChange(h_Infect, ConVarChanged_Infected);
	HookConVarChange(h_Tank, ConVarChanged_Infected);
	HookConVarChange(h_Witch, ConVarChanged_Infected);

	i_Common = GetConVarInt(h_Common);
	i_Infected = GetConVarInt(h_Infect);
	i_Tank = GetConVarInt(h_Tank);
	i_Witch = GetConVarInt(h_Witch);
	HookEvents();
}


/*======================================================================================
############			C V A R   C H A N G E   A N D   H O O K S			############
======================================================================================*/
public ConVarChanged_Enable(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (StringToInt(newValue) > 0) {
		HookEvents();
	}else{
		UnhookEvents();
	}
}


public ConVarChanged_Infected(Handle:convar, const String:oldValue[], const String:newValue[])
{
	i_Common = GetConVarInt(h_Common);
	i_Infected = GetConVarInt(h_Infect);
	i_Tank = GetConVarInt(h_Tank);
	i_Witch = GetConVarInt(h_Witch);
}


HookEvents()
	AddNormalSoundHook(NormalSHook:SoundHook);

UnhookEvents()
	RemoveNormalSoundHook(NormalSHook:SoundHook);


/*======================================================================================
#####################				S O U N D   H O O K				####################
======================================================================================*/
public Action:SoundHook(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags) 
{
	if (i_Common == 1) { // Common sounds
		for (new i = 0; i < sizeof(g_Common); i++) {
			if (StrContains(sample, g_Common[i], false) > -1) {
				if(GetRandomInt(0,1)==1)
				{
					volume = 0.0;
				}
				return Plugin_Changed;
			}
		}
	}

	if (i_Infected == 1) {// Infected sounds
		for (new i = 0; i < sizeof(g_Infected); i++) {
			if (StrContains(sample, g_Infected[i], false) > -1) {
				if(GetRandomInt(0,3)>1)
				{
					volume = 0.0;
				}
				return Plugin_Changed;
			}
		}
	}

	if (i_Tank == 1) {// Tank sounds
		for (new i = 0; i < sizeof(g_Tank); i++) {
			if (StrContains(sample, g_Tank[i], false) > -1) {
				if(GetRandomInt(0,1)==1)
				{
					volume = 0.0;
				}
				return Plugin_Changed;
			}
		}
	}

	if (i_Witch == 1) {// Witch sounds
		for (new i = 0; i < sizeof(g_Witch); i++) {
			if (StrContains(sample, g_Witch[i], false) > -1) {
				if(GetRandomInt(0,1)==1)
				{
					volume = 0.0;
				}
				return Plugin_Changed;
			}
		}
	}

	return Plugin_Continue;
}