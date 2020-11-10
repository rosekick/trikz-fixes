#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <smlib>
#include <clientprefs>
#include <trikznobug>

#define PLUGIN_VERSION "1.3"

public Plugin:myinfo =
{
	name = "[Trikz] Menu",
	author = "ici, george, ciallo",
	version = PLUGIN_VERSION
};

new g_AmmoOffset = -1;
new m_hMyWeapons = -1;
new g_CollisionGroup = -1;
new g_iOffset;

new bool:g_bBlock[MAXPLAYERS+1];
new bool:g_bAutoSwitch[MAXPLAYERS+1];
new bool:g_bAutoFlash[MAXPLAYERS+1];
new bool:g_bSkyFix[MAXPLAYERS+1] = {true, ...};

new Handle:g_hBlockCookie = INVALID_HANDLE;
new Handle:g_hAutoSwitchCookie = INVALID_HANDLE;
new Handle:g_hAutoFlashCookie = INVALID_HANDLE;
new Handle:g_hSkyFixCookie = INVALID_HANDLE;

public OnPluginStart()
{
	g_CollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	if (g_CollisionGroup == -1) {
		SetFailState("[Trikz Menu] Failed to find m_CollisionGroup offset!");
	}
	
	g_AmmoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	if (g_AmmoOffset == -1) {
		SetFailState("[Trikz Menu] Failed to find m_iAmmo offset!");
	}
	
	m_hMyWeapons = FindSendPropInfo("CBasePlayer", "m_hMyWeapons");  
	if (m_hMyWeapons == -1) {
		SetFailState("[Trikz Menu] Failed to find m_hMyWeapons offset!");
	}

	g_iOffset = FindSendPropInfo("CBaseCombatWeapon", "m_hOwnerEntity");
	if (g_iOffset == -1) {
		SetFailState("[Trikz Menu] Failed to find m_hOwnerEntity offset!");
	}
	
	g_hBlockCookie = RegClientCookie("TrikzMenu_Block", "Trikz Menu - Block Cookie", CookieAccess_Private);
	g_hAutoSwitchCookie = RegClientCookie("TrikzMenu_AutoSwitch", "Trikz Menu - AutoSwitch Cookie", CookieAccess_Private);
	g_hAutoFlashCookie = RegClientCookie("TrikzMenu_AutoFlash", "Trikz Menu - AutoFlash Cookie", CookieAccess_Private);
	g_hSkyFixCookie = RegClientCookie("TrikzMenu_SkyFix", "Trikz Menu - SkyFix Cookie", CookieAccess_Private);
	
	RegConsoleCmd("sm_trikz", SM_Trikz, "Opens the trikz menu.");
	RegConsoleCmd("sm_t", SM_Trikz, "Opens the trikz menu.");
	RegConsoleCmd("sm_switch", SM_Switch, "Toggles Block.");
	RegConsoleCmd("sm_block", SM_Switch, "Toggles Block.");
	RegConsoleCmd("sm_sky", SM_Sky, "Toggles SkyFix.");
	RegConsoleCmd("sm_glock", GiveGlock, "Gives player glock");
    RegConsoleCmd("sm_usp", GiveUsp, "Gives player usp");
    RegConsoleCmd("sm_knife", GiveKnife, "Gives player knife");
	
	//HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void OnMapStart()
{
	if (FileExists("cfg/sourcemod/trikz/main.cfg"))
		ServerCommand("exec sourcemod/trikz/main.cfg");
	else
		SetFailState("<freak> cfg/sourcemod/trikz/main.cfg not found.");
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_PreThinkPost, OnClientPreThinkPost);
}

public OnClientPostAdminCheck(client)
{
	if (IsFakeClient(client)) return;
	CreateTimer(3.0, Timer_Message, GetClientUserId(client));
}

public Action:Timer_Message(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client)) return Plugin_Continue;
	
	PrintToChat(client, "[Trikz] Type !trikz to open up the menu.");
	return Plugin_Continue;
}

public OnClientCookiesCached(client)
{
	if (!IsFakeClient(client))
	{
		decl String:sValue[8];
		new cookie;
		
		GetClientCookie(client, g_hBlockCookie, sValue, sizeof(sValue));
		cookie = (sValue[0] != '\0' && StringToInt(sValue));
		g_bBlock[client] = bool:cookie;
		
		GetClientCookie(client, g_hAutoSwitchCookie, sValue, sizeof(sValue));
		cookie = (sValue[0] != '\0' && StringToInt(sValue));
		g_bAutoSwitch[client] = bool:cookie;
		
		GetClientCookie(client, g_hAutoFlashCookie, sValue, sizeof(sValue));
		cookie = (sValue[0] != '\0' && StringToInt(sValue));
		g_bAutoFlash[client] = bool:cookie;
		
		GetClientCookie(client, g_hSkyFixCookie, sValue, sizeof(sValue));
		cookie = (sValue[0] != '\0' && StringToInt(sValue));
		g_bSkyFix[client] = bool:cookie;
		Trikz_SkyFix(client, g_bSkyFix[client]);
		
		if (!g_bBlock[client] && IsClientInGame(client) && IsPlayerAlive(client))
		{
			SetEntData(client, g_CollisionGroup, 2, 4, true);
			SetAlpha(client, 100);
		}
	}
}

GiveWeapon(client, String:wep[])
{
    if(IsPlayerAlive(client))
	{
        new e_wep = GetPlayerWeaponSlot(client, 1);
        if(e_wep != -1){
            RemovePlayerItem(client, e_wep);
            AcceptEntityInput(e_wep, "Kill");
        }
        e_wep = GetPlayerWeaponSlot(client, 0);
        if(e_wep != -1){
            RemovePlayerItem(client, e_wep);
            AcceptEntityInput(e_wep, "Kill");
        }
        GivePlayerItem(client, wep, 0);
    }
}

public Action GiveGlock(client, args)
{
    GiveWeapon(client, "weapon_glock");
    return Plugin_Handled;
}

public Action GiveUsp(client, args)
{
    GiveWeapon(client, "weapon_usp_silencer");
    return Plugin_Handled;
}

public Action GiveKnife(client, args)
{
    GiveWeapon(client, "weapon_knife");
    return Plugin_Handled;
}

public Action:SM_Trikz(client, args)
{
	if (!client) {
		ReplyToCommand(client, "You cannot run this command through the server console.");
		return Plugin_Handled;
	}
	
	if (AreClientCookiesCached(client)) {
		OpenTrikzMenu(client);
	}
	return Plugin_Handled;
}

public Action:SM_Switch(client, args)
{
	if (!client) {
		ReplyToCommand(client, "You cannot run this command through the server console.");
		return Plugin_Handled;
	}
	
	if (AreClientCookiesCached(client)) {
		ToggleBlock(client);
	}
	return Plugin_Handled;
}

public Action:SM_Sky(client, args)
{
	if (!client) {
		ReplyToCommand(client, "You cannot run this command through the server console.");
		return Plugin_Handled;
	}
	
	if (AreClientCookiesCached(client)) {
		g_bSkyFix[client] = !g_bSkyFix[client];
		Trikz_SkyFix(client, g_bSkyFix[client]);
		
		if (g_bSkyFix[client]) {
			PrintToChat(client, "[Trikz] SkyFix is ON");
		} else {
			PrintToChat(client, "[Trikz] SkyFix is OFF");
		}
		
		SaveTrikzPref(client, 6);
	}
	return Plugin_Handled;
}

public Menu_Trikz(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2) {
			case 0:
			{
				g_bAutoFlash[param1] = !g_bAutoFlash[param1];
				if (g_bAutoFlash[param1]) {
					PrintToChat(param1, "[Trikz] AutoFlash is ON");
				} else {
					PrintToChat(param1, "[Trikz] AutoFlash is OFF");
				}
				if (g_bAutoFlash[param1] && (GetClientFlashBangs(param1) == 0)) {
					GivePlayerItem(param1, "weapon_flashbang");
				}
				SaveTrikzPref(param1, 3);
				OpenTrikzMenu(param1);
			}
			case 1:
			{
				g_bAutoSwitch[param1] = !g_bAutoSwitch[param1];
				if (g_bAutoSwitch[param1]) {
					PrintToChat(param1, "[Trikz] AutoSwitch is ON");
				} else {
					PrintToChat(param1, "[Trikz] AutoSwitch is OFF");
				}
				SaveTrikzPref(param1, 2);
				OpenTrikzMenu(param1);
			}
			case 2:
			{
				ToggleBlock(param1);
				OpenTrikzMenu(param1);
			}
			case 3:
			{
				g_bSkyFix[param1] = !g_bSkyFix[param1];
				Trikz_SkyFix(param1, g_bSkyFix[param1]);
				if (g_bSkyFix[param1]) {
					PrintToChat(param1, "[Trikz] SkyFix is ON");
				} else {
					PrintToChat(param1, "[Trikz] SkyFix is OFF");
				}
				SaveTrikzPref(param1, 6);
				OpenTrikzMenu(param1);
			}
		}
	}
	else if (action == MenuAction_End) CloseHandle(menu);
}

/* public Event_WeaponFire(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	decl String:weapon[32];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	if (StrEqual(weapon, "flashbang")) {
		if (g_bAutoFlash[client]) {
			GivePlayerItem(client, "weapon_flashbang");
			if (g_bAutoSwitch[client]) {
				RequestFrame(Timer_SelectFlash, client);
			}
		}
	}
} */

public void OnClientPreThinkPost(int client) {
	if(g_bAutoFlash[client]) {
		char sWeapon[64];
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		
		if(IsValidEdict(weapon)) {
			GetEdictClassname(weapon, sWeapon, 64);
			if(StrEqual(sWeapon, "weapon_flashbang")) {
				float fThrowTime = GetEntPropFloat(weapon, Prop_Send, "m_fThrowTime");
				
				if(fThrowTime > 0.0 && fThrowTime < GetGameTime()) {
					GivePlayerItem(client, "weapon_flashbang");
					
					if(g_bAutoSwitch[client]) {
						RequestFrame(Timer_SelectFlash, client);
					}
				}
			}
		}
	}
}

public void OnEntityCreated(int edict, const char[] classname) {
	if(IsValidEdict(edict)) {
		if(StrEqual(classname, "weapon_flashbang")) {
			CreateTimer(0.1, Timer_RemoveFlash, edict);
		}
	}
}

public Action Timer_RemoveFlash(Handle timer, any edict) {
	if(IsValidEdict(edict)) {
		char sEdictName[32];
		GetEdictClassname(edict, sEdictName, 32);
		if(StrEqual(sEdictName, "weapon_flashbang")) {
			if(GetEntDataEnt2(edict, g_iOffset) == -1) {
				AcceptEntityInput(edict, "kill");
			}
		}
	}
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client && IsClientInGame(client) && GetClientTeam(client) > 1) {
		if (AreClientCookiesCached(client)) {
			if (g_bBlock[client]) {
				SetAlpha(client, 255);
				SetEntData(client, g_CollisionGroup, 5, 4, true);
			} else {
				SetAlpha(client, 100);
				SetEntData(client, g_CollisionGroup, 2, 4, true);
			}
			
			if (g_bAutoFlash[client] && (GetClientFlashBangs(client) == 0)) {
				GivePlayerItem(client, "weapon_flashbang");
			}
		}
	}
}

public void Timer_SelectFlash(any:client)
{
	FakeClientCommand(client, "use weapon_knife");
	FakeClientCommand(client, "use weapon_flashbang");
}

public Action:CS_OnCSWeaponDrop(client, weaponIndex)
{
    if(weaponIndex != -1)
    {
        AcceptEntityInput(weaponIndex, "KillHierarchy");
        AcceptEntityInput(weaponIndex, "Kill");
    }
}

/* public Action:CS_OnCSWeaponDrop(client, weaponIndex)
{
	PrintToChatAll("client %i drop %i", client, weaponIndex);
	return Plugin_Continue;
} */

public Action:Timer_TestBlock(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!client 
	|| !IsClientInGame(client) 
	|| !IsPlayerAlive(client)) return Plugin_Continue;
	
	if (g_bBlock[client]) {
		SetAlpha(client, 255);
		SetEntData(client, g_CollisionGroup, 5, 4, true);
	} else {
		SetAlpha(client, 100);
		SetEntData(client, g_CollisionGroup, 2, 4, true);
	}
	
	return Plugin_Continue;
}

stock OpenTrikzMenu(client)
{
	new Handle:hMenu = CreateMenu(Menu_Trikz, MENU_ACTIONS_DEFAULT);
	SetMenuTitle(hMenu, "Trikz Menu\n \n");
	
	decl String:sText[32];
	
	Format(sText, sizeof(sText), "[%s] - AutoFlash", (g_bAutoFlash[client]) ? "x" : "  ");
	AddMenuItem(hMenu, "0", sText);
	
	Format(sText, sizeof(sText), "[%s] - AutoSwitch", (g_bAutoSwitch[client]) ? "x" : "  ");
	AddMenuItem(hMenu, "1", sText);
	
	Format(sText, sizeof(sText), "[%s] - Block", (g_bBlock[client]) ? "x" : "  ");
	AddMenuItem(hMenu, "2", sText);
	
	Format(sText, sizeof(sText), "[%s] - SkyFix", (g_bSkyFix[client]) ? "x" : "  ");
	AddMenuItem(hMenu, "3", sText);
	
	SetMenuOptionFlags(hMenu, MENUFLAG_NO_SOUND|MENUFLAG_BUTTON_EXIT);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

stock ToggleBlock(client)
{
	g_bBlock[client] = !g_bBlock[client];
	
	if (g_bBlock[client]) {
		PrintToChat(client, "[Trikz] Block is ON");
		SetAlpha(client, 255);
		SetEntData(client, g_CollisionGroup, 5, 4, true);
	} else {
		PrintToChat(client, "[Trikz] Block is OFF");
		SetAlpha(client, 100);
		SetEntData(client, g_CollisionGroup, 2, 4, true);
	}
	
	new userid = GetClientUserId(client);
	CreateTimer(0.1, Timer_TestBlock, userid);
	CreateTimer(0.5, Timer_TestBlock, userid);
	
	SaveTrikzPref(client, 1);
}

stock GetClientFlashBangs(client)
{
	decl String:sWeapon[64];
	for (new i = 0, weapon; i < 128; i += 4) {
		weapon = GetEntDataEnt2(client, m_hMyWeapons + i);
		if (weapon != -1) {
			GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
			if (StrEqual(sWeapon, "weapon_flashbang")) {
				new iPrimaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType", 4);
				new ammo = GetEntData(client, g_AmmoOffset+(iPrimaryAmmoType*4));
				return ammo;
			}
		}
	}
	return 0;
}

stock SetAlpha(target, alpha)
{        
	SetEntityRenderMode(target, RENDER_TRANSCOLOR);
	SetEntityRenderColor(target, 255, 255, 255, alpha);    
}

stock SaveTrikzPref(client, type)
{
	if (AreClientCookiesCached(client))
	{
		decl String:sValue[8];
		switch (type)
		{
			case 1: {
				IntToString((g_bBlock[client]), sValue, sizeof(sValue));
				SetClientCookie(client, g_hBlockCookie, sValue);
			}
			case 2: {
				IntToString((g_bAutoSwitch[client]), sValue, sizeof(sValue));
				SetClientCookie(client, g_hAutoSwitchCookie, sValue);
			}
			case 3: {
				IntToString((g_bAutoFlash[client]), sValue, sizeof(sValue));
				SetClientCookie(client, g_hAutoFlashCookie, sValue);
			}
			case 4: {
				IntToString((g_bSkyFix[client]), sValue, sizeof(sValue));
				SetClientCookie(client, g_hSkyFixCookie, sValue);
			}
			default: {
				IntToString((g_bBlock[client]), sValue, sizeof(sValue));
				SetClientCookie(client, g_hBlockCookie, sValue);
				
				IntToString((g_bAutoSwitch[client]), sValue, sizeof(sValue));
				SetClientCookie(client, g_hAutoSwitchCookie, sValue);
				
				IntToString((g_bAutoFlash[client]), sValue, sizeof(sValue));
				SetClientCookie(client, g_hAutoFlashCookie, sValue);
			
				
				IntToString((g_bSkyFix[client]), sValue, sizeof(sValue));
				SetClientCookie(client, g_hSkyFixCookie, sValue);
			}
		}
	}
}
