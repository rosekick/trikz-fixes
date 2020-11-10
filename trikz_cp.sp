#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <colorvariables>

// max savelocs is 1024
#define MAX_LOCS 1024

// gravity
float gravity;

// Save locs
int g_iSaveLocCount;
float g_fSaveLocCoords[MAX_LOCS][3]; // [loc id][coords]
float g_fSaveLocAngle[MAX_LOCS][3]; // [loc id][angle]
float g_fSaveLocVel[MAX_LOCS][3]; // [loc id][velocity]
char g_szSaveLocTargetname[MAX_LOCS][128]; // [loc id]
char g_szSaveLocClientName[MAX_LOCS][MAX_NAME_LENGTH];
int g_iLastSaveLocIdClient[MAXPLAYERS + 1];
float g_fLastCheckpointMade[MAXPLAYERS + 1];
int g_iSaveLocUnix[MAX_LOCS]; // [loc id]
int g_iMenuPosition[MAXPLAYERS + 1];

public void OnPluginStart()
{
    RegConsoleCmd("sm_cp", Command_cpmenu, "create checkpoint");
	RegConsoleCmd("sm_save", Command_createPlayerCheckpoint, "create checkpoint");
    RegConsoleCmd("sm_tele", Command_goToPlayerCheckpoint, "teleport to your latest checkpoint");
    RegConsoleCmd("sm_savelist", Command_SaveList, "create savelocs menu");
    RegConsoleCmd("sm_nc", Command_Noclip, "noclip");
}

public void OnMapStart()
{
    ResetSaveLocs();
}

public Action Command_cpmenu(int client, int args)
{
    if(!client) return Plugin_Handled;

    OpenCpMenu(client);

    return Plugin_Handled;
}

public Action Command_createPlayerCheckpoint(int client, int args)
{
    float time = GetGameTime();

	if ((time - g_fLastCheckpointMade[client]) < 1.0)
		return Plugin_Handled;

	if (g_iSaveLocCount < MAX_LOCS)
	{
		g_iSaveLocCount++;
        gravity = GetEntityGravity(client);
		GetClientAbsOrigin(client, g_fSaveLocCoords[g_iSaveLocCount]);
		GetClientEyeAngles(client, g_fSaveLocAngle[g_iSaveLocCount]);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", g_fSaveLocVel[g_iSaveLocCount]);
		GetEntPropString(client, Prop_Data, "m_iName", g_szSaveLocTargetname[g_iSaveLocCount], sizeof(g_szSaveLocTargetname));
		g_iLastSaveLocIdClient[client] = g_iSaveLocCount;
		CPrintToChat(client, "sm_tele #%d", g_iSaveLocCount);

		g_fLastCheckpointMade[client] = GetGameTime();
		g_iSaveLocUnix[g_iSaveLocCount] = GetTime();
		GetClientName(client, g_szSaveLocClientName[g_iSaveLocCount], MAX_NAME_LENGTH);
	}
	else
	{
		CPrintToChat(client, "How did you hit 1024 save");
	}

	return Plugin_Handled;
}

public Action Command_goToPlayerCheckpoint(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	
	if (g_iSaveLocCount > 0)
	{
		if (args == 0)
		{
			int id = g_iLastSaveLocIdClient[client];
			TeleportToSaveloc(client, id);
		}
		else
		{
			char arg[128];
			char firstChar[2];
			GetCmdArg(1, arg, 128);
			Format(firstChar, 2, arg[0]);
			if (!StrEqual(firstChar, "#"))
			{
				CPrintToChat(client, "sm_tele #id");
				return Plugin_Handled;
			}

			ReplaceString(arg, 128, "#", "", false);
			int id = StringToInt(arg);

			if (id < 1 || id > MAX_LOCS - 1 || id > g_iSaveLocCount)
			{
				CPrintToChat(client, "Invalid id");
				return Plugin_Handled;
			}

			g_iLastSaveLocIdClient[client] = id;
			TeleportToSaveloc(client, id);
		}
	}
	else
	{
		CPrintToChat(client, "There are no saved locations, use sm_saveloc to make one");
	}

	return Plugin_Handled;
}

public Action Command_SaveList(int client, int args)
{
	if (g_iSaveLocCount < 1)
	{
		CPrintToChat(client, "There are no saved locations, use sm_saveloc to make one");
		return Plugin_Handled;
	}

	SaveLocMenu(client);

	return Plugin_Handled;
}

public void OpenCpMenu(int client)
{
    Menu menu = new Menu(CpMenu_Handle);

    menu.SetTitle("cp menu");

    menu.AddItem("save", "Save");
    menu.AddItem("tp", "Teleport");
	menu.AddItem("list", "Savelist");
    menu.AddItem("nc", "Noclip");

    menu.Display(client, MENU_TIME_FOREVER);
}

public int CpMenu_Handle(Menu menu, MenuAction action, int client, int param2)
{
    if(action == MenuAction_Select)
    {
        char sInfo[16];
        menu.GetItem(param2, sInfo, sizeof(sInfo));

        if(StrEqual(sInfo, "save"))
        {
            Command_createPlayerCheckpoint(client, 0);
            OpenCpMenu(client);
        }
        else if(StrEqual(sInfo, "tp"))
        {
            Command_goToPlayerCheckpoint(client, 0);
            OpenCpMenu(client);
        }
		else if(StrEqual(sInfo, "list"))
        {
            Command_SaveList(client, 0);
        }
        else if(StrEqual(sInfo, "nc"))
        {
            Command_Noclip(client, 0);
            OpenCpMenu(client);
        }
    }
}

public Action Command_Noclip(int client, int args)
{
    new MoveType:movetype = GetEntityMoveType(client);
    if (movetype != MOVETYPE_NOCLIP)
    {
        SetEntityMoveType(client, MOVETYPE_NOCLIP);
    }
    else
    {
        SetEntityMoveType(client, MOVETYPE_WALK);
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
    }
    return Plugin_Handled;
}


public void SaveLocMenu(int client)
{
	Menu menu = CreateMenu(SaveLocListHandler);
	SetMenuTitle(menu, "Save Locs");
	char szBuffer[128];
	char szItem[256];
	char szId[32];
	int unix;
	for (int i = 1; i <= g_iSaveLocCount; i++)
	{
		unix = GetTime() - g_iSaveLocUnix[i];
		diffForHumans(unix, szBuffer, 128, 1);
		Format(szItem, sizeof(szItem), "#%d - %s - %s", i, g_szSaveLocClientName[i], szBuffer);
		IntToString(i, szId, 32);
		AddMenuItem(menu, szId, szItem);
	}

	int pos = g_iMenuPosition[client];
	if (pos < 6)
		pos = 0;
	else if (pos < 12)
		pos = 6;
	else if (pos < 18)
		pos = 12;
	else if (pos < 24)
		pos = 18;
	else if (pos < 30)
		pos = 24;
	else if (pos < 36)
		pos = 30;
	else if (pos < 42)
		pos = 36;
	else if (pos < 48)
		pos = 42;
	else if (pos < 54)
		pos = 48;
	else if (pos < 60)
		pos = 54;
	SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
	DisplayMenuAtItem(menu, client, pos, MENU_TIME_FOREVER);
}

public int SaveLocListHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		g_iMenuPosition[param1] = param2;
		char szId[32];
		GetMenuItem(menu, param2, szId, 32);
		int id = StringToInt(szId);
		CPrintToChat(param1, "Set saveloc id to %d", id);
		TeleportToSaveloc(param1, id);
		SaveLocMenu(param1);
	}
	else if (action == MenuAction_End)
		delete menu;
}

public void ResetSaveLocs()
{
	g_iSaveLocCount = 0;
	for (int i = 0; i < MAX_LOCS; i++)
	{
		for (int j = 0; j < 3; j++)
		{
			g_fSaveLocCoords[i][j] = 0.0;
			g_fSaveLocAngle[i][j] = 0.0;
			g_fSaveLocVel[i][j] = 0.0;
		}
		g_iSaveLocUnix[i] = 0;
		g_szSaveLocTargetname[i][0] = '\0';
	}
}

public void TeleportToSaveloc(int client, int id)
{
	g_iLastSaveLocIdClient[client] = id;
	SetEntityGravity(client, gravity);
	DispatchKeyValue(client, "targetname", g_szSaveLocTargetname[id]);
	SetEntPropVector(client, Prop_Data, "m_vecVelocity", view_as<float>( { 0.0, 0.0, 0.0 } ));
	TeleportEntity(client, g_fSaveLocCoords[id], g_fSaveLocAngle[id], g_fSaveLocVel[id]);
}

public void diffForHumans(int unix, char[] buffer, int size, int type)
{
	int years, months, days, hours, mins, secs;
	if (type == 0)
	{
		if (unix > 31535999)
		{
			years = unix / 60 / 60 / 24 / 365;
			Format(buffer, size, "%d year%s ago", years, years==1?"":"s");
		}
		if (unix > 2591999)
		{
			months = unix / 60 / 60 / 24 / 30;
			Format(buffer, size, "%d month%s ago", months, months==1?"":"s");
		}
		if (unix > 86399)
		{
			days = unix / 60 / 60 / 24;
			hours = unix / 3600 % 60;
			mins = unix / 60 % 60;
			secs = unix % 60;
			Format(buffer, size, "%d day%s ago", days, days==1?"":"s");
		}
		else if (unix > 3599)
		{
			hours = unix / 3600 % 60;
			mins = unix / 60 % 60;
			secs = unix % 60;
			Format(buffer, size, "%d hour%s %d minute%s %d second%s ago", hours, hours==1?"":"s", mins, mins==1?"":"s", secs, secs==1?"":"s");
		}
		else if (unix > 59)
		{
			mins = unix / 60 % 60;
			secs = unix % 60;
			Format(buffer, size, "%d minute%s %d second%s ago", mins, mins==1?"":"s", secs, secs==1?"":"s");
		}
		else
		{
			secs = unix;
			Format(buffer, size, "%d second%s ago", secs, secs==1?"":"s");
		}
	}
	else if (type == 1)
	{
		if (unix > 31535999)
		{
			years = unix / 60 / 60 / 24 / 365;
			Format(buffer, size, "%d year%s ago", years, years==1?"":"s");
		}
		if (unix > 2591999)
		{
			months = unix / 60 / 60 / 24 / 30;
			Format(buffer, size, "%d month%s ago", months, months==1?"":"s");
		}
		if (unix > 86399)
		{
			days = unix / 60 / 60 / 24;
			Format(buffer, size, "%d day%s ago", days, days==1?"":"s");
		}
		else if (unix > 3599)
		{
			hours = unix / 3600 % 60;
			Format(buffer, size, "%d hour%s ago", hours, hours==1?"":"s");
		}
		else if (unix > 59)
		{
			mins = unix / 60 % 60;
			Format(buffer, size, "%d minute%s ago", mins, mins==1?"":"s");
		}
		else
		{
			secs = unix;
			if (secs < 1)
				secs = 1;
			Format(buffer, size, "%d second%s ago", secs, secs==1?"":"s");
		}
	}
}

stock bool IsValidClient(int client)
{
	if (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client))
		return true;
	return false;
}