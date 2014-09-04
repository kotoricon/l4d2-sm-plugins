#include <sdktools>
#include <sourcemod>
#include <sdktools_functions>

#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo =
{
	name = "自尽插件",
	author = "Kirisame",
	description = "爆炸自尽毁灭僵尸",
	version = PLUGIN_VERSION,
	url = "Undefined"
}

public OnPluginStart()
{	
	CreateConVar("l4d2_zj_version", PLUGIN_VERSION, "插件版本", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	RegConsoleCmd("sm_zj",	SelfKill);
	
	ZJTip();
}

public ZJTip()
{
	CreateTimer(300.0, SelfKillTip, _, TIMER_REPEAT);
}

public Action:SelfKillTip(Handle:timer)
{
	PrintToChatAll("\x01可以输入\x05 !zj \x04在需要时进行自尽\x01");
}

public Action:SelfKill(client, args)
{
	PrintToChat(client, "开始进入自尽状态");
	DoCommand(client, "sm_vomitplayer", "@me");
	DoCommand(client, "sm_timebomb", "@me");
	return Plugin_Handled;  
}

stock DoCommand(client, String:command[], String:arguments[]="")
{
	new userflags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userflags);
}