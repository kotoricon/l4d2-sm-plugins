#if defined _gunxpmod_included_
  #endinput
#endif
#define _gunxpmod_included_

// Checks if user connected, whithout any errors.
#define IsValidClient(%1)  ( 1 <= %1 <= MaxClients && IsClientInGame(%1) )

// Checks if user alive, whithout any errors.
#define IsValidAlive(%1) ( 1 <= %1 <= MaxClients && IsClientInGame(%1) && IsPlayerAlive(%1) )

#define TEAM_SURVIVOR 2
#define TEAM_INFECTED 3
 
/**
 * Sets player's experience.
 *
 * @param id    An integer.
 * @param value    An integer.
 * @return        None.
 */
native set_p_xp( id, value );


/**
 * Gets player's experience.
 *
 * @param id    An integer.
 * @return        Returns player's carrying experience.
 */
native get_p_xp( id );


/**
 * Gets player's level.
 *
 * @param id    An integer.
 * @return        Returns player's level.
 */
native get_p_level( id );


/* Registers Unlock item */
public Handle:find_itemindex()
{
	decl String:name[64], String:pluginname[64];
	new Handle:iter = GetPluginIterator();
	new Handle:PluginID;
	GetPluginFilename( INVALID_HANDLE, pluginname, sizeof ( pluginname ) );
	
	while (MorePlugins(iter))
	{
		PluginID = ReadPlugin(iter);
	
		GetPluginFilename( PluginID, name, sizeof( name ) );
		
 		if(StrEqual(name, pluginname))
		{
 			CloseHandle(iter);
			return PluginID;
		}
	}
	
	CloseHandle(iter);

 	return INVALID_HANDLE;
}
public register_gxm_item(const String:item_name[], const String:item_desc[], item_cost, item_team)
{
	new Handle:item_index = find_itemindex()
	new Handle:itemplugin = FindPluginByFile( "gunxpmod_shop.smx" )
	new Function:itemregfunc = GetFunctionByName (itemplugin, "register_item_gxm");

	new temp = Call_StartFunction(itemplugin, itemregfunc);

	Call_PushCell(item_index)
	Call_PushString(item_name)
	Call_PushString(item_desc)
	Call_PushCell(item_cost)
	Call_PushCell(item_team)
	
	temp = Call_Finish();
	
	if( temp == -2 ) 
	{
		LogError ( "MAX_UNLOCKS are reached maximum limit!" );
		return 0;
	}

	return temp;
}