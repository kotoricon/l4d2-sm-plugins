#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION  "1.0"

public Plugin:myinfo = {
	name = "Player Report",
	author = "MasterOfTheXP. Fixed by hlmod.ru users",
	description = "Report players to admins.",
	version = PLUGIN_VERSION,
	url = "http://mstr.ca/"
};

new Target[MAXPLAYERS + 1];
new Float:LastUsedReport[MAXPLAYERS + 1];

new Handle:cvarDelay;

new String:configLines[256][192];
new lines;

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	
	RegConsoleCmd("sm_report", Command_report);
	
	cvarDelay = CreateConVar("sm_playerreport_delay","5.0","Time, in seconds, to delay the target of sm_rocket's death.", FCVAR_NONE, true, 0.0);
	
	ReportAd();
}

public ReportAd()
{
	CreateTimer(300.0, ReportPlayers, _, TIMER_REPEAT);
}

public Action:ReportPlayers(Handle:timer)
{
	PrintToChatAll("\x01如遇到恶意TK,反复投票换图,重新开始或作弊等情况请输入\x05 !report \x04进行举报\x01");
}

public OnClientPutInServer(client)
{
	Target[client] = 0;
	LastUsedReport[client] = GetGameTime();
	for (new z = 1; z <= GetMaxClients(); z++)
	{
		if (Target[z] == client) Target[z] = 0;
	}
}

public Action:Command_report(client, args)
{
	if (LastUsedReport[client] + GetConVarFloat(cvarDelay) > GetGameTime())
	{
		ReplyToCommand(client, "[举报系统] 必须等待 %i 秒后才能进行下一次举报.", RoundFloat((LastUsedReport[client] + RoundFloat(GetConVarFloat(cvarDelay))) - RoundFloat(GetGameTime())));
		return Plugin_Handled;
	}
	if (args == 0) ChooseTargetMenu(client);
	else if (args == 1)
	{
		new String:arg1[128];
		GetCmdArg(1, arg1, 128);
		Target[client] = FindTarget(client, arg1, true, false);
		if (!IsValidClient(Target[client]))
		{
			ReplyToCommand(client, "[举报系统] %t", "玩家已离开服务器或不存在");
			return Plugin_Handled;
		}
		ReasonMenu(client);
	}
	else if (args > 1)
	{
		new String:arg1[128], String:arg2[256];
		GetCmdArg(1, arg1, 128);
		GetCmdArgString(arg2, 256);
		ReplaceStringEx(arg2, 256, arg1, "");
		new target = FindTarget(client, arg1, true, false);
		if (!IsValidClient(target))
		{
			ReplyToCommand(client, "[举报系统] %t", "玩家已离开服务器或不存在");
			return Plugin_Handled;
		}
		ReportPlayer(client, target, arg2);
	}
	return Plugin_Handled;
}

stock ReportPlayer(client, target, String:reason[])
{
	if (!IsValidClient(target))
	{
		PrintToChat(client, "[举报系统] 玩家已离开服务器或不存在.");
		return;
	}
	new String:configFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configFile, sizeof(configFile), "configs/playerreport_logs.txt");
	new Handle:file = OpenFile(configFile, "at+");
	new String:ID1[50], String:ID2[50], String:date[50], String:time[50];
	GetClientAuthString(client, ID1, 50);
	GetClientAuthString(target, ID2, 50);
	FormatTime(date, 50, "%m/%d/%Y");
	FormatTime(time, 50, "%H:%M:%S");
	WriteFileLine(file, "玩家: %N [%s]\n举报了: %N [%s]\n日期: %s\n时间: %s\n原因: \"%s\"\n-------\n\n", client, ID1, target, ID2, date, time, reason);
	CloseHandle(file);
	PrintToChat(client, "[举报系统] Report submitted.");
	for (new z = 1; z <= GetMaxClients(); z++)
	{
		if (!IsValidClient(z)) continue;
		if (CheckCommandAccess(z, "sm_admin", ADMFLAG_ROOT, true))
		
		PrintToChat(z, "[举报系统] %N 举报了 %N (原因: \"%s\")", client, target, reason);
	}
	PrintToServer("[举报系统] %N 举报了 %N (原因: \"%s\")", client, target, reason);
	LastUsedReport[client] = GetGameTime();
}

ChooseTargetMenu(client)
{
	new Handle:smMenu = CreateMenu(ChooseTargetMenuHandler);
	SetGlobalTransTarget(client);
	new String:text[128];
	Format(text, 128, "举报玩家:", client);
	SetMenuTitle(smMenu, text);
	SetMenuExitBackButton(smMenu, false);
	SetMenuExitButton(smMenu, true);
	
	decl String:Name[128], String:UserID[5];
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && i != client)
		{
			GetClientName(i, Name, sizeof(Name));
			IntToString(GetClientUserId(i), UserID, sizeof(UserID));
			AddMenuItem(smMenu, UserID, Name);
		}
	}
	
	DisplayMenu(smMenu, client, MENU_TIME_FOREVER);
}

public ChooseTargetMenuHandler(Handle:menu, MenuAction:action, client, param2)
{
	if (action == MenuAction_Select)
	{
		new String:info[32];
		new userid, target;
		
		GetMenuItem(menu, param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0) PrintToChat(client, "[举报系统] %t", "玩家已离开服务器或不存在");
		else
		{
			if (client == target) ReplyToCommand(client, "[举报系统] 无法举报自己");
			else
			{
				Target[client] = target;
				ReasonMenu(client);
			}
		}
	}
}

ReasonMenu(client)
{
	new Handle:smMenu = CreateMenu(ReasonMenuHandler);
	SetGlobalTransTarget(client);
	new String:text[128];
	Format(text, 128, "Select reason:");
	SetMenuTitle(smMenu, text);
	lines = ReadConfig("playerreport_reasons");
	for (new z = 0; z <= lines - 1; z++)
	{
		AddMenuItem(smMenu, configLines[z], configLines[z]);
	}
	DisplayMenu(smMenu, client, MENU_TIME_FOREVER);
	return;
}

public ReasonMenuHandler(Handle:menu, MenuAction:action, client, item)
{
	if (action == MenuAction_Cancel && item == MenuCancel_ExitBack) CloseHandle(menu);
	if (action == MenuAction_Select)
	{
		new String:selection[128];
		GetMenuItem(menu, item, selection, 128);
		ReportPlayer(client, Target[client], selection);
	}
}

stock bool:IsValidClient(client)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	return true;
}

stock ReadConfig(String:configName[])
{
	new String:configFile[PLATFORM_MAX_PATH];
	new String:line[192];
	new i = 0;
	new totalLines = 0;
	
	BuildPath(Path_SM, configFile, sizeof(configFile), "configs/%s.txt", configName);
	
	new Handle:file = OpenFile(configFile, "rt");
	
	if(file != INVALID_HANDLE)
	{
		while (!IsEndOfFile(file))
		{
			if (!ReadFileLine(file, line, sizeof(line)))
				break;
			
			TrimString(line);
			if(strlen(line) > 0)
			{
				FormatEx(configLines[i], 192, "%s", line);
				totalLines++;
			}
			
			i++;
			
			if(i >= sizeof(configLines))
			{
				LogError("%s config contains too many entries!", configName);
				break;
			}
		}
				
		CloseHandle(file);
	}
	else LogError("[SM] ERROR: Config sourcemod/configs/%s.txt does not exist.", configName);
	
	return totalLines;
}