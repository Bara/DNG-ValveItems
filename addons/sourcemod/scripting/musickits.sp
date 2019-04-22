#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <csgoitems>
#include <clientprefs>
#include <multicolors>
#include <groupstatus>

#pragma newdecls required

#define MK_LENGTH 128
#define OUTBREAK "{darkblue}[DNG]{default}"
#define SPECIAL "{lightgreen}"
#define TEXT "{default}"

bool g_bDebug = false;

int g_iMusicKit[MAXPLAYERS + 1] =  { -1, ... };
int g_iSite[MAXPLAYERS + 1] =  { 0, ... };

Handle g_hMusicKitCookie = null;
Handle g_hRandomKit = null;
bool g_bRandom[MAXPLAYERS + 1] = { false, ... };

public Plugin myinfo = 
{
	name = "Music Kits",
	author = "Bara",
	description = "",
	version = "1.0.0",
	url = "github.com/Bara/musicKits"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_music", Command_Music, ADMFLAG_CUSTOM1);
	RegAdminCmd("sm_kit", Command_Music, ADMFLAG_CUSTOM1);
	RegAdminCmd("sm_kits", Command_Music, ADMFLAG_CUSTOM1);
	RegConsoleCmd("sm_rkit", Command_RKit);

	RegAdminCmd("sm_mykit", Command_MyKit, ADMFLAG_CUSTOM1);
	
	g_hMusicKitCookie = RegClientCookie("musickits_cookie_v2", "Cookie for Music Kit Def Index", CookieAccess_Private);
	g_hRandomKit = RegClientCookie("musikkits_random_kit_v2", "Enable/Disable Random Kit", CookieAccess_Private);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_Player);
	HookEvent("round_start", Event_Round);
	HookEvent("round_end", Event_Round);
	
	for (int i = 0; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			OnClientCookiesCached(i);
		}
	}

	LoadTranslations("groupstatus.phrases");
}

public void CSGOItems_OnItemsSynced()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		if(IsClientValid(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	if (IsClientValid(client))
	{
		char sBuffer[8];
		GetClientCookie(client, g_hMusicKitCookie, sBuffer, sizeof(sBuffer));
		
		int iDefIndex = StringToInt(sBuffer);
		if(iDefIndex >= 0)
		{
			g_iMusicKit[client] = iDefIndex;
			SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusicKit[client]); // Trigger ban
		}

		GetClientCookie(client, g_hRandomKit, sBuffer, sizeof(sBuffer));
		g_bRandom[client] = view_as<bool>(StringToInt(sBuffer));
	}
}

public void OnClientPostAdminCheck(int client)
{
	CreateTimer(3.0, Timer_UpdateKit, GetClientUserId(client));
}

public Action Timer_UpdateKit(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (IsClientValid(client))
	{
		char sDefIndex[8];
		GetClientCookie(client, g_hMusicKitCookie, sDefIndex, sizeof(sDefIndex));
		
		int iDefIndex = StringToInt(sDefIndex);
		if(iDefIndex >= 0)
		{
			g_iMusicKit[client] = iDefIndex;
			SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusicKit[client]); // Trigger ban
		}
	}
}

public Action Event_Player(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsClientValid(client))
	{
		if(g_iMusicKit[client] > 0)
		{
			SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusicKit[client]); // Trigger ban
		}
	}
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsClientValid(client))
	{
		if(g_iMusicKit[client] > 0)
		{
			SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusicKit[client]); // Trigger ban
		}
		else if (g_bRandom[client])
		{
			int defIndex = CSGOItems_GetMusicKitDefIndexByMusicKitNum(GetRandomInt(0, CSGOItems_GetMusicKitCount()));

			SetEntProp(client, Prop_Send, "m_unMusicID", defIndex);

			char sDisplayName[MK_LENGTH];
			CSGOItems_GetMusicKitDisplayNameByDefIndex(defIndex, sDisplayName, sizeof(sDisplayName));

			CPrintToChat(client, "%s Ihr Musik Kit für diese Runde: %s%s", OUTBREAK, SPECIAL, sDisplayName);
		}
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsClientValid(client))
	{
		if (!CheckCommandAccess(client, "sm_vip", ADMFLAG_CUSTOM1, true))
		{
			CPrintToChat(client, "%s Du kannst mit %s!rkit %sein zufälliges Kit pro Runde de/aktivieren", OUTBREAK, SPECIAL, TEXT);
		}
	}
}

public Action Event_Round(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientValid(i))
		{
			if(g_iMusicKit[i] > 0)
			{
				SetEntProp(i, Prop_Send, "m_unMusicID", g_iMusicKit[i]); // Trigger ban
			}
		}
	}
}

public Action Command_MyKit(int client, int args)
{
	if (g_iMusicKit[client] >= 0)
	{
		char sDisplay[MK_LENGTH];
		CSGOItems_GetMusicKitDisplayNameByDefIndex(g_iMusicKit[client], sDisplay, sizeof(sDisplay));

		if(g_iMusicKit[client] > 0)
		{
			SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusicKit[client]); // Trigger ban
			CPrintToChat(client, "%s Dein Kit: {default}%s", OUTBREAK, sDisplay);
		}
		else
		{
			CPrintToChat(client, "%s Du hast {default}kein Kit {green}ausgewählt!", OUTBREAK, sDisplay);
		}
	}
}


public Action Command_RKit(int client, int args)
{
	if (!IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (!GroupStatus_IsClientInGroup(client))
	{
		ConVar cvar = FindConVar("groupstatus_url");

		if (cvar != null)
		{
			char sURL[256], sName[64];
			cvar.GetString(sName, sizeof(sName));
			Format(sURL, sizeof(sURL), "https://steamcommunity.com/groups/%s", sName);

			CPrintToChat(client, "%T", "In Group: No", client, sName);
		}

		return Plugin_Handled;
	}

	if (g_bRandom[client])
	{
		g_bRandom[client] = false;
		CPrintToChat(client, "%s Zufälliges Kit wurde: %sDeaktiviert", OUTBREAK, SPECIAL);
	}
	else
	{
		g_bRandom[client] = true;
		CPrintToChat(client, "%s Zufälliges Kit wurde: %sAktiviert", OUTBREAK, SPECIAL);
	}

	char sBuffer[4];
	IntToString(g_bRandom[client], sBuffer, sizeof(sBuffer));
	SetClientCookie(client, g_hRandomKit, sBuffer);

	return Plugin_Continue;
}

public Action Command_Music(int client, int args)
{
	if(!IsClientValid(client))
	{
		return Plugin_Handled;
	}

	if (!GroupStatus_IsClientInGroup(client))
	{
		ConVar cvar = FindConVar("groupstatus_url");

		if (cvar != null)
		{
			char sURL[256], sName[64];
			cvar.GetString(sName, sizeof(sName));
			Format(sURL, sizeof(sURL), "https://steamcommunity.com/groups/%s", sName);

			CPrintToChat(client, "%T", "In Group: No", client, sName);
		}

		return Plugin_Handled;
	}
	
	ShowMusicKitsMenu(client);
	
	return Plugin_Continue;
}

public int Menu_MusicKits(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char sDefIndex[MK_LENGTH];
		menu.GetItem(param, sDefIndex, sizeof(sDefIndex));
		g_iMusicKit[client] = StringToInt(sDefIndex);
		SetClientCookie(client, g_hMusicKitCookie, sDefIndex);

		char sDisplay[MK_LENGTH];
		CSGOItems_GetMusicKitDisplayNameByDefIndex(g_iMusicKit[client], sDisplay, sizeof(sDisplay));

		if(g_iMusicKit[client] > 0)
		{
			CPrintToChat(client, "%s Dein neues Kit: {default}%s", OUTBREAK, sDisplay);
		}
		else
		{
			CPrintToChat(client, "%s Du hast {default}kein Kit {green}ausgewählt!", OUTBREAK, sDisplay);
		}
		
		g_iSite[client] = menu.Selection;
		
		SetEntProp(client, Prop_Send, "m_unMusicID", g_iMusicKit[client]); // Trigger ban
		RequestFrame(Frame_OpenMenu, GetClientUserId(client));
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void Frame_OpenMenu(any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (IsClientValid(client))
	{
		ShowMusicKitsMenu(client);
	}
}

void ShowMusicKitsMenu(int client)
{
	
	Menu menu = new Menu(Menu_MusicKits);
	
	if (g_iMusicKit[client] > 0)
	{
		char sDisplay[MK_LENGTH];
		CSGOItems_GetMusicKitDisplayNameByDefIndex(g_iMusicKit[client], sDisplay, sizeof(sDisplay));
		
		menu.SetTitle("Wähle ein Musik Kit\nAktuelles: %s", sDisplay);
	}
	else
	{
		menu.SetTitle("Wähle ein Musik Kit:");
	}
	
	if (g_iMusicKit[client] == 0)
	{
		menu.AddItem("0", "Kein Kit", ITEMDRAW_DISABLED);
	}
	else
	{
		menu.AddItem("0", "Kein Kit");
	}
	
	for (int i = 0; i <= CSGOItems_GetMusicKitCount(); i++)
	{
		int defIndex = CSGOItems_GetMusicKitDefIndexByMusicKitNum(i);
		
		char sDisplayName[MK_LENGTH];
		CSGOItems_GetMusicKitDisplayNameByDefIndex(defIndex, sDisplayName, sizeof(sDisplayName));
		
		if(strlen(sDisplayName) < 1)
			continue;
		
		if (g_bDebug)
		{
			PrintToChat(client, "%s [%d]", sDisplayName, defIndex);
		}
		
		char sKey[MK_LENGTH];
		IntToString(defIndex, sKey, sizeof(sKey));
		
		if (g_iMusicKit[client] != defIndex)
		{
			menu.AddItem(sKey, sDisplayName);
		}
		else if (g_iMusicKit[client] == defIndex)
		{
			menu.AddItem(sKey, sDisplayName, ITEMDRAW_DISABLED);
		}
	}
	
	menu.ExitButton = true;
	menu.DisplayAt(client, g_iSite[client], MENU_TIME_FOREVER);
}

stock bool IsClientValid(int client, bool bots = false)
{
	if (client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client) && (bots || !IsFakeClient(client)) && !IsClientSourceTV(client))
		{
			return true;
		}
	}
	
	return false;
}
