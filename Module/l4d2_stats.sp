#pragma semicolon 1
#include <sourcemod>
#include <clientprefs>
#include <colors>

#define MAX_LINE_WIDTH 64

#define	TEAM_SPECTATOR	1
#define	TEAM_SURVIVOR	2
#define	TEAM_INFECTED	3

#define ATTACKER new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
#define CLIENT new client = GetClientOfUserId(GetEventInt(event, "userid"));

#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))

new Handle:db = INVALID_HANDLE;
new RankTotal = 0;
new ClientRank[MAXPLAYERS + 1];
new ClientPoints[MAXPLAYERS + 1];
new CommonKill[MAXPLAYERS + 1];

new Handle:playerBoomerKill = INVALID_HANDLE;
new Handle:playerHunterKill = INVALID_HANDLE;
new Handle:playerSmokerKill = INVALID_HANDLE;
new Handle:playerJockeyKill = INVALID_HANDLE;
new Handle:playerChargerKill = INVALID_HANDLE;
new Handle:playerSpitterKill = INVALID_HANDLE;
new Handle:playerCommonKill = INVALID_HANDLE;
new Handle:playerTankKill = INVALID_HANDLE;
//new playerMeleeShovedTime[MAXPLAYERS+1];
new Handle:playerHeal = INVALID_HANDLE;
new Handle:playerRevive = INVALID_HANDLE;
new Handle:playerDown = INVALID_HANDLE;
new Handle:playerDefibrillated = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "玩家数据统计",
	author = "Kirisame",
	description = "数据库版数据统计",
	version = "1.0",
	url = "Twitter @chnmth"
};

enum
{
    CLASS_SMOKER = 1,
    CLASS_BOOMER = 2,
    CLASS_HUNTER = 3,
    CLASS_SPITTER = 4,
    CLASS_JOCKEY = 5,
    CLASS_CHARGER = 6,
    CLASS_TANK = 7,
    CLASS_WITCH = 8
};

public OnPluginStart()
{
	ConnectDB();
	
	playerBoomerKill = CreateConVar("sm_playerBoomerKill","1","杀死 boomer 获得多少积分");
	playerHunterKill = CreateConVar("sm_playerHunterKill","1","杀死 hunter 获得多少积分");
	playerSmokerKill = CreateConVar("sm_playerSmokerKill","1","杀死 smoker 获得多少积分");
	playerJockeyKill = CreateConVar("sm_playerJockeyKill","1","杀死 jockey 获得多少积分");
	playerChargerKill = CreateConVar("sm_playerChargerKill","1","杀死 charger 获得多少积分");
	playerSpitterKill = CreateConVar("sm_playerSpitterKill","1","杀死 spitter 获得多少积分");
	playerCommonKill = CreateConVar("sm_playerCommonKill","2","杀死一定量 普通感染者 获得多少积分");
	playerTankKill = CreateConVar("sm_playerTankKill","10","杀死 tank 获得多少积分");
	playerHeal = CreateConVar("sm_playerHeal","10","治疗他人 获得多少积分");
	playerDown = CreateConVar("sm_playerDown","5","倒地 扣除多少积分");
	playerRevive = CreateConVar("sm_playerRevive","2","拉起倒地者 获得多少积分");
	playerDefibrillated = CreateConVar("sm_playerDefibrillated","4","电击救起他人 获得多少积分");
	
	HookEvent("infected_death", Infected_Killed);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_incapacitated", event_PlayerIncap);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("heal_success", event_HealPlayer);
	HookEvent("defibrillator_used", event_DefibPlayer);
	HookEvent("revive_success", Event_ReviveSuccess);
	HookEvent("tank_killed", Event_TankDeath);
	RegConsoleCmd("sm_rank", cmd_ShowRank);
	RegConsoleCmd("sm_top10", cmd_ShowTop10);
	RegConsoleCmd("sm_nextrank", cmd_NextRank);
	//RegConsoleCmd("sm_count", cmd_CountKill);
	RegConsoleCmd("callvote", Callvote_Handler);
	RegConsoleCmd("go_away_from_keyboard", Callvote_keyboard);
	
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say2", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
}

StatsDisabled()
{
	if (db == INVALID_HANDLE) {
		return true;
	}
	return false;
}

public GetClientPoints(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (!client || hndl == INVALID_HANDLE) {
		return;
	}

	while (SQL_FetchRow(hndl)) {
		ClientPoints[client] = SQL_FetchInt(hndl, 0);
	}
}

public GetRankTotal(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE) {
		return;
	}

	while (SQL_FetchRow(hndl)) {
		RankTotal = SQL_FetchInt(hndl, 0);
	}
}

public GetClientRank(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (!client || hndl == INVALID_HANDLE) {
		return;
	}

	while (SQL_FetchRow(hndl)) {
		ClientRank[client] = SQL_FetchInt(hndl, 0);
	}
}

public Action:TimertyGetClientRank(Handle:timer, any:client)
{
	if (!client || StatsDisabled()) {
		return Plugin_Stop;
	}

	if (!IsClientInGame(client)) {
		return Plugin_Stop;
	}

	if (IsFakeClient(client)) {
		return Plugin_Stop;
	}

	decl String:query[82];
	Format(query, sizeof(query), "SELECT COUNT(*) FROM stats WHERE points >=%i", ClientPoints[client]);
	SQL_TQuery(db, GetClientRank, query, client);
	return Plugin_Stop;
}

public KnowRankPoints(client)
{
	if (!client || StatsDisabled()) {
		return;
	}

	if (!IsClientInGame(client)) {
		return;
	}

	if (IsFakeClient(client)) {
		return;
	}

	decl String:SteamID[30];
	GetClientAuthString(client, SteamID, sizeof(SteamID));

	decl String:query[105];
	Format(query, sizeof(query), "SELECT COUNT(*) FROM stats");
	SQL_TQuery(db, GetRankTotal, query, client);
	Format(query, sizeof(query), "SELECT points FROM stats WHERE steamid = '%s'", SteamID);
	SQL_TQuery(db, GetClientPoints, query, client);
	CreateTimer(0.6, TimertyGetClientRank, client);
	return;
}

public Action:Callvote_keyboard(client, args)
{
	return Plugin_Handled;
}

public Action:Callvote_Handler(client, args)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client)) {
		return Plugin_Handled;
	}

	if (ClientRank[client] < 51) {
		return Plugin_Continue;
	}

	return Plugin_Handled;
}

public updateptystatslayers()
{
	if (!IsServerProcessing()) {
		return;
	}

	new GetRealtyClientCount = 0;
	new typlayers = GetMaxClients();
	for (new i = 1; i <= typlayers; i++)
	{
		if (IsValidEntity(i) && IsClientInGame(i) && !IsFakeClient(i)) {
			GetRealtyClientCount++;
			CheckPlayerDB(i);
		}
	}

	return;
}

public Action:TimedRemovetystats(Handle:timer, any:client)
{
	updateptystatslayers();
	return Plugin_Stop;
}

public Action:Event_RoundStart(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
	CreateTimer(17.0, TimedRemovetystats);
	CreateTimer(40.0, TimedRemovetystats);
	CreateTimer(85.0, TimedRemovetystats);
	return Plugin_Continue;
}

public OnClientPostAdminCheck(client)
{
	if (IsFakeClient(client)) {
		return;
	}

	ClientPoints[client] = 0;
	ClientRank[client] = 100;
	CreateTimer(1.0, Timedtyclient, client);
}

public Action:Timedtyclient(Handle:timer, any:client)
{
	if (!client || !IsClientInGame(client)) {
		return Plugin_Stop;
	}

	if (IsFakeClient(client)) {
		return Plugin_Stop;
	}

	if (StatsDisabled()) {
		return Plugin_Stop;
	}

	CheckPlayerDB(client);
	CreateTimer(4.5, RankConnect, client);
	return Plugin_Stop;
}

public Action:RankConnect(Handle:timer, any:client)
{
	if (!client || !IsClientInGame(client)) {
		return Plugin_Stop;
	}

	if (IsFakeClient(client)) {
		return Plugin_Stop;
	}

	cmd_ShowRank(client, 0);

	return Plugin_Stop;
}

public Action:RanktyConnect(Handle:timer, any:client)
{
	if (IsClientInGame(client) && !IsFakeClient(client))
	{
		if (GetClientTeam(client) == 2) {
			if (IsPlayerAlive(client)) {
				if (ClientPoints[client] >= 320000)
					SetEntityRenderColor(client, 0, 0, 0, 255);
				else if (ClientPoints[client] >= 160000)
					SetEntityRenderColor(client, 153, 0, 0, 255);
				else if (ClientPoints[client] >= 80000)
					SetEntityRenderColor(client, 255, 51, 204, 255);
				else if (ClientPoints[client] >= 40000)
					SetEntityRenderColor(client, 164, 79, 25, 255);
				else if (ClientPoints[client] >= 20000)
					SetEntityRenderColor(client, 0, 153, 51, 255);
				else if (ClientPoints[client] >= 10000)
					SetEntityRenderColor(client, 0, 51, 255, 255);
				else if (ClientPoints[client] >= 5000)
					SetEntityRenderColor(client, 0, 204, 255, 255);
				else
					return Plugin_Stop;
			}
		}
	}

	return Plugin_Stop;
}

public ConnectDB()
{
	if (SQL_CheckConfig("l4d2stats")) {
		new String:Error[256];
		db = SQL_Connect("l4d2stats", true, Error, sizeof(Error));

		if (db == INVALID_HANDLE) {
			LogError("连接数据库失败,错误: %s", Error);
		}
		else {
			SendSQLUpdate("SET NAMES 'utf8'");
		}
	}
	else {
		LogError("databases.cfg missing 'l4d2stats' entry!");
	}
}

CheckPlayerDB(client)
{
	if (!client || StatsDisabled()) {
		return;
	}

	if (!IsClientInGame(client)) {
		return;
	}

	if (!IsClientConnected(client)) {
		return;
	}

	if (IsFakeClient(client)) {
		return;
	}

	decl String:SteamID[30];
	GetClientAuthString(client, SteamID, sizeof(SteamID));

	decl String:query[110];
	Format(query, sizeof(query), "SELECT steamid FROM stats WHERE steamid = '%s'", SteamID);
	SQL_TQuery(db, InsertPlayerDB, query, client);
	KnowRankPoints(client);
	CreateTimer(1.2, RanktyConnect, client);
	return;
}

public InsertPlayerDB(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client = data;
	if (!client || hndl == INVALID_HANDLE) {
		return;
	}

	if (!IsClientInGame(client)) {
		return;
	}

	if (!SQL_GetRowCount(hndl)) {
		new String:SteamID[30];
		GetClientAuthString(client, SteamID, sizeof(SteamID));
		new String:query[95];
		Format(query, sizeof(query), "INSERT IGNORE INTO stats SET steamid = '%s'", SteamID);
		SQL_TQuery(db, SQLErrorCheckCallback, query);
	}

	UpdatePlayer(client);
	return;
}

public SendSQLUpdate(String:query[])
{
	if (db == INVALID_HANDLE) {
		return;
	}

	SQL_TQuery(db, SQLErrorCheckCallback, query);
}

public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (db == INVALID_HANDLE) {
		return;
	}

	if(!StrEqual("", error)) {
		LogError("SQL Error: %s", error);
	}
}

public UpdatePlayer(client)
{
	if (!IsClientConnected(client)) {
		return;
	}

	decl String:SteamID[30];
	GetClientAuthString(client, SteamID, sizeof(SteamID));

	new String:tname[90];
	GetClientName(client, tname, 30);
	ReplaceString(tname, 30, "<", "");
	ReplaceString(tname, 30, ">", "");
	ReplaceString(tname, 30, "?", "");
	ReplaceString(tname, 30, ";", "");
	ReplaceString(tname, 30, "`", "");
	ReplaceString(tname, 30, "'", "");
	ReplaceString(tname, 30, "/", "");
	ReplaceString(tname, 30, "-", "");
	ReplaceString(tname, 30, "%", "");
	ReplaceString(tname, 30, "&", "");

	decl String:query[172];
	Format(query, sizeof(query), "UPDATE stats SET lastontime = '%i', name = '%s' WHERE steamid = '%s'", GetTime(), tname, SteamID);
	SendSQLUpdate(query);
	return;
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	//new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	//new victim = GetEventInt(event, "userid");
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (StatsDisabled()) {
		return Plugin_Continue;
	}
	
	if (!attacker) {
		return Plugin_Continue;
	}

	if (attacker == victim) {
		return Plugin_Continue;
	}

	if (!IsValidEntity(attacker)) {
		return Plugin_Continue;
	}

	if (IsFakeClient(attacker)) {
		return Plugin_Continue;
	}
	
	decl String:AttackerID[30];
	GetClientAuthString(attacker, AttackerID, sizeof(AttackerID));
	
	decl String:query[121];
	decl String:queryspecial[121];

	if(IsValidClient(victim))
	{
		if(GetClientTeam(victim) == 3)
		{
			new iClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
			if(IsValidClient(attacker))
			{
				if(GetClientTeam(attacker) == TEAM_SURVIVOR)	//玩家幸存者杀死特殊感染者
				{
					if(!IsFakeClient(attacker))
					{
						switch (iClass)
						{
							case 1:
							{
								Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerSmokerKill), AttackerID);
								SendSQLUpdate(query);
								
								Format(queryspecial, sizeof(queryspecial), "UPDATE stats SET smoker = smoker + 1 WHERE steamid = '%s'", AttackerID);
								SendSQLUpdate(queryspecial);
							}
							case 2:
							{
								Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerBoomerKill), AttackerID);
								SendSQLUpdate(query);
								
								Format(queryspecial, sizeof(queryspecial), "UPDATE stats SET boomer = boomer + 1 WHERE steamid = '%s'", AttackerID);
								SendSQLUpdate(queryspecial);
							}
							case 3:
							{
								Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerHunterKill), AttackerID);
								SendSQLUpdate(query);
							
								Format(queryspecial, sizeof(queryspecial), "UPDATE stats SET hunter = hunter + 1 WHERE steamid = '%s'", AttackerID);
								SendSQLUpdate(queryspecial);
							}
							case 4:
							{
								Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerSpitterKill), AttackerID);
								SendSQLUpdate(query);
								
								Format(queryspecial, sizeof(queryspecial), "UPDATE stats SET spitter = spitter + 1 WHERE steamid = '%s'", AttackerID);
								SendSQLUpdate(queryspecial);
							}
							case 5:
							{
								Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerJockeyKill), AttackerID);
								SendSQLUpdate(query);
								
								Format(queryspecial, sizeof(queryspecial), "UPDATE stats SET jockey = jockey + 1 WHERE steamid = '%s'", AttackerID);
								SendSQLUpdate(queryspecial);
							}
							case 6:
							{
								Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerChargerKill), AttackerID);
								SendSQLUpdate(query);
								
								Format(queryspecial, sizeof(queryspecial), "UPDATE stats SET charger = charger + 1 WHERE steamid = '%s'", AttackerID);
								SendSQLUpdate(queryspecial);
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:event_PlayerIncap(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new userid = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!Attacker) {
		return Plugin_Continue;
	}

	if (Attacker == userid) {
		return Plugin_Continue;
	}

	if (GetClientTeam(userid) != 2) {
		return Plugin_Continue;
	}

	if (StatsDisabled()) {
		return Plugin_Continue;
	}

	decl String:AttackerID[30];
	GetClientAuthString(userid, AttackerID, sizeof(AttackerID));

	decl String:query[121];
	decl String:queryspecial[121];
	
	Format(queryspecial, sizeof(queryspecial), "UPDATE stats SET incapacitated = incapacitated + 1 WHERE steamid = '%s'", AttackerID);
	
	Format(query, sizeof(query), "UPDATE stats SET points = points - %i WHERE steamid = '%s'", GetConVarInt(playerDown), AttackerID);
	SendSQLUpdate(query);
	SendSQLUpdate(queryspecial);
	return Plugin_Continue;
}

public Action:Infected_Killed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (StatsDisabled()) {
		return Plugin_Continue;
	}
	
	if (!attacker) {
		return Plugin_Continue;
	}

	if (!IsValidEntity(attacker)) {
		return Plugin_Continue;
	}

	if (IsFakeClient(attacker)) {
		return Plugin_Continue;
	}
	
	decl String:AttackerID[30];
	GetClientAuthString(attacker, AttackerID, sizeof(AttackerID));
	
	decl String:query[121];
	decl String:queryadd[121];
	
	if(attacker > 0)
	{
		if(GetClientTeam(attacker)==2 && !IsFakeClient(attacker))
		{
			CommonKill[attacker] += 1;
			//PrintToChat(attacker, "杀敌数: %d", CommonKill[attacker]);
			new updatekill = GetRandomInt(5,10);
			if(CommonKill[attacker] == updatekill)
			{
				Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerCommonKill), AttackerID);
				Format(queryadd, sizeof(queryadd), "UPDATE stats SET common = common + %i WHERE steamid = '%s'", updatekill, AttackerID);
				
				SendSQLUpdate(query);
				SendSQLUpdate(queryadd);
				CommonKill[attacker] = 0;
				//PrintToChat(attacker, "重设0");
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_TankDeath(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
	if (StatsDisabled()) {
		return Plugin_Continue;
	}
	
	for (new i = 1; i <= MaxClients; i++) 
	{
		if (!i) {
			return Plugin_Continue;
		}

		if (!IsValidEntity(i)) {
			return Plugin_Continue;
		}

		if (IsFakeClient(i)) {
			return Plugin_Continue;
		}
		
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i)) 
		{	
			decl String:AttackerID[30];
			GetClientAuthString(i, AttackerID, sizeof(AttackerID));
	
			decl String:query[121];
			decl String:queryadd[121];
			
			Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerTankKill), AttackerID);
			SendSQLUpdate(query);
			
			Format(queryadd, sizeof(queryadd), "UPDATE stats SET tank = tank + 1 WHERE steamid = '%s'", AttackerID);
			SendSQLUpdate(queryadd);
		}
	}
	return Plugin_Continue;
}

public Action:event_HealPlayer(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Recepient = GetClientOfUserId(GetEventInt(event, "subject"));
	new Giver = GetClientOfUserId(GetEventInt(event, "userid"));

	if (Recepient == Giver) {
		return Plugin_Continue;
	}

	if (IsFakeClient(Recepient) || IsFakeClient(Giver)) {
		return Plugin_Continue;
	}

	if (StatsDisabled()) {
		return Plugin_Continue;
	}
	
	decl String:GiverID[30];
	GetClientAuthString(Giver, GiverID, sizeof(GiverID));
	
	decl String:queryspecial[121];
	Format(queryspecial, sizeof(queryspecial), "UPDATE stats SET heal = heal + 1 WHERE steamid = '%s'", GiverID);
	SendSQLUpdate(queryspecial);

	decl String:query[121];
	Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerHeal), GiverID);
	SendSQLUpdate(query);
	return Plugin_Continue;
}

public Action:event_DefibPlayer(Handle:event, const String:name[], bool:dontBroadcast)
{
	new Recipient = GetClientOfUserId(GetEventInt(event, "subject"));
	new Giver = GetClientOfUserId(GetEventInt(event, "userid"));

	if (Recipient == Giver) {
		return Plugin_Continue;
	}

	if (StatsDisabled()) {
		return Plugin_Continue;
	}

	decl String:GiverID[30];
	GetClientAuthString(Giver, GiverID, sizeof(GiverID));

	decl String:query[121];
	Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerDefibrillated), GiverID);
	SendSQLUpdate(query);
	
	decl String:queryspecial[121];
	Format(queryspecial, sizeof(queryspecial), "UPDATE stats SET defibrillated = defibrillated + 1 WHERE steamid = '%s'", GiverID);
	SendSQLUpdate(queryspecial);
	return Plugin_Continue;
}

public Action:Event_ReviveSuccess(Handle:event, const String:name[], bool:dontBroadcast)
{
	new target = GetClientOfUserId(GetEventInt(event, "subject"));
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (target == client) {
		return Plugin_Continue;
	}

	if (IsFakeClient(target)) {
		return Plugin_Continue;
	}

	if (StatsDisabled()) {
		return Plugin_Continue;
	}

	decl String:GiverID[30];
	GetClientAuthString(client, GiverID, sizeof(GiverID));

	decl String:query[121];
	decl String:queryadd[121];
	
	Format(query, sizeof(query), "UPDATE stats SET points = points + %i WHERE steamid = '%s'", GetConVarInt(playerRevive), GiverID);
	Format(queryadd, sizeof(queryadd), "UPDATE stats SET revive = revive + 1 WHERE steamid = '%s'", GiverID);
	SendSQLUpdate(query);
	return Plugin_Continue;
}

public RankPanelHandler(Handle:menu, MenuAction:action, param1, param2)
{
}

public Action:TimerDisplayRank(Handle:timer, any:client)
{
	if (!client || !IsClientInGame(client)) {
		return Plugin_Stop;
	}

	if (IsFakeClient(client)) {
		return Plugin_Stop;
	}

	new Handle:RankPanel = CreatePanel();
	new String:Value[MAX_LINE_WIDTH];

	Format(Value, sizeof(Value), "%N 的数据统计:", client);
	DrawPanelText(RankPanel, Value);

	Format(Value, sizeof(Value), "目前排名: %i / 总玩家数 %i", ClientRank[client], RankTotal);
	DrawPanelText(RankPanel, Value);

	Format(Value, sizeof(Value), "总积分: %i", ClientPoints[client]);
	DrawPanelText(RankPanel, Value);
	
	Format(Value, sizeof(Value), "输入 !nextrank 查看离前一排名玩家的积分差距");
	DrawPanelText(RankPanel, Value);
	
	Format(Value, sizeof(Value), "输入 !top10 查看 TOP10 玩家");
	DrawPanelText(RankPanel, Value);

	DrawPanelItem(RankPanel, "关闭");
	SendPanelToClient(RankPanel, client, RankPanelHandler, 20);
	CloseHandle(RankPanel);

	return Plugin_Stop;
}

public Action:cmd_ShowRank(client, args)
{
	if (!client || !IsClientInGame(client)) {
		return Plugin_Continue;
	}

	if (IsFakeClient(client)) {
		return Plugin_Continue;
	}

	if (StatsDisabled()) {
		PrintToChat(client,"数据库维护中暂停数据统计,请等待恢复");
		return Plugin_Handled;
	}

	KnowRankPoints(client);
	CreateTimer(1.2, TimerDisplayRank, client);
	return Plugin_Handled;
}

public DisplayTop10(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (!client || hndl == INVALID_HANDLE) {
		return;
	}

	new String:Name[35];
	new Handle:Top10Panel = CreatePanel();
	new String:Value[MAX_LINE_WIDTH];
	new points = 0;
	new number = 0;
	SetPanelTitle(Top10Panel, "Top 10 玩家");

	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 0, Name, sizeof(Name));
		points = SQL_FetchInt(hndl, 1);

		number++;
		Format(Value, sizeof(Value), "第 %i 名:   %s   总积分: %i", number, Name, points);
		DrawPanelText(Top10Panel, Value);
	}

	DrawPanelItem(Top10Panel, "关闭");
	SendPanelToClient(Top10Panel, client, RankPanelHandler, 30);
	CloseHandle(Top10Panel);
}

public Action:cmd_ShowTop10(client, args)
{
	if (!client || !IsClientInGame(client)) {
		return Plugin_Continue;
	}

	if (IsFakeClient(client)) {
		return Plugin_Continue;
	}

	if (StatsDisabled()) {
		PrintToChat(client,"数据库维护中暂停数据统计,请等待恢复");
		return Plugin_Handled;
	}

	decl String:query[89];
	Format(query, sizeof(query), "SELECT name, points FROM stats ORDER BY points DESC LIMIT 10");
	SQL_TQuery(db, DisplayTop10, query, client);
	return Plugin_Handled;
}

public DisplayNextRank(Handle:owner, Handle:hndl, const String:error[], any:client)
{
	if (!client || hndl == INVALID_HANDLE) {
		return;
	}

	new Points;
	while (SQL_FetchRow(hndl)) {
		Points = SQL_FetchInt(hndl, 0);
	}

	new Handle:NextRankPanel = CreatePanel();
	new String:Value[MAX_LINE_WIDTH];
	SetPanelTitle(NextRankPanel, "离下一个积分排名差距 :");

	if (ClientRank[client] == 1) {
		Format(Value, sizeof(Value), "你已经是第一名了");
		DrawPanelText(NextRankPanel, Value);
	}
	else {
		Format(Value, sizeof(Value), "还需要: %i 积分", (Points - ClientPoints[client]));
		DrawPanelText(NextRankPanel, Value);
	}

	DrawPanelItem(NextRankPanel, "关闭");
	SendPanelToClient(NextRankPanel, client, RankPanelHandler, 30);
	CloseHandle(NextRankPanel);
}

public Action:TimerDisplayNextRank(Handle:timer, any:client)
{
	if (!client || !IsClientInGame(client)) {
		return Plugin_Stop;
	}

	if (IsFakeClient(client)) {
		return Plugin_Stop;
	}

	if (StatsDisabled()) {
		return Plugin_Stop;
	}

	decl String:SteamID[30];
	GetClientAuthString(client, SteamID, sizeof(SteamID));

	decl String:query[150];
	Format(query, sizeof(query), "SELECT points FROM stats WHERE points > %i AND steamid <> '%s' ORDER BY points LIMIT 1", ClientPoints[client], SteamID);
	SQL_TQuery(db, DisplayNextRank, query, client);
	return Plugin_Stop;
}

public Action:cmd_NextRank(client, args)
{
	if (!client || !IsClientInGame(client)) {
		return Plugin_Continue;
	}

	if (IsFakeClient(client)) {
		return Plugin_Continue;
	}

	if (StatsDisabled()) {
		PrintToChat(client,"数据库维护中暂停数据统计,请等待恢复");
		return Plugin_Handled;
	}

	KnowRankPoints(client);
	CreateTimer(1.2, TimerDisplayNextRank, client);
	return Plugin_Handled;
}

public Action:Command_Say(client,args)
{
	decl String:query[105];
	decl String:pName[MAX_NAME_LENGTH];
	decl String:pText[192];
	
	decl String:SteamID[30];
	GetClientAuthString(client, SteamID, sizeof(SteamID));

	new bool:isDead = !IsPlayerAlive(client);
	
	GetClientName(client, pName, sizeof(pName));
	GetCmdArgString(pText, sizeof(pText));
	StripQuotes(pText);	
	
	if (StatsDisabled()) {
		return Plugin_Continue;
	}
	else
	{
		Format(query, sizeof(query), "SELECT points FROM stats WHERE steamid = '%s'", SteamID); 
		SQL_TQuery(db, GetClientPoints, query, client);
		
		if(pText[0] == '/' || pText[0] == '!')
		{
			return Plugin_Handled;
		}

		if(ClientPoints[client] <= 200)
		{
			if (!isDead)
			{
				CPrintToChatAll("{olive}[新兵] {blue}%s: {default}%s", pName, pText);
			}
			else
			{
				CPrintToChatAll("*死亡* {olive}[新兵] {blue}%s: {default}%s", pName, pText);
			}
			return Plugin_Handled;
		}
		if(ClientPoints[client] > 200 && ClientPoints[client] <= 500)
		{
			if (!isDead)
			{
				CPrintToChatAll("{olive}[二等兵] {blue}%s: {default}%s", pName, pText);
			}
			else
			{
				CPrintToChatAll("*死亡* {olive}[二等兵] {blue}%s: {default}%s", pName, pText);
			}
			return Plugin_Handled;
		}
		if(ClientPoints[client] > 500 && ClientPoints[client] <= 1000)
		{
			if (!isDead)
			{
				CPrintToChatAll("{olive}[一等兵] {blue}%s: {default}%s", pName, pText);
			}
			else
			{
				CPrintToChatAll("*死亡* {olive}[一等兵] {blue}%s: {default}%s", pName, pText);
			}
			return Plugin_Handled;
		}
		if(ClientPoints[client] > 1000 && ClientPoints[client] <= 2500)
		{
			if (!isDead)
			{
				CPrintToChatAll("{green}[下士] {blue}%s: {default}%s", pName, pText);
			}
			else
			{
				CPrintToChatAll("*死亡* {green}[下士] {blue}%s: {default}%s", pName, pText);
			}
			return Plugin_Handled;
		}
		if(ClientPoints[client] > 2500 && ClientPoints[client] <= 7500)
		{
			if (!isDead)
			{
				CPrintToChatAll("{green}[中士] {blue}%s: {default}%s", pName, pText);
			}
			else
			{
				CPrintToChatAll("*死亡* {green}[中士] {blue}%s: {default}%s", pName, pText);
			}
			return Plugin_Handled;
		}
		if(ClientPoints[client] > 7500 && ClientPoints[client] <= 15000)
		{
			if (!isDead)
			{
				CPrintToChatAll("{green}[上士] {blue}%s: {default}%s", pName, pText);
			}
			else
			{
				CPrintToChatAll("*死亡* {green}[上士] {blue}%s: {default}%s", pName, pText);
			}
			return Plugin_Handled;
		}
		if(ClientPoints[client] > 15000 && ClientPoints[client] <= 30000)
		{
			if (!isDead)
			{
				CPrintToChatAll("{lightgreen}[少尉] {blue}%s: {default}%s", pName, pText);
			}
			else
			{
				CPrintToChatAll("*死亡* {lightgreen}[少尉] {blue}%s: {default}%s", pName, pText);
			}
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}