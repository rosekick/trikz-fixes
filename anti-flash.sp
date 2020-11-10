#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>

#define PLUGIN_VERSION "1.4"

new Handle:g_hLife = INVALID_HANDLE;
new Handle:g_hEntities = INVALID_HANDLE;
new Handle:g_hTimerDisable = INVALID_HANDLE;

new Float:g_fLife;


new Handle:timers[MAXPLAYERS+1];
new bool:cegado[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	author = "Franc1sco franug, Twisted|Panda, Ciallo",
	description = "Prevent the flash on a flashbang.",
	version = PLUGIN_VERSION,
}

public OnPluginStart()
{
	CreateConVar("sm_csgo_anti_team_flash_version", PLUGIN_VERSION, "CS:GO Anti Team Flash: Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hLife = CreateConVar("csgo_anti_team_flash_life", "2.0", "If enabled and csgo_anti_team_flash_none is enabled, this is the lifetime of the flashbang before it is deleted.", FCVAR_NONE, true, 0.0);
	AutoExecConfig(true, "csgo_anti_team_flash");

	HookEvent("flashbang_detonate", Event_OnFlashExplode, EventHookMode_Pre);
	HookEvent("player_spawn", Event_OnPlayerSpawn);

	HookConVarChange(g_hLife, OnSettingsChange);

	g_hEntities = CreateArray(2);
}

public OnPluginEnd()
{
	ClearArray(g_hEntities);
}

public OnMapEnd()
{
	if(g_hTimerDisable != INVALID_HANDLE && CloseHandle(g_hTimerDisable))
	g_hTimerDisable = INVALID_HANDLE;
	
	ClearArray(g_hEntities);
}

public OnMapStart()
{
	Void_SetDefaults();
}

public OnClientDisconnect(client)
{
	cegado[client] = false;
	if(timers[client] != INVALID_HANDLE)
	{
		KillTimer(timers[client]);
		timers[client] = INVALID_HANDLE;
	}
}

public OnEntityCreated(entity, const String:classname[])
{
	if(StrEqual(classname, "flashbang_projectile"))
		CreateTimer(0.1, Timer_Create, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Event_OnFlashExplode(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(0.0, Pasado);
}

public Action:Pasado(Handle:timer)
{
	if(GetArraySize(g_hEntities))
		RemoveFromArray(g_hEntities, 0);
}

public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;
		
	cegado[client] = false;
	
	if(timers[client] != INVALID_HANDLE)
	{
		KillTimer(timers[client]);
		timers[client] = INVALID_HANDLE;
	}
	
	return Plugin_Continue;
}

public Action:Timer_Flash(Handle:timer)
{
	g_hTimerDisable = INVALID_HANDLE;
}

public Action:Timer_Destroy(Handle:timer, any:ref)
{
	new entity = EntRefToEntIndex(ref);
	if(entity != INVALID_ENT_REFERENCE)
		AcceptEntityInput(entity, "Kill");
}

public Action:Timer_Create(Handle:timer, any:ref)
{
	new entity = EntRefToEntIndex(ref);
	if(entity != INVALID_ENT_REFERENCE)
	{
		SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);  
		CreateTimer((g_fLife - 0.1), Timer_Destroy, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
}

Void_SetDefaults()
{
	g_fLife = GetConVarFloat(g_hLife);
}

public OnSettingsChange(Handle:cvar, const String:oldvalue[], const String:newvalue[])
{
	if(cvar == g_hLife)
		g_fLife = StringToFloat(newvalue);
}