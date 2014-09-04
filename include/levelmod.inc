#if defined _levelmod_included_
	#endinput
#endif
#define _levelmod_included_


#define LEVELMODAPIVERSION 2

/**
 * Get a clients level
 * 
 * @param iClient		The client to get the level from
 * @return			client level
 */
native lm_GetClientLevel(iClient);

/**
 * Sets a clients level
 *
 * @param iClient		The client to set the level to
 * @param iLevel		The value the level should be set to
 * @return			Nothing.
 */
native lm_SetClientLevel(iClient, iLevel);

/**
 * Get a clients xp
 *
 * @param iClient		The client to get the xp from
 * @return			client experience points
 */
native lm_GetClientXP(iClient);

/**
 * Sets a clients xp (automatically levels up accordingly)
 *
 * @param iClient		The client to set the xp to
 * @param iXP			The value the xp should be set to
 * @return			Nothing.
 */
native lm_SetClientXP(iClient, iXP);

/**
 * Get a clients next level up xp requirements
 *
 * @param iClient		The client to get the value from
 * @return			client next level up xp requirements
 */
native lm_GetClientXPNext(iClient);

/**
 * Gives Experience points to a client, automatically leveling up
 *
 * @param iClient		The client to give xp to
 * @param iXP			Amount of XP to give
 * @param iChannel		Hud-Channel to use (valid: 0 for primary, 1 for secondary)
 */
native lm_GiveXP(iClient, iXP, iChannel = 0);

/**
 * Gives levels to a client (shows level up notification)
 *
 * @param iClient		The client to give levels to
 * @param iLevels		Amount of levels to give the client
 */
native lm_GiveLevel(iClient, iLevel);

/**
 * Returns the amount of experience required to be a certain level 
 *
 * @param iLevel		Level to aquire
 * @return			amount of xp needed
 */
native lm_GetXpRequiredForLevel(iLevel);

/**
 * Returns the maximum level a player can get
 *
 * @return			the maximum level a player can get
 */
native lm_GetLevelMax();

/**
 * Returns the highest level a player who's currently on the server has reached
 *
 * @return			the highest level of a connected player
 */
native lm_GetLevelHighest();

/**
 * Returns the lowest level a player who's currently on the server has reached
 *
 * @return			the lowest level of a connected player
 */
native lm_GetLevelLowest();

native lm_ForceExpReqBase(iExpReqBase);
native lm_ForceExpReqMult(Float:fExpReqBase);
native lm_ForceLevelDefault(iExpReqBase);
native lm_ForceLevelMax(iExpReqBase);

/**
 * Returns True if levelmod is enabled
 *
 * @return			is levelmod enabled?
 */
native bool:lm_IsEnabled();

/**
 * Forwards when a client levels up
 *
 * @param iClient		The client who achieved a new level
 * @param iLevel		The level the client achieved
 * @param iAmount		The amount of levels the client achieved
 * @param bool:isLevelDown	This is true if the player leveledDown
 */
forward lm_OnClientLevelUp(iClient,iLevel, iAmount, bool:isLevelDown);

/**
 * Forwards when a client gains experience
 *
 * @param iClient		The client who gained experience points
 * @param iXP			The amount of xp the client got
 * @param iChannel		Hud-Channel being used (valid: 0 for primary, 1 for secondary)
 */
forward lm_OnClientExperience(iClient,iXP,iChannel);