#if defined _readyup_included_
  #endinput
#endif
#define _readyup_included_

public SharedPlugin:__pl_rup = 
{
	name = "readyup",
	file = "readyup.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

forward ReadyUp_FirstClientLoaded();
forward ReadyUp_AllClientsLoaded();
forward ReadyUp_ReadyUpStart();
forward ReadyUp_ReadyUpEnd();
forward ReadyUp_RoundIsOver(gamemode);
forward ReadyUp_CheckpointDoorStartOpened();
forward ReadyUp_CoopMapEnd();
forward ReadyUp_CampaignComplete();
forward ReadyUp_CoopMapFailed(gamemode);
forward ReadyUp_SaferoomLocked();
forward ReadyUp_IsClientLoaded(client);
forward ReadyUp_LoadFromConfig(Handle:key, Handle:value);
forward ReadyUp_ParseConfigFailed(String:config[], String:error[], bool:canRetry);

native bool:ReadyUp_IsTeamsFlipped();
native ReadyUp_ParseConfig(String:config[]);
native ReadyUp_GetGameMode();