#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <csgoitems>
#include <clientprefs>
#include <multicolors>
#include <autoexecconfig>
#include <groupstatus>

#pragma newdecls required

#define DISPLAY_LENGTH 128
#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))
#define PTAG "{darkblue}[DNG]{default}"

Database g_dDB = null;

int g_iGlove[MAXPLAYERS + 1] = { -1, ...};
int g_iSkin[MAXPLAYERS + 1] = { -1, ...};

int g_iGloveSite[MAXPLAYERS + 1] = { -1, ...};
int g_iSkinSite[MAXPLAYERS + 1] = { -1, ...};

int g_iLastGloveChange[MAXPLAYERS + 1] = { -1, ...};
int g_iLastSkinChange[MAXPLAYERS + 1] = { -1, ...};

Handle g_hAllSkins = null;
bool g_bAllSkins[MAXPLAYERS + 1] = { false, ... };

ConVar g_cFlag = null;
ConVar g_cInterval = null;

public Plugin myinfo = 
{
    name = "Gloves",
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("HasClientGloves", Native_HasGloves);

    RegPluginLibrary("gloves");

    return APLRes_Success;
}

public int Native_HasGloves(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (g_iGlove[client] > 0 && g_iSkin[client] > 0)
    {
        return true;
    }

    return false;
}

public void OnPluginStart()
{
    RegAdminCmd("sm_dglove", Command_DGloves, ADMFLAG_ROOT);

    RegConsoleCmd("sm_glove", Command_Gloves);
    RegConsoleCmd("sm_gloves", Command_Gloves);

    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

    g_hAllSkins = RegClientCookie("ws_allskins", "Show all skins", CookieAccess_Private);
    SetCookiePrefabMenu(g_hAllSkins, CookieMenu_OnOff_Int, "Show all skins", Cookie_Request);

    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("plugin.gloves");
    g_cFlag = AutoExecConfig_CreateConVar("gloves_flag", "t", "Flag to get access");
    g_cInterval = AutoExecConfig_CreateConVar("gloves_interval", "t", "Interval between changes");
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();

    LoopClients(i)
    {
        OnClientPutInServer(i);

        if (!AreClientCookiesCached(i))
        {
            g_bAllSkins[i] = false;
            continue;
        }

        OnClientCookiesCached(i);
    }

    connectSQL();

    LoadTranslations("gloves.phrases");
    LoadTranslations("groupstatus.phrases");
}

public void OnMapStart()
{
    connectSQL();
}

void connectSQL()
{
    SQL_TConnect(OnSQLConnect, "valve");
}

public void OnSQLConnect(Handle owner, Handle hndl, const char[] error, any data)
{
    if (hndl == null)
    {
        SetFailState("(OnSQLConnect) Can't connect to database");
        return;
    }
    
    g_dDB = view_as<Database>(CloneHandle(hndl));
    
    CreateTable();
}

void CreateTable()
{
    char sQuery[1024];
    Format(sQuery, sizeof(sQuery),
    "CREATE TABLE IF NOT EXISTS `gloves` ( \
        `id` INT NOT NULL AUTO_INCREMENT, \
        `communityid` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL, \
        `glove` int(11) NOT NULL DEFAULT '0', \
        `skin` int(11) NOT NULL DEFAULT '0', \
        PRIMARY KEY (`id`), \
        UNIQUE KEY (`communityid`) \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");
    
    g_dDB.Query(SQL_CreateTable, sQuery);
}

public void SQL_CreateTable(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_CreateTable) Fail at Query: %s", error);
        return;
    }
    delete results;
    
    LoopClients(i)
    {
        LoadClientGloves(i);
    }
}

public void OnClientPutInServer(int client)
{
    if(IsClientValid(client))
    {
        if (!AreClientCookiesCached(client))
        {
            g_bAllSkins[client] = false;
        }
        else
            OnClientCookiesCached(client);
    }
}

public void OnClientCookiesCached(int client)
{
    char sValue[8];
    GetClientCookie(client, g_hAllSkins, sValue, sizeof(sValue));
    g_bAllSkins[client] = (sValue[0] != '\0' && StringToInt(sValue));
}

public void Cookie_Request(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    if(action == CookieMenuAction_SelectOption)
    {
        OnClientCookiesCached(client);
    }
}
public void OnClientPostAdminCheck(int client)
{
    if(IsClientValid(client))
    {
        LoadClientGloves(client);
    }
}

void LoadClientGloves(int client)
{
    char sCommunityID[32];
    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
    {
        LogError("Auth failed for client index %d", client);
        return;
    }

    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "SELECT glove, skin FROM gloves WHERE communityid = \"%s\" LIMIT 1;", sCommunityID);
    g_dDB.Query(SQL_LoadClientGloves, sQuery, GetClientUserId(client));
}

public void SQL_LoadClientGloves(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_LoadClientGloves) Fail at Query: %s", error);
        return;
    }
    else
    {
        if(results.HasResults)
        {
            int client = GetClientOfUserId(data);
                
            if (IsClientValid(client))
            {
                while (results.FetchRow())
                {
                    g_iGlove[client] = results.FetchInt(0);
                    g_iSkin[client] = results.FetchInt(1);
                }
            }
        }
    }
}

void UpdateClientSQL(int client)
{
    char sCommunityID[32];
    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
    {
        LogError("Auth failed for client index %d", client);
        return;
    }

    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "INSERT INTO gloves (communityid, glove, skin) VALUES (\"%s\", '%d', '%d') ON DUPLICATE KEY UPDATE glove = '%d', skin = '%d';", sCommunityID, g_iGlove[client], g_iSkin[client], g_iGlove[client], g_iSkin[client]);
    g_dDB.Query(SQL_UpdateClientGloves, sQuery, GetClientUserId(client));
}

public void SQL_UpdateClientGloves(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_UpdateClientGloves) Fail at Query: %s", error);
        return;
    }
}

public Action Command_DGloves(int client, int args)
{
    SetEntPropString(client, Prop_Send, "m_szArmsModel", "");
}

public Action Command_Gloves(int client, int args)
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

    ShowGlovesMenu(client);

    return Plugin_Continue;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if(IsClientValid(client))
    {
        CreateTimer(0.2, Timer_UpdateClientGlove, GetClientUserId(client));
    }
}

public Action Timer_UpdateClientGlove(Handle timer, any userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client))
    {
        UpdatePlayerGlove(client);
    }
}

void ShowGlovesMenu(int client)
{
    Menu menu = new Menu(Menu_Gloves);

    char sTitle[DISPLAY_LENGTH];
    char sBuffer[DISPLAY_LENGTH];

    if (g_iGlove[client] > 0)
    {
        CSGOItems_GetGlovesDisplayNameByDefIndex(g_iGlove[client], sBuffer, sizeof(sBuffer));
        Format(sTitle, sizeof(sTitle), "%T", "Choose a Glove Currently", client, sBuffer);
    }
    else
    {
        Format(sTitle, sizeof(sTitle), "%T", "Choose a Glove", client);
    }

    menu.SetTitle(sTitle);

    if (g_bAllSkins[client])
    {
        Format(sBuffer, sizeof(sBuffer), "%T\n ", "Menu Suitable: Yes", client);
        menu.AddItem("changeAllSkins", sBuffer);
    }
    else
    {
        Format(sBuffer, sizeof(sBuffer), "%T\n ", "Menu Suitable: All", client);
        menu.AddItem("changeAllSkins", sBuffer);
    }

    if (g_iGlove[client] != 0)
    {
        menu.AddItem("0", "Keine Gloves");
    }
    else
    {
        menu.AddItem("0", "Keine Gloves", ITEMDRAW_DISABLED);
    }

    for (int i = 0; i <= CSGOItems_GetGlovesCount(); i++)
    {
        int iIndex = CSGOItems_GetGlovesDefIndexByGlovesNum(i);

        if (iIndex == 0)
        {
            continue;
        }

        char sName[DISPLAY_LENGTH];
        CSGOItems_GetGlovesDisplayNameByDefIndex(iIndex, sName, sizeof(sName));

        if (StrContains(sName, "Default", false) != -1)
        {
            continue;
        }

        IntToString(iIndex, sBuffer, sizeof(sBuffer));
        menu.AddItem(sBuffer, sName);
    }
    
    menu.ExitButton = true;
    menu.DisplayAt(client, g_iGloveSite[client], MENU_TIME_FOREVER);
}

public int Menu_Gloves(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (((g_iLastGloveChange[client] + g_cInterval.IntValue) <= GetTime()) || g_iLastGloveChange[client] == -1)
        {
            char sIndex[DISPLAY_LENGTH];
            menu.GetItem(param, sIndex, sizeof(sIndex));

            if (StrEqual(sIndex, "changeAllSkins", false))
            {
                if (g_bAllSkins[client])
                {
                    CPrintToChat(client, "%T", "Suitable: Yes", client, PTAG);
                    g_bAllSkins[client] = false;
                }
                else
                {
                    CPrintToChat(client, "%T", "Suitable: All", client, PTAG);
                    g_bAllSkins[client] = true;
                }

                char buffer[5];
                IntToString(g_bAllSkins[client], buffer, 5);
                SetClientCookie(client, g_hAllSkins, buffer);

                g_iGloveSite[client] = menu.Selection;

                RequestFrame(Frame_OpenMenu, GetClientUserId(client));
            }
            else
            {
                int iIndex = StringToInt(sIndex);

                g_iLastGloveChange[client] = GetTime();
                g_iGlove[client] = iIndex;

                char sDisplay[DISPLAY_LENGTH];
                CSGOItems_GetGlovesDisplayNameByDefIndex(g_iGlove[client], sDisplay, sizeof(sDisplay));
                CPrintToChat(client, "%T", "Glove Choosed", client, PTAG, sDisplay);

                g_iGloveSite[client] = menu.Selection;

                ShowSkinsMenu(client);
            }
        }
        else
        {
            int iLeft = (GetTime() - g_iLastGloveChange[client] - g_cInterval.IntValue) * -1;
            
            if (iLeft == 1)
            {
                CPrintToChat(client, "%T", "Remaining One", client, PTAG);
            }
            else
            {
                CPrintToChat(client, "%T", "Remaining", client, PTAG, iLeft);
            }

            RequestFrame(Frame_OpenMenu, GetClientUserId(client));
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ShowSkinsMenu(int client)
{
    Menu menu = new Menu(Menu_GloveSkin);

    char sTitle[DISPLAY_LENGTH];

    if (g_iGlove[client] > 0)
    {
        char sBuffer[DISPLAY_LENGTH], sSkin[DISPLAY_LENGTH];

        if (g_iSkin[client] > 0)
        {
            CSGOItems_GetSkinDisplayNameByDefIndex(g_iSkin[client], sSkin, sizeof(sSkin));
            Format(sSkin, sizeof(sSkin), "\nSkin: %s", sSkin);
        }

        CSGOItems_GetGlovesDisplayNameByDefIndex(g_iGlove[client], sBuffer, sizeof(sBuffer));
        Format(sTitle, sizeof(sTitle), "%T", "Choose a Skin Currently", client, sBuffer, sSkin);
    }
    else
    {
        Format(sTitle, sizeof(sTitle), "%T", "Choose a Skin", client);
    }

    menu.SetTitle(sTitle);

    for (int i = 0; i <= CSGOItems_GetSkinCount(); i++)
    {
        int iIndex = CSGOItems_GetSkinDefIndexBySkinNum(i);

        if (iIndex == 0 || !CSGOItems_IsSkinNumGloveApplicable(i))
        {
            continue;
        }

        char sName[DISPLAY_LENGTH], sBuffer[12];
        CSGOItems_GetSkinDisplayNameByDefIndex(iIndex, sName, sizeof(sName));

        if (StrContains(sName, "Default", false) != -1)
        {
            continue;
        }

        if (!g_bAllSkins[client])
        {
            int iGloveNum = CSGOItems_GetGlovesNumByDefIndex(g_iGlove[client]);

            if (!CSGOItems_IsNativeSkin(i, iGloveNum, ITEMTYPE_GLOVES))
            {
                continue;
            }
        }

        IntToString(iIndex, sBuffer, sizeof(sBuffer));

        if (g_iGlove[client] != iIndex)
        {
            menu.AddItem(sBuffer, sName);
        }
        else
        {
            menu.AddItem(sBuffer, sName, ITEMDRAW_DISABLED);
        }
    }
    
    menu.ExitButton = true;
    menu.DisplayAt(client, g_iSkinSite[client], MENU_TIME_FOREVER);
}

public int Menu_GloveSkin(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (((g_iLastSkinChange[client] + g_cInterval.IntValue) <= GetTime()) || g_iLastSkinChange[client] == -1)
        {
            char sIndex[DISPLAY_LENGTH];
            menu.GetItem(param, sIndex, sizeof(sIndex));
            int iIndex = StringToInt(sIndex);

            g_iLastSkinChange[client] = GetTime();
            g_iSkin[client] = iIndex;

            char sDisplay[DISPLAY_LENGTH];
            CSGOItems_GetSkinDisplayNameByDefIndex(g_iSkin[client], sDisplay, sizeof(sDisplay));
            CPrintToChat(client, "%T", "Glove Choosed", client, PTAG, sDisplay);

            g_iSkinSite[client] = menu.Selection;

            if (IsPlayerAlive(client))
            {
                UpdatePlayerGlove(client);
            }

            UpdateClientSQL(client);
        }
        else
        {
            int iLeft = (GetTime() - g_iLastSkinChange[client] - g_cInterval.IntValue) * -1;
            
            if (iLeft == 1)
            {
                CPrintToChat(client, "%T", "Remaining One", client, PTAG);
            }
            else
            {
                CPrintToChat(client, "%T", "Remaining", client, PTAG, iLeft);
            }
        }

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
        ShowGlovesMenu(client);
    }
}

void UpdatePlayerGlove(int client)
{
    if (g_iGlove[client] < 1 || g_iSkin[client] < 1)
    {
        return;
    }

    int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if(iWeapon != -1)
    {
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
    }

    int ent = GetEntPropEnt(client, Prop_Send, "m_hMyWearables");
    if(ent != -1)
    {
        AcceptEntityInput(ent, "KillHierarchy");
    }

    SetEntPropString(client, Prop_Send, "m_szArmsModel", "");

    ent = CreateEntityByName("wearable_item");

    if(ent != -1)
    {
        SetEntProp(ent, Prop_Send, "m_iItemIDLow", -1);

        SetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex", g_iGlove[client]);
        SetEntProp(ent, Prop_Send,  "m_nFallbackPaintKit", g_iSkin[client]);
        
        SetEntPropFloat(ent, Prop_Send, "m_flFallbackWear", 0.0001);
        SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
        SetEntPropEnt(ent, Prop_Data, "m_hParent", client);
        // SetEntPropEnt(ent, Prop_Data, "m_hMoveParent", client); // For WorlModel support
        SetEntProp(ent, Prop_Send, "m_bInitialized", 1);

        DispatchSpawn(ent);

        SetEntPropEnt(client, Prop_Send, "m_hMyWearables", ent);
        // SetEntProp(client, Prop_Send, "m_nBody", 1); // For WorlModel support
    }

    if(iWeapon != -1)
    {
        DataPack dpack;
        CreateDataTimer(0.1, ResetGlovesTimer, dpack);
        dpack.WriteCell(client);
        dpack.WriteCell(iWeapon);
    }
}

public Action ResetGlovesTimer(Handle timer, DataPack pack)
{
    ResetPack(pack);
    int client = pack.ReadCell();
    int iWeapon = pack.ReadCell();

    if(IsClientValid(client) && IsValidEntity(iWeapon))
    {
        SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iWeapon);
    }
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
