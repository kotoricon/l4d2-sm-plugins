#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.0" 

public Plugin:myinfo = 
{ 
	name = "服务器改名插件", 
	author = "Kirisame", 
	description = "使服务器启动后自动设置中文服务器名称", 
	version = PLUGIN_VERSION, 
	url = "Undefined" 
} 

public OnPluginStart()    
{    
    RegAdminCmd("sm_namehost", Command_Namehost, ADMFLAG_RCON,"激活服务器中文名称");
}    
    
public Action:Command_Namehost(client, args)    
{
	ServerCommand("hostname \"超难多人战役#2 (新手勿入) \"");
}