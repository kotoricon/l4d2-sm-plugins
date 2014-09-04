#include <sourcemod>
#include <sdktools>
#include <adminmenu>

#define DEBUG 0
#define PLUGIN_VERSION "2.5"
#define CVAR_FLAGS FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define MAXLENGTH 128

#define SURVIVOR 2
#define INFECTED 3

#define SMOKER	1
#define BOOMER	2
#define HUNTER	3
#define SPITTER		4
#define JOCKEY		5
#define CHARGER	6
#define WITCH		7
#define TANK		8

#define UNLOCK 0
#define LOCK 1

new playerWarnings[MAXPLAYERS];
new trollerWarnings[MAXPLAYERS];
new maxWarningTime = 5;
new maxTWarningTime = 5;

new String:oldKeyName[32];
new String:ChoosedMenu[MAXPLAYERS+1][56]

/* TopMenu Handle */
new Handle:hAdminMenu = INVALID_HANDLE;

new Handle:LocalTimer = INVALID_HANDLE;

new Handle:sm_ar_announce = INVALID_HANDLE;
new Handle:sm_ar_enable = INVALID_HANDLE;
new Handle:sm_ar_infected_enable = INVALID_HANDLE;
new Handle:sm_ar_lock_tankalive = INVALID_HANDLE;
new Handle:sm_ar_door_minsinfected = INVALID_HANDLE;
new Handle:sm_ar_door_maxsinfected = INVALID_HANDLE;

new Handle:l4d_together_enable;
new Handle:l4d_together_loner_range; 

new Handle:l4d_together_loner_punish; 
new Handle:l4d_punish_intervual_min;
new Handle:l4d_punish_intervual_max;

/* Lock flag */
new SafetyLock;
//new bool:isEnd = true;

/* Keyman's ID */
new idKeyman = 0;

/* Flag to start working */
new LeftSafe = 0;
new Started[MAXPLAYERS + 1];
new HumanMoved = 0;

/* Goal door ID */
new idGoal = 0;
new RunIdGoal = 0;

/* Sound file */
new String:SoundNotice[MAXLENGTH] = "doors/latchlocked2.wav";
new String:SoundDoorOpen[MAXLENGTH] = "doors/door_squeek1.wav";
new String:SoundDoorSpawn[MAXLENGTH] = "music/gallery_music.mp3";

public Plugin:myinfo = 
{
	name = "[L4D2] Anti-Runner System",
	author = "ztar, mod by Pescoxa",
	description = "Only Keyman can open saferoom door.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=123058"
}

public OnPluginStart()
{
	decl String:gameMod[32];
	GetGameFolderName(gameMod, sizeof(gameMod));
	if(!StrEqual(gameMod, "left4dead2", false))
	{
		SetFailState("Anti-Runner System supports L4D2 only.");
	}

	LeftSafe = 0;
	SetStarted(0);
	
	LoadTranslations("common.phrases");
	LoadTranslations("l4d2_sm_anti-runner.phrases");

	RegAdminCmd("sm_key", Command_Key, ADMFLAG_CUSTOM1);

	sm_ar_announce = CreateConVar("sm_ar_announce","1", "Announce plugin info (0:OFF 1:ON)", CVAR_FLAGS);
	sm_ar_door_minsinfected = CreateConVar("sm_ar_door_minsinfected","1", "Minnum of door keeper infected", CVAR_FLAGS);
	sm_ar_door_maxsinfected = CreateConVar("sm_ar_door_maxsinfected","3", "Maxnum of door keeper infected", CVAR_FLAGS);
	sm_ar_enable = CreateConVar("sm_ar_enable", "1", "Enable plugin (0:OFF 1:ON)", CVAR_FLAGS);

	sm_ar_infected_enable = CreateConVar("sm_ar__infected_enable", "0", "Enable door infected spawn? (0:OFF 1:ON)", CVAR_FLAGS);

	l4d_together_enable= 		CreateConVar("l4d_together_enable", "1", " 0:diable  , 1: enable");
 	l4d_together_loner_range=	CreateConVar("l4d_together_loner_range", "4000.0", "if some one away from his teamate, he is the loner"); 
	
	l4d_together_loner_punish= 	CreateConVar("l4d_together_loner_punish", "1", "0:diable, 1:enable, spawn infected to punish loner");
	l4d_punish_intervual_min= 	CreateConVar("l4d_together_loner_punish_intervual_min", "10.0", " seconds");	
	l4d_punish_intervual_max= 	CreateConVar("l4d_together_loner_punish_intervual_max", "20.0", " seconds");

	HookConVarChange(sm_ar_enable, CvarChanged_sm_ar_enable);
	
	sm_ar_lock_tankalive = CreateConVar("sm_ar_lock_tankalive","1", "Lock door if any Tank is alive (0:OFF 1:ON)", CVAR_FLAGS);
	
	CreateConVar("sm_ar_colors","x01\x01 - x02\x02 - x03\x03 - x04\x04 - x05\x05", "Colors", CVAR_FLAGS);
	
	HookEvent("player_death", Event_Player_Death);
	HookEvent("player_spawn", player_spawn);
	HookEvent("player_use", Event_Player_Use, EventHookMode_Post);
	HookEvent("round_start", Event_Round_Start, EventHookMode_Post);
	HookEvent("round_end", Event_Round_End);
	HookEvent("player_team", Event_Join_Team, EventHookMode_Post);
	HookEvent("player_left_checkpoint", Event_Left_CheckPoint, EventHookMode_Post);
	RegConsoleCmd("sm_alone", sm_alone);

	ResetAllState();
				
	/*Menu Handler */
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	
	AutoExecConfig(true, "l4d2_sm_anti-runner");
	
	CreateConVar("sm_ar_version", PLUGIN_VERSION, "[L4D2] Anti-Runner System", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_NOTIFY);
}

new PlayerCompanionCount[MAXPLAYERS+1];
new PlayerClosestCompanionCount[MAXPLAYERS+1]; 
new Float:PlayerAloneStartTime[MAXPLAYERS+1];
new Float:PlayerSpawnTime[MAXPLAYERS+1];
new Float:PlayerSpawnIntervual[MAXPLAYERS+1];
new bool:Msg[MAXPLAYERS+1];
new bool:dooropend = true;
new PlayerIndex=0; 
new SurviorCount=0;

public Action:player_spawn(Handle:hEvent, const String:strName[], bool:DontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid")); 
	if(client>0)
	{
 
		PlayerCompanionCount[client]=1;
		PlayerClosestCompanionCount[client]=1;
		PlayerAloneStartTime[client]=GetEngineTime(); 
		PlayerSpawnTime[client]=GetEngineTime(); 
		PlayerSpawnIntervual[client]=0.0;
		Msg[client]=true;
	}
}

public SetStarted(Value)
{
  new maxplayers = GetMaxClients();
  for (new i = 1; i <= maxplayers; i++)
  	Started[i] = Value;
}

public HasGoal()
{
	if (GetConVarInt(sm_ar_enable) == 1)
	{
		if (idGoal == -1)
		{
			return false;
		}
		else
		{
			return true;
		}
	}
	else
	{
		return false;
	}
}

public IsValidMode()
{
	new String:gmode[32];
	GetConVarString(FindConVar("mp_gamemode"), gmode, sizeof(gmode));
	
	decl String:CurrentMap[64];
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));

	new ret;
	ret = false;
	
	if (GetConVarInt(sm_ar_enable) == 1  && (!StrEqual(CurrentMap, "c10m4_mainstreet")))
	{
		if ((strcmp(gmode, "versus", false) == 0) || (strcmp(gmode, "teamversus", false) == 0) || (strcmp(gmode, "mutation12", false) == 0))
		{
			ret = true;
		}
		else 
		{
			if ((strcmp(gmode, "coop", false) == 0) || strcmp(gmode, "realism", false) == 0)
			{
				ret = true;
			}
			else
			{
				ret = false;
			}
		}
	}
	else
	{
		ret = false;
	}
	
	if (ret)
	{
		InitDoor();
		ret = HasGoal();
	}
	
	return ret;
	
}

public StopTimer()
{
	if (LocalTimer != INVALID_HANDLE)
	{
		KillTimer(LocalTimer);
		LocalTimer = INVALID_HANDLE;
	}
}

public OnClientPutInServer(client)
{
	if(!IsValidEntity(client))
		return;
		
	if((client == 0) || (IsFakeClient(client)))
		return;
	
	/* Announce about this plugin */
	if (GetConVarInt(sm_ar_announce))
	{
		CreateTimer(20.0, TimerAnnounce, client);
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN: MENU
///////////////////////////////////////////////////////////////////////////////////////////////////
public OnAdminMenuReady(Handle:topmenu)
{
	if (topmenu == hAdminMenu)
	{
		return;
	}

	hAdminMenu = topmenu;

	new TopMenuObject:menu_category = AddToTopMenu(hAdminMenu, "sm_ars_topmenu", TopMenuObject_Category, Handle_Category, INVALID_TOPMENUOBJECT);

	if (menu_category != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hAdminMenu, "sm_ars_ed_menu", TopMenuObject_Item, AdminMenu_EnableDisable, menu_category, "sm_ars_ed_menu", ADMFLAG_SLAY);
		AddToTopMenu(hAdminMenu, "sm_ars_ck_menu", TopMenuObject_Item, AdminMenu_ChangeKey, menu_category, "sm_ars_ck_menu", ADMFLAG_SLAY);
	}
}

public Handle_Category(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	switch(action)
	{
		case TopMenuAction_DisplayTitle:
			Format(buffer, maxlength, "%T", "WhatDoYouWant", param);
		case TopMenuAction_DisplayOption:
			Format( buffer, maxlength, "%T", "AntiRunnerSystem", param);
	}
}

public AdminMenu_EnableDisable(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (GetConVarInt(sm_ar_enable) == 1)
		{
			Format(buffer, maxlength, "%T", "Disable", param);
		}
		else
		{
			Format(buffer, maxlength, "%T", "Enable", param);
		}
	}
	else if( action == TopMenuAction_SelectOption)
	{
		if (GetConVarInt(sm_ar_enable) == 1)
		{
			SetConVarInt(sm_ar_enable, 0);
		}
		else
		{
			SetConVarInt(sm_ar_enable, 1);
		}
		DisplayTopMenu(hAdminMenu, param, TopMenuPosition_LastCategory);
	}
}

public AdminMenu_ChangeKey(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "ChooseKeyMan", param);
	}
	else if( action == TopMenuAction_SelectOption)
	{
		DisplayChangeKeyMenu(param);
	}
}

DisplayChangeKeyMenu(client)
{
	
	if (IsValidMode())
	{
	
		new Handle:menu = CreateMenu(MenuHandler_PlayerSelect)

		SetMenuTitle(menu, "%T", "SelectAPlayer", client)
		SetMenuExitBackButton(menu, true)

		new max_clients = GetMaxClients();
		decl String:user_id[12];
		decl String:display[MAX_NAME_LENGTH+12];
		
		decl String:aux[255];
		Format(aux, sizeof(aux),"%T", "Random", client)
		AddMenuItem(menu, "*", aux);
		Format(aux, sizeof(aux),"%T", "Refresh", client)
		AddMenuItem(menu, "", aux);
		
		for (new i = 1; i <= max_clients; i++)
		{
		
			if (!IsValidEntity(i))
			{
				continue;
			}
			
			if (!IsClientConnected(i) || IsClientInKickQueue(i))
			{
				continue;
			}
			
			if (IsFakeClient(i))
			{
				continue;
			}
			
			if (!IsClientInGame(i))
			{
				continue;
			}
			
			if (!IsPlayerAlive(i))
			{
				continue;
			}
			
			if (GetClientTeam(i) != SURVIVOR)
			{
				continue;
			}
			
			if (i == idKeyman)
			{
				Format(display, sizeof(display), "%T", "Current", client, i);
			}
			else
			{
				Format(display, sizeof(display), "%N", i);
			}
			IntToString(i, user_id, sizeof(user_id));
			AddMenuItem(menu, user_id, display);
		}
	
		ChoosedMenu[client] = "ChangeKeyMenu";
		DisplayMenu(menu, client, MENU_TIME_FOREVER)
		
	}
	
	else
	{
		DisplayTopMenu(hAdminMenu, client, TopMenuPosition_LastCategory);
	}
		
}

stock ChoosedMenuHistory(param1)
{
	if (strcmp(ChoosedMenu[param1], "ChangeKeyMenu") == 0)
	{
		DisplayTopMenu(hAdminMenu, param1, TopMenuPosition_LastCategory);
	}
}

public MenuHandler_PlayerSelect(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{	
				ChoosedMenuHistory(param1);
			}
		}
		case MenuAction_Select:
		{
			new String:info[56];
			GetMenuItem(menu, param2, info, sizeof(info));
      
			if (strcmp(info, "*") == 0)
			{
				if (IsClientInGame(param1))
				{
					FakeClientCommandEx(param1, "sm_key %s", info);
				}
      }
			else if (strcmp(info, "") == 0)
			{
				if (IsClientInGame(param1))
				{
					DisplayChangeKeyMenu(param1);
					return;
				}
      }
			else
			{
				if (IsClientInGame(param1))
				{
					new client = StringToInt(info)
					FakeClientCommandEx(param1, "sm_key \"%N\"", client);
				}
			}
			ChoosedMenuHistory(param1);

		}
	}
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// END: MENU
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN: EVENTS TO CHANGE KEYMAN
///////////////////////////////////////////////////////////////////////////////////////////////////
public CvarChanged_sm_ar_enable(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (GetConVarInt(sm_ar_enable) == 0)
	{
		idKeyman = 0;
		if (idGoal != -1)
		{
			SafetyLock = UNLOCK;
			ControlDoor(idGoal, UNLOCK);
		}
	}
	else
	{
		if (idGoal == -1)
		{
			if (RunIdGoal == 0)
			{
				InitDoor();
			}
		}
		else
		{
			SafetyLock = LOCK;
			ControlDoor(idGoal, LOCK);
		}
		if (idKeyman == 0)
		{
			if (LeftSafe == 1)
			{
				idKeyman = SelectKeymanEx();
				WarnAdmins(idKeyman);
			}
		}
	}
}

/* KEYMAN CHANGED TEAM */
public Event_Join_Team(Handle:event, String:event_name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	new clientTeam = GetEventInt(event, "team");
	new bool:isBot = GetEventBool(event, "isbot");
	
	if(!IsValidEntity(client))
		return;

	if (LeftSafe == 0)
		SetStarted(0);
	
	if (!IsValidMode())
		return;
	
	if(isBot == true)
		return;
		
	if(((clientTeam != SURVIVOR) && (client == idKeyman)) || (idKeyman == 0))
	{
		if (LocalTimer == INVALID_HANDLE)
		{
			if (idKeyman != 0)
			{
				if(GetConVarInt(sm_ar_announce))
					for (new i = 1; i <= GetMaxClients(); i++)
						if ((IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i)))
								PrintToChat(i, "\x04[防恶意火箭流系统] \x03%T", "JoinTeam", i);
			}
			StoreOldKeyManName();
			LocalTimer = CreateTimer(1.0, SelectKeyman);
		}
	}
}

/* KEYMAN IS DEAD */
public Action:Event_Player_Death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client>0)
	{
		PlayerCompanionCount[client]=1;
		PlayerClosestCompanionCount[client]=1;
		PlayerAloneStartTime[client]=GetEngineTime(); 
		PlayerSpawnTime[client]=GetEngineTime(); 
		PlayerSpawnIntervual[client]=0.0;
		Msg[client]=true;
	}

	if (!IsValidMode())
		return Plugin_Continue;

	new victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if((victim == 0) || (IsFakeClient(victim)))
		return Plugin_Continue;

	/* If victim was Keyman, Re-select Keyman */
	if((victim == idKeyman))
	{
		if (LocalTimer == INVALID_HANDLE)
		{
			if(GetConVarInt(sm_ar_announce))
				for (new i = 1; i <= GetMaxClients(); i++)
						if ((IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i)))
								PrintToChat(i, "\x04[防恶意火箭流系统] \x03%T", "Dead", i);
			StoreOldKeyManName();
			LocalTimer = CreateTimer(2.0, SelectKeyman);
		}
	}
	return Plugin_Continue;
}

/* KEYMAN DISCONNECTED */
public OnClientDisconnect(client)
{
	if (!IsValidMode())
		return;

	if(!IsValidEntity(client))
		return;
	
	if((client == 0) || (IsFakeClient(client)))
		return;
	
	/* If Keyman disconnect, Re-select Keyman */
	if((client == idKeyman))
	{
		if (LocalTimer == INVALID_HANDLE)
		{
			if(GetConVarInt(sm_ar_announce))
				for (new i = 1; i <= GetMaxClients(); i++)
						if ((IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i)))
								PrintToChat(i, "\x04[防恶意火箭流系统] \x03%T", "Disconnected", i);
			StoreOldKeyManName();
			LocalTimer = CreateTimer(2.0, SelectKeyman);
		}
	}
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// END: EVENTS TO CHANGE KEYMAN
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN: EVENTS THAT CONTROLS THE PLUGIN
///////////////////////////////////////////////////////////////////////////////////////////////////
public OnMapStart()
{
	/* Precache */
	PrecacheSound(SoundNotice, true);
	PrecacheSound(SoundDoorOpen, true);
	PrecacheSound(SoundDoorSpawn, true);

	ResetAllState();
	CreateTimer(0.1, TimerUpdatePlayer, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Event_Round_Start(Handle:event, const String:name[], bool:dontBroadcast)
{
	StopTimer();
	idKeyman = 0;
	LeftSafe = 0;
	SetStarted(0);
	HumanMoved = 0;
	idGoal = -1;
	RunIdGoal = 0;
	SafetyLock = UNLOCK;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (buttons & IN_MOVELEFT || buttons & IN_BACK || buttons & IN_FORWARD || buttons & IN_MOVERIGHT || buttons & IN_USE)
	{
		if ((client > 0) && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client) && (GetClientTeam(client) == SURVIVOR))
		{
			if (!IsFakeClient(client))
				HumanMoved = 1;
			if (HumanMoved == 1)
			{
				Started[client] = 1;
			}
		}
	}
	return Plugin_Continue;
}

public Event_Left_CheckPoint(Handle:event, const String:name[], bool:dontBroadcast)
{
	new entity = GetEventInt(event, "entityid");
	//new area = GetEventInt(event, "area");
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if ((Started[client] > 0) && (client > 0) && (entity == 0) && (LeftSafe == 0))
	{
		CreateTimer(GetRandomFloat(5.0,20.0), OnLeftSafeArea, client);
	}
}

public Action:OnLeftSafeArea(Handle:timer, any:client)
{
	decl String:CurrentMap[64];
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));

	if (client == 0 || !IsClientInGame(client))
		return Plugin_Stop;

	if (GetClientTeam(client) != SURVIVOR)
	{
		Started[client] = 0;
		return Plugin_Stop;
	}

	if (LeftSafe == 1)
		return Plugin_Stop;

	LeftSafe = 1;
	SetStarted(1);
	
	if (!IsValidMode())
		return Plugin_Stop;
		
	if(GetConVarInt(sm_ar_announce))
	{	
		for (new i = 1; i <= GetMaxClients(); i++)
		{
			if ((IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i)))
			{
				if ((client != 0))
				{
					if (IsFakeClient(client))
					{
						PrintToChat(i,"\x04[防恶意火箭流系统] \x01%T", "BOTLeftSafeArea", i, client);
					}
					else
					{
						PrintToChat(i,"\x04[防恶意火箭流系统] \x01%T", "PlayerLeftSafeArea", i, client);
					}
				}
			}
		}
		playerWarnings[client]=0;
		trollerWarnings[client]=0;
		// if(StrEqual(CurrentMap, "c1m1_hotel") || StrEqual(CurrentMap, "c2m1_highway") || StrEqual(CurrentMap, "c3m1_plankcountry") || StrEqual(CurrentMap, "c4m1_milltown_a") || StrEqual(CurrentMap, "c5m1_waterfront") || StrEqual(CurrentMap, "c6m1_riverbank") || StrEqual(CurrentMap, "c7m1_docks") || StrEqual(CurrentMap, "c8m1_apartment") || StrEqual(CurrentMap, "c9m1_alleys") || StrEqual(CurrentMap, "c10m1_caves") || StrEqual(CurrentMap, "c11m1_greenhouse") || StrEqual(CurrentMap, "c12m1_hilltop") || StrEqual(CurrentMap, "c13m1_alpinecreek"))
		// {
			//isEnd=false;
			//playerWarnings[client]=0;
		// }else{
			//isEnd=true;
			// new admindata = GetUserFlagBits(client);
			// SetUserFlagBits(client, ADMFLAG_ROOT);
			// new spawnflags = GetCommandFlags("director_force_panic_event");
			// SetCommandFlags("director_force_panic_event", spawnflags & ~FCVAR_CHEAT);
			// FakeClientCommand(client, "director_force_panic_event");
			// SetCommandFlags("director_force_panic_event", spawnflags|FCVAR_CHEAT);
			// SetUserFlagBits(client, admindata);
			//playerWarnings[client]=0;
		// }
	}
	
	if(idKeyman == 0 || !IsValidEntity(idKeyman) || !IsClientInGame(idKeyman) || !IsPlayerAlive(idKeyman) || IsFakeClient(idKeyman) || (GetClientTeam(idKeyman) == INFECTED))
	{
		if (LocalTimer == INVALID_HANDLE)
		{
			if(GetConVarInt(sm_ar_announce))
				for (new i = 1; i <= GetMaxClients(); i++)
						if ((IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i)))
								PrintToChat(i, "\x04[防恶意火箭流系统] \x03%T", "Reset", i);
			StoreOldKeyManName();
			LocalTimer = CreateTimer(1.0, SelectKeyman);
		}
	}

	return Plugin_Stop;

}

public Action:Event_Player_Use(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new Entity = GetEventInt(event, "targetid");
	
	if(client == 0)
		return Plugin_Continue;
	
	if (IsFakeClient(client))
		return Plugin_Continue;
	
	if(IsValidEntity(Entity) && (SafetyLock == UNLOCK) && ((Entity == idGoal) || !IsValidMode()))
	{
		new String:entname[MAXLENGTH];
		if(GetEdictClassname(Entity, entname, sizeof(entname)))
		{
			/* Saferoom door */
			if(StrEqual(entname, "prop_door_rotating_checkpoint"))
			{
				/* is valid, in game and alive */
				if(IsClientInGame(client) && IsPlayerAlive(client))
				{
					if(GetClientTeam(client)==2 && dooropend == false)
					{
						trollerWarnings[client]+= 1;
						if(trollerWarnings[client] == (maxWarningTime * 2))
						{
							KickClient(client, "玩门很好玩? 单机去吧");
							PrintToChatAll("\x04%N\x01 \x03因为恶意玩门已被自动踢出\x01!",client);
						}
						else
						{
							PrintToChat(client,"\x03注意:\x01 你因为恶意玩门已被赋予了 \x04%d\x01 警告,如果超过 \x04%d\x01 次会被\x03自动踢出\x01", trollerWarnings[client] , (maxTWarningTime * 2));
						}
					}
				}
			}
		}
	}
	if(IsValidEntity(Entity) && (SafetyLock == LOCK) && ((Entity == idGoal) || !IsValidMode()))
	{
		new String:entname[MAXLENGTH];
		if(GetEdictClassname(Entity, entname, sizeof(entname)))
		{
			/* Saferoom door */
			if(StrEqual(entname, "prop_door_rotating_checkpoint"))
			{
				for (new i = 1; i <= GetMaxClients(); i++)
				{
					/* is valid, in game and alive */
					if(IsValidEntity(i) && IsClientInGame(i) && IsPlayerAlive(i))
					{
						/* Detect if there is a Tank */
						decl String:ModelName[128];
						GetEntPropString(i, Prop_Data, "m_ModelName", ModelName, 128);
						new bool:isTank = false;
						if (StrContains(ModelName, "hulk.mdl", true) != -1) { isTank = true; }
						
						if((isTank) && GetConVarInt(sm_ar_lock_tankalive) && IsValidMode())
						{
							EmitSoundToAll(SoundNotice, Entity);
							PrintHintText(client, "%T", "TankAlive", client);
							return Plugin_Continue;
						}
					}
				}
				
				AcceptEntityInput(Entity, "Lock");
				SetEntProp(Entity, Prop_Data, "m_hasUnlockSequence", LOCK);

				/* test if the current key man is valid, case not, select other */				
				if(((idKeyman == 0) || !IsValidEntity(idKeyman) || !IsClientInGame(idKeyman) || !IsPlayerAlive(idKeyman) || IsFakeClient(idKeyman)) && IsValidMode())
				{
					if(GetConVarInt(sm_ar_announce))
						for (new i = 1; i <= GetMaxClients(); i++)
							if ((IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i)))
									PrintToChat(i, "\x04[防恶意火箭流系统] \x03%T", "Invalid", i);
									idKeyman = SelectKeymanEx();
				}
				
				/* test if who is opennig the door is the keyman and open it */
				if((client == idKeyman) || !IsValidMode())
				{
					EmitSoundToAll(SoundDoorOpen, Entity);
					SafetyLock = UNLOCK;
					ControlDoor(Entity, UNLOCK);
					ScreenFade(client, 200, 0, 0, 200, 100, 1);
					if(GetConVarInt(sm_ar_announce) && IsValidMode())
					{
						for (new i = 1; i <= GetMaxClients(); i++)
							if ((IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i)))
									PrintToChat(i, "\x04[防恶意火箭流系统] \x03%T", "Arrived", i, idKeyman);
									CreateTimer(5.0, UpdateDoorStatus);
					}
					
					if(GetConVarInt(sm_ar_infected_enable)==1)
					{
						new minnum = GetConVarInt(sm_ar_door_minsinfected);
						new maxnum = GetConVarInt(sm_ar_door_maxsinfected);
						new count = GetRandomInt(minnum,maxnum);
						new type = GetRandomInt(1,6);
						new tankspawn = GetRandomInt(1,9);

						for(new i = 1; i <= count ; i++)
						{
							switch(type)
							{
								case 1:
								{
									new admindata = GetUserFlagBits(client);
									SetUserFlagBits(client, ADMFLAG_ROOT);
									new spawnflags = GetCommandFlags("z_spawn");
									SetCommandFlags("z_spawn", spawnflags & ~FCVAR_CHEAT);
									FakeClientCommand(client, "z_spawn hunter");
									SetCommandFlags("z_spawn", spawnflags|FCVAR_CHEAT);
									SetUserFlagBits(client, admindata);
								}
								case 2:
								{
									new admindata = GetUserFlagBits(client);
									SetUserFlagBits(client, ADMFLAG_ROOT);
									new spawnflags = GetCommandFlags("z_spawn");
									SetCommandFlags("z_spawn", spawnflags & ~FCVAR_CHEAT);
									FakeClientCommand(client, "z_spawn smoker");
									SetCommandFlags("z_spawn", spawnflags|FCVAR_CHEAT);
									SetUserFlagBits(client, admindata);
								}
								case 3:
								{
									new admindata = GetUserFlagBits(client);
									SetUserFlagBits(client, ADMFLAG_ROOT);
									new spawnflags = GetCommandFlags("z_spawn");
									SetCommandFlags("z_spawn", spawnflags & ~FCVAR_CHEAT);
									FakeClientCommand(client, "z_spawn boomer");
									SetCommandFlags("z_spawn", spawnflags|FCVAR_CHEAT);
									SetUserFlagBits(client, admindata);
								}
								case 4:
								{
									new admindata = GetUserFlagBits(client);
									SetUserFlagBits(client, ADMFLAG_ROOT);
									new spawnflags = GetCommandFlags("z_spawn");
									SetCommandFlags("z_spawn", spawnflags & ~FCVAR_CHEAT);
									FakeClientCommand(client, "z_spawn jockey");
									SetCommandFlags("z_spawn", spawnflags|FCVAR_CHEAT);
									SetUserFlagBits(client, admindata);
								}
								case 5:
								{
									new admindata = GetUserFlagBits(client);
									SetUserFlagBits(client, ADMFLAG_ROOT);
									new spawnflags = GetCommandFlags("z_spawn");
									SetCommandFlags("z_spawn", spawnflags & ~FCVAR_CHEAT);
									FakeClientCommand(client, "z_spawn spitter");
									SetCommandFlags("z_spawn", spawnflags|FCVAR_CHEAT);
									SetUserFlagBits(client, admindata);
								}
								case 6:
								{
									new admindata = GetUserFlagBits(client);
									SetUserFlagBits(client, ADMFLAG_ROOT);
									new spawnflags = GetCommandFlags("z_spawn");
									SetCommandFlags("z_spawn", spawnflags & ~FCVAR_CHEAT);
									FakeClientCommand(client, "z_spawn charger");
									SetCommandFlags("z_spawn", spawnflags|FCVAR_CHEAT);
									SetUserFlagBits(client, admindata);
								}
							}
						}

						new admindata = GetUserFlagBits(client);
						SetUserFlagBits(client, ADMFLAG_ROOT);
						new spawnflags = GetCommandFlags("z_spawn");
						SetCommandFlags("z_spawn", spawnflags & ~FCVAR_CHEAT);
						FakeClientCommand(client, "z_spawn witch");
						SetCommandFlags("z_spawn", spawnflags|FCVAR_CHEAT);
						SetUserFlagBits(client, admindata);

						if(tankspawn==1)
						{
							new admindata1 = GetUserFlagBits(client);
							SetUserFlagBits(client, ADMFLAG_ROOT);
							new spawnflags1 = GetCommandFlags("z_spawn");
							SetCommandFlags("z_spawn", spawnflags1 & ~FCVAR_CHEAT);
							FakeClientCommand(client, "z_spawn tank");
							SetCommandFlags("z_spawn", spawnflags1|FCVAR_CHEAT);
							SetUserFlagBits(client, admindata1);

							PrintToChatAll("\x03全体运气不佳,出现\x01\x04Tank\x01看门!");
						}

						for (new i = 1; i <= GetMaxClients(); i++)
						{
							if(GetClientTeam(i)==3 && IsFakeClient(i))
							{
								if(GetEntProp(i, Prop_Send, "m_zombieClass") == CHARGER || GetEntProp(i, Prop_Send, "m_zombieClass") == SPITTER || GetEntProp(i, Prop_Send, "m_zombieClass") == JOCKEY
									 || GetEntProp(i, Prop_Send, "m_zombieClass") == SMOKER || GetEntProp(i, Prop_Send, "m_zombieClass") == HUNTER || GetEntProp(i, Prop_Send, "m_zombieClass") == BOOMER
									 || GetEntProp(i, Prop_Send, "m_zombieClass") == TANK || GetEntProp(i, Prop_Send, "m_zombieClass") == WITCH)
								{
									/* Get entity position */
									decl Float:pos[3];
									GetClientAbsOrigin(client, pos);
									pos[2] += 20;
									
									/* Teleport after setting up */
									TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
									EmitSoundToAll(SoundDoorSpawn, i);
								}
							}
						}
					}
				}
				else if (IsValidMode())
				{
					/* Notify client who is Keyman */
					EmitSoundToAll(SoundNotice, Entity);
					for (new i = 1; i <= GetMaxClients(); i++)
						if ((IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i)))
							PrintHintText(i, "%T", "DenyWarning", i, idKeyman);
					// if(WitchKeeperspawned==false)
					// {
						// for(new i = 1; i <=2; i++)
						// {
							// new admindata = GetUserFlagBits(client);
							// SetUserFlagBits(client, ADMFLAG_ROOT);
							// new spawnflags = GetCommandFlags("z_spawn");
							// SetCommandFlags("z_spawn", spawnflags & ~FCVAR_CHEAT);
							// FakeClientCommand(client, "z_spawn witch");
							// SetCommandFlags("z_spawn", spawnflags|FCVAR_CHEAT);
							// SetUserFlagBits(client, admindata);

							// decl Float:pos[3];
							// GetClientAbsOrigin(client, pos);
							// pos[2] += 20;
							
							playerWarnings[client]++;
							if(playerWarnings[client] == maxWarningTime)
							{
								KickClient(client, "你因为恶意操作安全门刷怪已被自动踢出");
								PrintToChatAll("\x04玩家\x01 %N \x04\x01\x03因为恶意操作安全门已被自动踢出\x01!",client);
							}
							else
							{
								PrintToChat(client,"\x03注意:\x01 你因为恶意操作安全门已被赋予了 \x04%d\x01 警告,如果超过 \x04%d\x01 次会被\x03自动踢出\x01!", playerWarnings[client], maxWarningTime);
							}	
							// TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
						// }
					// }
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:UpdateDoorStatus(Handle:timer)
{
	dooropend = false;
	PrintToChatAll("\x05防 \x04恶意开关安全门系统\x03 已开始进行工作\x01");
}

public Action:Event_Round_End(Handle:event, const String:name[], bool:dontBroadcast)
{
	StopTimer();
	idKeyman = 0;
	LeftSafe = 0;
	SetStarted(0);
	HumanMoved = 0;
	idGoal = -1;
	RunIdGoal = 0;
	SafetyLock = UNLOCK;

	ResetAllState();
	for (new i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == 3)
			{
				if (IsFakeClient(i))
				{
					KickClient(i);
				}
			}
		}
	}
	
	if(GetConVarInt(sm_ar_announce))
		if (IsValidMode())
			for (new i = 1; i <= GetMaxClients(); i++)
				if ((IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i)))
						PrintToChat(i, "\x04[防恶意火箭流系统] \x03%T", "SettingFree", i);
	
	return Plugin_Continue;
}

ResetAllState()
{  
	new Float:time=GetEngineTime();
	PlayerIndex=0;
	SurviorCount=0;
	for( new i=1; i<=MaxClients; i++)
	{ 		
 
		PlayerCompanionCount[i]=1; 
		PlayerClosestCompanionCount[i]=1;
		PlayerAloneStartTime[i]=time;
		PlayerSpawnTime[i]=time;
		PlayerSpawnIntervual[i]=0.0;
		Msg[PlayerIndex]=true;
	}
}

public Action:sm_alone(client,args)
{
	if(client>0)
	{
		for( new i=1; i<=MaxClients; i++)
		{
			if(IsClientInGame(i) && GetClientTeam(i)==2)
			{
				if(IsPlayerAlive(i) && GetEngineTime()-PlayerAloneStartTime[i]>5.0)
				{
					PrintToChatAll("%N", i);
				}
			}
			
		}
	}
}

public OnMapEnd(){
	LocalTimer = INVALID_HANDLE;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// END: EVENTS THAT CONTROLS THE PLUGIN
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN: KEYMAN SELECTION
///////////////////////////////////////////////////////////////////////////////////////////////////
public Action:SelectKeyman(Handle:timer, any:client)
{
	if (!IsValidMode())
		return Plugin_Stop;
		
	if (LeftSafe == 1) 
	{
		idKeyman = SelectKeymanEx();
	}
	LocalTimer = INVALID_HANDLE;
	return Plugin_Stop;
}

public SelectKeymanEx()
{

	if (!IsValidMode())
		return 0;

	new keyman = 0;
	new count = 0;
	new idAlive[MAXPLAYERS+1];
	
	/* See all clients */
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		/* is valid, in game, alive, and not bot */
		if(IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i) && !IsFakeClient(i))
		{
			/* Survivor team */
			if((GetClientTeam(i) == SURVIVOR))
			{
				idAlive[count] = i;
				count++;
				}
		}
	}
	
	if(count != 0) 
	{
		
		new key = GetRandomInt(0, count-1);
		
		/* Get Keyman ID */
		keyman = idAlive[key];
	
	}
	
	/* Only warn if the new KeyMan is different of the old one */
	if((keyman != idKeyman))
	{
		WarnAdmins(keyman);
	}
	
	return keyman;
	
}

/* If the KeyMan is not available, keep his name to show later */
public StoreOldKeyManName()
{
	if (idKeyman == 0)
	{
		oldKeyName = "";
	}
	else
	{
		GetClientName(idKeyman, oldKeyName, sizeof(oldKeyName));
	}
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// END: KEYMAN SELECTION
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN: WARNINGS
///////////////////////////////////////////////////////////////////////////////////////////////////
public Action:TimerAnnounce(Handle:timer, any:client)
{
	if(IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && GetConVarInt(sm_ar_announce))
	{
		if (IsValidMode())
		{
			PrintToChat(client,"\x04[防恶意火箭流系统] \x01%T\n\n", "WelcomeOn", client);
			PrintToChat(client,"\x05每隔30分钟就会因为游戏进度过慢自动创建惩罚\x03Tank\x01,\x03请注意过关效率!\x01");
			//isEnd = true;
		}
		else
		{
			PrintToChat(client,"\x04[防恶意火箭流系统] \x01%T\n\n", "WelcomeOff", client);
			//isEnd = false;
			return Plugin_Stop;
		}
	}
	
	WarnAdmin(idKeyman, client);
	return Plugin_Stop;
		
}

public WarnAdmin(keyman, i)
{

	if (keyman != 0)
	{
		if (!(IsValidEntity(keyman) && IsClientConnected(keyman) && IsClientInGame(keyman)))
		{
			keyman = 0;
		}
	}
	
	if (idKeyman != 0)
	{
		if (!(IsValidEntity(idKeyman) && IsClientConnected(idKeyman) && IsClientInGame(idKeyman)))
		{
			idKeyman = 0;
		}
	}
	
	if(IsValidEntity(i) && IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
	{
		
		if (!IsValidMode())
			return;

		new AdminId:AdminID = GetUserAdmin(i);
		if(AdminID != INVALID_ADMIN_ID)
		{
			if ((keyman == 0))
			{
				PrintToChat(i, "\x04[防恶意火箭流系统] \x01%T", "NoKeyMan", i);
			}
			else
			{
				if ((idKeyman == 0))
				{
					PrintToChat(i, "\x04[防恶意火箭流系统] \x01%T", "NewKeyMan", i, keyman);
				}
				else
				{
					if (idKeyman == keyman)
					{
						PrintToChat(i, "\x04[防恶意火箭流系统] \x01%T", "SameKeyMan", i, keyman);
					}
					else
					{
						if(StrEqual(oldKeyName, "", false))
						{
							PrintToChat(i, "\x04[防恶意火箭流系统] \x01%T", "NewKeyMan", i, keyman);
						}
						else
						{
							PrintToChat(i, "\x04[防恶意火箭流系统] \x01%T", "ChangeKeyMan", i, oldKeyName, keyman);
						}
					}
				}
			}
		}
	}
}

public WarnAdmins(keyman)
{

	if (!IsValidMode())
		return;

	//Avisa para os Admins quem é o KeyMan ************************************
	for(new i = 1 ; i <= GetMaxClients();i++)
	{
		WarnAdmin(keyman, i) 
	}
	//*************************************************************************
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// END: WARNINGS
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN: DOOR CONTROL
///////////////////////////////////////////////////////////////////////////////////////////////////
public InitDoor()
{
	if (RunIdGoal == 1)
		return;
		
	RunIdGoal = 1;
	
	if (idGoal != -1)
		return;
	
	new Entity = -1;
	while((Entity = FindEntityByClassname(Entity, "prop_door_rotating_checkpoint")) != -1)
	{
		if(GetEntProp(Entity, Prop_Data, "m_hasUnlockSequence") == UNLOCK)
		{
			idGoal = Entity;
			SafetyLock = LOCK;
			ControlDoor(idGoal, LOCK);
		}
	}

}

public ControlDoor(Entity, Operation)
{

	if(Operation == LOCK)
	{
		/* Close and lock */
		AcceptEntityInput(Entity, "Close");
		AcceptEntityInput(Entity, "Lock");
		AcceptEntityInput(Entity, "ForceClosed");
		SetEntProp(Entity, Prop_Data, "m_hasUnlockSequence", LOCK);
	}
	else if(Operation == UNLOCK)
	{
		/* Unlock and open */
		SetEntProp(Entity, Prop_Data, "m_hasUnlockSequence", UNLOCK);
		AcceptEntityInput(Entity, "Unlock");
		AcceptEntityInput(Entity, "ForceClosed");
		AcceptEntityInput(Entity, "Open");
	}
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// END: DOOR CONTROL
///////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////////
// BEGIN: COMMAND SM_KEY
///////////////////////////////////////////////////////////////////////////////////////////////////
public Action:Command_Key(client, args)
{

	if ((client == 0))
	{
		ReplyToCommand(client, "\x04[防恶意火箭流系统] \x01%T", "InGame" , client);
		return Plugin_Handled;
	}
	
	if (!IsValidMode())
	{
		ReplyToCommand(client, "\x04[防恶意火箭流系统] \x01%T", "ModeNotSupported", client);
		return Plugin_Handled;
	}
	
	if(args < 1)
	{
		ReplyToCommand(client, "\x04[防恶意火箭流系统] \x01%T", "Usage", client);
	}
	
	if(IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
	{
		new AdminId:AdminID = GetUserAdmin(client);
		if(AdminID != INVALID_ADMIN_ID)
		{
			if ((idKeyman == 0))
			{
				PrintToChat(client, "\x04[防恶意火箭流系统] \x01%T", "NoKeyMan", client);
			}
			else
			{
				PrintToChat(client, "\x04[防恶意火箭流系统] \x01%T", "KeyManIs", client, idKeyman);
			}
		}
	}
	
	if(args < 1)
	{
		return Plugin_Handled;
	}
	
	new String:Target[64];
	new WarnAgain = 1;
	GetCmdArg(1, Target, sizeof(Target));
	
	new targetclient = -1;
	StoreOldKeyManName();
	if (strcmp(Target, "*", false) == 0)
	{
		WarnAgain = 0;
		targetclient = SelectKeymanEx();
		if (targetclient == 0)
		{
			targetclient = -1;
		}
	}
	else
	{
		targetclient = FindClient(client,Target);
	}
	
	if (targetclient == -1)
	{
		ReplyToCommand(client, "\x04[防恶意火箭流系统] \x01%T", "PlayerNotFound", client);
		return Plugin_Handled;
	}
		
	if(IsValidEntity(targetclient) && IsClientConnected(targetclient) && IsClientInGame(targetclient) && IsPlayerAlive(targetclient) && !IsFakeClient(targetclient) && (GetClientTeam(targetclient) == SURVIVOR))
	{
		if (WarnAgain == 1)
		{
			WarnAdmins(targetclient);
		}
		idKeyman = targetclient;
		return Plugin_Handled;	
	}
	else
	{
		PrintToChat(client, "\x04[防恶意火箭流系统] \x01%T", "PlayerNotAvailable", client);
		return Plugin_Handled;
	}

}

public FindClient(client,String:Target[])
{
	new iNumClients = FindTarget(client, Target, false, false);
	
	if (iNumClients == -1)
	{
		return -1;
	}
	else if (!CanUserTarget(client, iNumClients))
	{
		return -1;
	}
	
	return iNumClients;
}
///////////////////////////////////////////////////////////////////////////////////////////////////
// END: COMMAND SM_KEY
///////////////////////////////////////////////////////////////////////////////////////////////////
public ScreenFade(target, red, green, blue, alpha, duration, type)
{
	new Handle:msg = StartMessageOne("Fade", target);
	BfWriteShort(msg, 500);
	BfWriteShort(msg, duration);
	if (type == 0)
		BfWriteShort(msg, (0x0002 | 0x0008));
	else
		BfWriteShort(msg, (0x0001 | 0x0010));
	BfWriteByte(msg, red);
	BfWriteByte(msg, green);
	BfWriteByte(msg, blue);
	BfWriteByte(msg, alpha);
	EndMessage();
}

public Action:TimerUpdatePlayer(Handle:timer, any:data)
{
	if(GetConVarInt(l4d_together_enable)==0)return Plugin_Continue;
	if(!NextPlayer())return Plugin_Continue; 
	decl Float:playerPos[3];
	decl Float:pos[3];
	GetClientEyePosition(PlayerIndex, playerPos);
	new playerCount=0;
	new Float:time=GetEngineTime();
	new closestCompanionCount=1;
	new companionCount=1;
	new Float:loner_rage=GetConVarFloat(l4d_together_loner_range);
	for( new i=1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i)==2 )
		{
			if(IsPlayerAlive(i))
			{
				playerCount++;
				if(i==PlayerIndex)continue;
				
				GetClientEyePosition(i, pos);
				new Float:dis=GetVectorDistance(pos, playerPos);
				//if(PlayerIndex==1)PrintToChatAll("%N dis %f, range %f",i, dis,loner_rage );
				if(dis<loner_rage)
				{
					companionCount++;
					 
				} 
				if(dis<=300.0)
				{
					closestCompanionCount++;
				}
			}  
		} 
	}  
	SurviorCount=playerCount;
	PlayerCompanionCount[PlayerIndex]=companionCount;
 	PlayerClosestCompanionCount[PlayerIndex]=closestCompanionCount; 
	if(companionCount>1)
	{		
		PlayerAloneStartTime[PlayerIndex]=time; 	
		Msg[PlayerIndex]=true;  
	} 	 
	else 
	{
		if(Msg[PlayerIndex])
		{
			PrintHintText(PlayerIndex, "[警告]: 你离你的队友太远即将被防恶意火箭流系统惩罚!"); 
		}
		Msg[PlayerIndex]=false;
	}
	
	if(SurviorCount>1 && time-PlayerAloneStartTime[PlayerIndex]>5.0 && GetConVarInt(l4d_together_loner_punish)==1)
	{  
		if(PlayerSpawnTime[PlayerIndex]+PlayerSpawnIntervual[PlayerIndex]<time)
		{ 
			CreateTimer(0.1, TimerPunishLoner, PlayerIndex, TIMER_FLAG_NO_MAPCHANGE);	 
			PlayerSpawnTime[PlayerIndex]=time;
			PlayerSpawnIntervual[PlayerIndex]=GetRandomFloat(GetConVarFloat(l4d_punish_intervual_min), GetConVarFloat(l4d_punish_intervual_max));			
		}		
	} 
	return Plugin_Continue;
}
public Action:TimerPunishLoner(Handle:timer, any:client)
{
	PunishLoner(client);
}
PunishLoner(client)
{
	if(IsClientInGame(client) && GetClientTeam(client)==2 && IsPlayerAlive(client) && !IsPlayerIncapped(client))
	{ 
		decl Float:hitpos[3];
		decl Float:pos[3];
		decl Float:angle[3];
		decl Float:vec[3];
		GetClientEyePosition(client, pos);
		GetClientEyeAngles(client , angle);
		angle[0]=-25.0;
		GetAngleVectors(angle,angle,NULL_VECTOR,NULL_VECTOR);
		NormalizeVector(angle, angle);
		ScaleVector(angle,-1.0);
		CopyVector( angle, vec );
		GetVectorAngles(angle,angle);
		
		new Handle:trace= TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelf, client); 
		if(TR_DidHit(trace))
		{	
			TR_GetEndPosition(hitpos, trace);
			NormalizeVector(vec,vec);
			ScaleVector(vec, -40.0);
			AddVectors(hitpos, vec, hitpos);
			
			new Float:d=GetVectorDistance(hitpos, pos); 
			if(d<200.0 && d>40.0)
			{ 
				SpawnInfected(hitpos);
			}
		}
		CloseHandle(trace);
	}
}
bool:IsPlayerIncapped(client)
{ 
	if (GetEntProp(client, Prop_Send, "m_isIncapacitated", 1)) return true;
	return false;
}
SpawnInfected(Float:pos[3])
{

	new bot = CreateFakeClient("Monster");
	if (bot > 0)	
	{		
		ChangeClientTeam(bot,3);  
		new random =0;
		
		decl bool:IsPalyerSI[MAXPLAYERS+1];
	 
		
		for(new i = 1; i <= MaxClients; i++)
		{	
			IsPalyerSI[i]=false;
			if(IsClientInGame(i) && IsPlayerAlive(i))
			{
				if(GetClientTeam(i)==3)
				{
					IsPalyerSI[i]=true;
				}
			}		 
		}
		
		random=GetRandomInt(1,4);
		decl String:siName[32]="";
		switch(random)
		{
			case 1: 
				siName="smoker";
			case 2:
			    siName="hunter";
			case 3:
				siName="jockey"; 
			case 4:
				siName="charger"; 
			
		} 
		
		SpawnCommand(bot, "z_spawn", siName);
		PrintToChatAll("\x03[提醒]\x01:\x05恶意火箭流的玩家即将受到惩罚\x04,请引以为戒\x01");
		new selected=0;
		for(new i = 1; i <= MaxClients; i++)
		{	
			if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i)==3)
			{
				if(!IsPalyerSI[i])
				{
					selected=i;
					break;
				} 
			}		 
		}
		if(selected>0)
		{
			TeleportEntity(selected, pos, NULL_VECTOR, NULL_VECTOR ); 
		} 
		
		Kickbot(INVALID_HANDLE, bot); 
	}	  
}
public Action:Kickbot(Handle:timer, any:client)
{
	if (IsClientInGame(client))
	{
		if (IsFakeClient(client))
		{
			KickClient(client);
		}
	}
}
public bool:TraceRayDontHitSelf (entity, mask, any:data)
{
	if(entity == data) 
	{
		return false; 
	}	
	return true;
}
CopyVector(Float:source[3], Float:target[3])
{
	target[0]=source[0];
	target[1]=source[1];
	target[2]=source[2];
}
bool:NextPlayer()
{
	new bool:find=false;
	for(new i=PlayerIndex+1; i<=MaxClients; i++)
	{
		if(IsClientInGame(i) )
		{
			if(GetClientTeam(i)==2)
			{
				if(IsPlayerAlive(i))
				{
					find=true;
					PlayerIndex=i;
					break;
				} 
			} 
		}  
	}
	if(!find)
	{
		PlayerIndex=0;
	}
	return find;
	 
}
public Action:TimerAjust(Handle:timer, any:data)
{
 
	return Plugin_Continue;   
}
 
SpawnCommand(client, String:command[], String:arguments[] = "")
{
	if (client)
	{ 
		new flags = GetCommandFlags(command);
		SetCommandFlags(command, flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "%s %s", command, arguments);
		SetCommandFlags(command, flags);
	}
}