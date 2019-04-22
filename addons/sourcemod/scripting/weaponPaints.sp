#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <csgoitems>
#include <clientprefs>
#include <multicolors>
#include <autoexecconfig>
#include <knifes>
#include <groupstatus>

#pragma newdecls required

#define WP_COMMUNITYID 32
#define WP_CLASSNAME 32
#define WP_DISPLAY 128

#define DEFAULT_WEAR 0.0001
#define DEFAULT_SEED 0
#define DEFAULT_QUALITY 3
#define DEFAULT_FLAG ""

#define OUTBREAK "{darkblue}[DNG]{default}"

enum skinsList {
    siDef,
    String:ssDef[6],
    String:ssName[WP_DISPLAY]
};

enum weaponsList {
    wiDef,
    String:wsDef[6],
    String:wsName[WP_DISPLAY]
}

enum paintsCache
{
    String:pC_sCommunityID[32],
    String:pC_sClassName[32],
    pC_iDefIndex,
    Float:pC_fWear,
    pC_iSeed,
    pC_iQuality,
    String:pC_sNametag[128]
};

bool g_bDebug = false;
bool g_bChangeC4 = false;
bool g_bChangeGrenade = false;

int g_iLastChange[MAXPLAYERS + 1] =  { -1, ... };

Database g_dDB = null;

int g_iClip1 = -1;

// int g_iWeaponPSite[MAXPLAYERS + 1] =  { 0, ... };

int g_iCache[paintsCache];
ArrayList g_aCache = null;
ArrayList g_aSkins = null;
ArrayList g_aWeapons = null;

Handle g_hAllSkins = null;
bool g_bAllSkins[MAXPLAYERS + 1] = { false, ... };

ConVar g_cFlag = null;
ConVar g_cNFlag = null;
ConVar g_cInterval = null;

#include "weaponPaints/sql.sp"
#include "weaponPaints/setSkin.sp"
#include "weaponPaints/current.sp"
#include "weaponPaints/weapon.sp"
#include "weaponPaints/wear.sp"
#include "weaponPaints/nametag.sp"

public Plugin myinfo = 
{
    name = "Weapon Paints",
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_ws", Command_WS);
    RegConsoleCmd("sm_allskins", Command_AllSkins);
    RegConsoleCmd("sm_nametag", Command_Nametag);

    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("plugin.weaponpaints");
    g_cFlag = AutoExecConfig_CreateConVar("weaponpaints_flag", "t", "Flag to get access");
    g_cNFlag = AutoExecConfig_CreateConVar("weaponpaints_nametag_flag", "t", "Flag to get access for nametags");
    g_cInterval = AutoExecConfig_CreateConVar("weaponpaints_interval", "5", "Interval between changes");
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    
    if (g_aCache != null)
        g_aCache.Clear();
    
    g_aCache = new ArrayList(sizeof(g_iCache));

    g_hAllSkins = RegClientCookie("ws_allskins", "Show all skins", CookieAccess_Private);
    SetCookiePrefabMenu(g_hAllSkins, CookieMenu_OnOff_Int, "Show all skins", Cookie_Request);
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientValid(i))
        {
            OnClientPutInServer(i);

            if (!AreClientCookiesCached(i))
            {
                g_bAllSkins[i] = false;
                continue;
            }

            OnClientCookiesCached(i);
        }
    }
    
    LogMessage("[WeaponPaints] Connect SQL OnPluginStart");
    connectSQL();
    
    g_iClip1 = FindSendPropInfo("CBaseCombatWeapon", "m_iClip1");
    if (g_iClip1 == -1)
    {
        SetFailState("Unable to find offset for m_iClip1.");
    }

    LoadTranslations("weaponpaints.phrases");
    LoadTranslations("groupstatus.phrases");
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);

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
        LoadClientPaints(client);
    }
}

public void OnClientDisconnect(int client)
{
    if (g_aCache != null)
    {
        char sCommunityID[WP_COMMUNITYID];
        
        if (client > 1 && !GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            return;
        }
        
        for (int i = 0; i < g_aCache.Length; i++)
        {
            int iCache[paintsCache];
            g_aCache.GetArray(i, iCache[0]);
            
            if (StrEqual(sCommunityID, iCache[pC_sCommunityID], true))
            {
                g_aCache.Erase(i);
            }
        }
    }
}

public void OnWeaponEquipPost(int client, int weapon)
{
    SetPaints(client, weapon);
}

public void OnMapStart()
{
    LogMessage("[WeaponPaints] Connect SQL OnMapStart");
    connectSQL();
}

public Action Command_AllSkins(int client, int args)
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

    if (g_bAllSkins[client])
    {
        CReplyToCommand(client, "%T", "All skins on", client, OUTBREAK);
    }
    else
    {
        CReplyToCommand(client, "%T", "All skins off", client, OUTBREAK);
    }

    return Plugin_Continue;
}

public Action Command_WS(int client, int args)
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

    char sBuffer[64];
    
    Menu menu = new Menu(Menu_PaintsMain);
    
    menu.SetTitle("%T", "Menu Choose category", client);

    Format(sBuffer, sizeof(sBuffer), "%T", "Menu Change Current Weapon", client);
    if (IsPlayerAlive(client))
    {
        menu.AddItem("current", sBuffer);
    }
    else
    {
        menu.AddItem("current", sBuffer, ITEMDRAW_DISABLED);
    }
    
    Format(sBuffer, sizeof(sBuffer), "%T", "Menu Change Weapon", client);
    menu.AddItem("weapon", sBuffer);
    
    Format(sBuffer, sizeof(sBuffer), "%T", "Menu Change Wear", client);
    if (IsPlayerAlive(client))
    {
        menu.AddItem("wear", sBuffer);
    }
    else
    {
        menu.AddItem("wear", sBuffer, ITEMDRAW_DISABLED);
    }
    
    if(IsPlayerAlive(client))
    {
        Format(sBuffer, sizeof(sBuffer), "%T", "Menu Change nametag", client);
        menu.AddItem("nametag", sBuffer);
    }
    
    if (g_bAllSkins[client])
    {
        Format(sBuffer, sizeof(sBuffer), "%T", "Menu All skins off", client);
        menu.AddItem("changeAllSkins", sBuffer);
    }
    else
    {
        Format(sBuffer, sizeof(sBuffer), "%T", "Menu All skins on", client);
        menu.AddItem("changeAllSkins", sBuffer);
    }
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    
    return Plugin_Continue;
}

public int Menu_PaintsMain(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[32];
        menu.GetItem(param, sParam, sizeof(sParam));
        
        if (StrEqual(sParam, "current", false))
        {
            if (CheckMenuWeapon(client))
            {
                ChooseCurrentWeapon(client);
            }
        }
        else if (StrEqual(sParam, "weapon", false))
        {
            if (CheckMenuWeapon(client))
            {
                ChooseWeaponMenu(client);
            }
        }
        else if (StrEqual(sParam, "wear", false))
        {
            if (CheckMenuWeapon(client))
            {
                ChangeWearMenu(client);
            }
        }
        else if (StrEqual(sParam, "nametag", false))
        {
            if (CheckMenuWeapon(client) && CheckMenuAccess(client))
            {
                ChangeNameTag(client);
            }
        }
        else if (StrEqual(sParam, "changeAllSkins", false))
        {
            if (g_bAllSkins[client])
            {
                CPrintToChat(client, "%T", "All skins on", client, OUTBREAK);
                g_bAllSkins[client] = false;
            }
            else
            {
                CPrintToChat(client, "%T", "All skins off", client, OUTBREAK);
                g_bAllSkins[client] = true;
            }

            char buffer[5];
            IntToString(g_bAllSkins[client], buffer, 5);
            SetClientCookie(client, g_hAllSkins, buffer);

            RequestFrame(Frame_ReopenWS, GetClientUserId(client));
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public void Frame_ReopenWS(any userid)
{
    int client = GetClientOfUserId(userid);

    if (IsClientValid(client))
    {
        Command_WS(client, 0);
    }
}

bool CheckMenuWeapon(int client)
{
    if 	(!IsValidDef(client, CSGOItems_GetActiveWeaponDefIndex(client), true))
    {
        Command_WS(client, 0);
        return false;
    }
    
    return true;
}

bool CheckMenuAccess(int client)
{
    if (CSGOItems_IsDefIndexKnife(CSGOItems_GetActiveWeaponDefIndex(client)) && (Knifes_GetIndex(client) < 1))
    {
        CPrintToChat(client, "%T", "No Permissions", client, OUTBREAK);
        Command_WS(client, 0);
        return false;
    }
    
    return true;
}

void connectSQL()
{
    if (SQL_CheckConfig("valve"))
    {
        SQL_TConnect(OnSQLConnect, "valve");
    }
    else
    {
        SetFailState("Can't find an entry in your databases.cfg with the name \"valve\"");
        return;
    }
}

void UpdateClientMySQL(int client, const char[] sClass, int defIndex, float fWear, int iSeed, int iQuality, char[] sNametag = "")
{
    if (g_aCache != null)
    {
        char sCommunityID[WP_COMMUNITYID];
        
        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            return;
        }
        
        char sQuery[2048];
        
        char sEName[512];
        g_dDB.Escape(sNametag, sEName, sizeof(sEName));
        
        Format(sQuery, sizeof(sQuery), "INSERT INTO weaponPaints (communityid, classname, defindex, wear, seed, quality, nametag) VALUES (\"%s\", \"%s\", '%d', %.4f, '%d', '%d', \"%s\") ON DUPLICATE KEY UPDATE  defindex = '%d', wear = %.4f, seed = '%d', quality = '%d', nametag = \"%s\";", sCommunityID, sClass, defIndex, fWear, iSeed, iQuality, sEName, defIndex, fWear, iSeed, iQuality, sEName);
        
        if (g_bDebug)
        {
            LogMessage(sQuery);
        }
        
        g_dDB.Query(OnUpdateClientArray, sQuery);
    }
}

public void OnUpdateClientArray(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(OnUpdateClientArray) Fail at Query: %s", error);
        return;
    }
}

void UpdateClientArray(int client, const char[] sClass, int defIndex, float fWear, int iSeed, int iQuality, char[] sNametag = "")
{
    if (g_dDB != null)
    {
        char sCommunityID[WP_COMMUNITYID];
        
        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            return;
        }
        
        char oldName[512];
        
        // Remove current/old array entry
        for (int i = 0; i < g_aCache.Length; i++)
        {
            int iCache[paintsCache];
            g_aCache.GetArray(i, iCache[0]);
            
            if (StrEqual(sCommunityID, iCache[pC_sCommunityID], true) && StrEqual(sClass, iCache[pC_sClassName], true))
            {
                strcopy(oldName, sizeof(oldName), iCache[pC_sNametag]);
                if (g_bDebug)
                {
                    LogMessage("[UpdateClientArray] Player: \"%L\" - CommunityID: %s - Classname: %s - DefIndex: %d - Wear: %.4f - Seed: %d - Quality: %d - Nametag: %s", client, iCache[pC_sCommunityID], iCache[pC_sClassName], iCache[pC_iDefIndex], iCache[pC_fWear], iCache[pC_iSeed], iCache[pC_iQuality], iCache[pC_sNametag]);
                }
                
                g_aCache.Erase(i);
                break;
            }
        }
        
        // Insert new array entry
        int tmpCache[paintsCache];
        strcopy(tmpCache[pC_sCommunityID], WP_COMMUNITYID, sCommunityID);
        strcopy(tmpCache[pC_sClassName], WP_CLASSNAME, sClass);
        tmpCache[pC_iDefIndex] = defIndex;
        tmpCache[pC_fWear] = fWear;
        tmpCache[pC_iSeed] = iSeed;
        tmpCache[pC_iQuality] = iQuality;
        
        if(strlen(sNametag) > 2 && !StrEqual(sNametag, "delete", false))
            strcopy(tmpCache[pC_sNametag], 128, sNametag);
        else if (StrEqual(sNametag, "delete", false))
            Format(tmpCache[pC_sNametag], 128, "");
        else
            strcopy(tmpCache[pC_sNametag], 128, oldName);
        
        if (g_bDebug)
        {
            PrintToChat(client, "nametag: %s new: %s", tmpCache[pC_sNametag], sNametag);
        }
        g_aCache.PushArray(tmpCache[0]);
    }
}

bool IsValidDef(int client, int defIndex, bool message = false)
{
    if (defIndex == 0)
    {
        return false;
    }
    else if (defIndex == 42 || defIndex == 59)
    {
        if (message)
        {
            PrintToChat(client, "%T", "Cant change", client, "Knife");
        }
        
        return false;
    }
    else if (defIndex == 49)
    {
        if (!g_bChangeC4)
        {
            if (message)
            {
                PrintToChat(client, "%T", "Cant change", client, "C4");
            }
        
            return false;
        }
    }
    else if (defIndex >= 43 && defIndex <= 48)
    {
        if (!g_bChangeGrenade)
        {
            if (message)
            {
                PrintToChat(client, "%T", "Cant change", client, "Grenades");
            }
        
            return false;
        }
    }
    else if (defIndex == 31)
    {
        if (!g_bChangeGrenade)
        {
            if (message)
            {
                PrintToChat(client, "%T", "Cant change", client, "Zeus");
            }
        
            return false;
        }
    }
    
    return true;
}

void AddWeaponSkinsToMenu(Menu menu, int client, int weapon = -1, bool activeWeapon = true, int wDefIndex = -1)
{
    int iSkins[skinsList];
    
    delete g_aSkins;
    g_aSkins = new ArrayList(sizeof(iSkins));
    
    for (int i = 0; i <= CSGOItems_GetSkinCount(); i++)
    {
        int defIndex = CSGOItems_GetSkinDefIndexBySkinNum(i);
        
        char sDefIndex[12], sDisplay[WP_DISPLAY];
        IntToString(defIndex, sDefIndex, sizeof(sDefIndex));
        
        CSGOItems_GetSkinDisplayNameByDefIndex(defIndex, sDisplay, sizeof(sDisplay));
        
        if (defIndex < 1 || CSGOItems_IsSkinNumGloveApplicable(i))
        {
            continue;
        }
        
        int skins[skinsList];
        
        skins[siDef] = defIndex;
        strcopy(skins[ssDef], 12, sDefIndex);
        strcopy(skins[ssName], WP_DISPLAY, sDisplay);
        
        g_aSkins.PushArray(skins[0]);
    }
    
    SortADTArrayCustom(g_aSkins, Sort_Skins);

    char sBuffer[18];
    Format(sBuffer, sizeof(sBuffer), "%T", "Default", client);
    
    if (weapon > 0 && GetEntProp(weapon, Prop_Send, "m_nFallbackPaintKit") != 0)
    {
        menu.AddItem("0", sBuffer);
    }
    else
    {
        menu.AddItem("0", sBuffer, ITEMDRAW_DISABLED);
    }
    
    Format(sBuffer, sizeof(sBuffer), "%T", "Random", client);
    menu.AddItem("1", sBuffer);
    
    for (int i = 0; i < g_aSkins.Length; i++)
    {
        int iSkins2[skinsList];
        g_aSkins.GetArray(i, iSkins2[0]);
        
        if (IsValidEntity(weapon) && activeWeapon)
        {
            int isDef = GetEntProp(weapon, Prop_Send, "m_nFallbackPaintKit");

            if (g_bDebug)
            {
                char sDisplay[WP_DISPLAY];
                CSGOItems_GetWeaponDisplayNameByDefIndex(CSGOItems_GetActiveWeaponDefIndex(client), sDisplay, sizeof(sDisplay));
                
                if (g_bDebug)
                {
                    PrintToChat(client, "(AddWeaponSkinsToMenu) Weapon: %s weaponIndex: %d, defIndex: %d", sDisplay, CSGOItems_GetActiveWeapon(client), CSGOItems_GetActiveWeaponDefIndex(client));
                }
            }
            
            char sEntry[WP_DISPLAY + 8];
            Format(sEntry, sizeof(sEntry), "[%d] %s", iSkins2[siDef], iSkins2[ssName]);
            
            if (StrEqual(iSkins2[ssName], "default", false))
            {
                continue;
            }

            if (!g_bAllSkins[client])
            {
                int iWeaponNum = CSGOItems_GetWeaponNumByWeapon(weapon);
                int iSkinNum = CSGOItems_GetSkinNumByDefIndex(iSkins2[siDef]);

                if (!CSGOItems_IsNativeSkin(iSkinNum, iWeaponNum, ITEMTYPE_WEAPON))
                {
                    continue;
                }
            }
            
            if(iSkins2[siDef] != isDef)
            {
                if (g_bDebug)
                {
                    PrintToChat(client, "iSkins2: %d [%s] - isDef: %d", iSkins2[siDef], iSkins2[ssDef], isDef);
                }
                
                if (!g_bDebug)
                {
                    menu.AddItem(iSkins2[ssDef], iSkins2[ssName]);
                }
                else
                {
                    menu.AddItem(iSkins2[ssDef], sEntry);
                }
            }
            else
            {
                if (!g_bDebug)
                {
                    menu.AddItem(iSkins2[ssDef], iSkins2[ssName], ITEMDRAW_DISABLED);
                }
                else
                {
                    menu.AddItem(iSkins2[ssDef], sEntry, ITEMDRAW_DISABLED);
                }
            }
        }
        else
        {
            if (g_bDebug)
            {
                char sDisplay[WP_DISPLAY];
                CSGOItems_GetWeaponDisplayNameByDefIndex(CSGOItems_GetActiveWeaponDefIndex(client), sDisplay, sizeof(sDisplay));
                
                if (g_bDebug)
                {
                    PrintToChat(client, "(AddWeaponSkinsToMenu) Weapon: %s weaponIndex: %d, defIndex: %d", sDisplay, CSGOItems_GetActiveWeapon(client), CSGOItems_GetActiveWeaponDefIndex(client));
                }
            }
            
            char sEntry[WP_DISPLAY + 8];
            Format(sEntry, sizeof(sEntry), "[%d] %s", iSkins2[siDef], iSkins2[ssName]);
            
            if (g_bDebug)
            {
                PrintToChat(client, "iSkins2: %d [%s]", iSkins2[siDef], iSkins2[ssDef]);
            }

            if (!g_bAllSkins[client])
            {
                int iWeaponNum = CSGOItems_GetWeaponNumByDefIndex(wDefIndex);
                int iSkinNum = CSGOItems_GetSkinNumByDefIndex(iSkins2[siDef]);

                if (!CSGOItems_IsNativeSkin(iSkinNum, iWeaponNum, ITEMTYPE_WEAPON))
                {
                    continue;
                }
            }
            
            if (!g_bDebug)
            {
                menu.AddItem(iSkins2[ssDef], iSkins2[ssName]);
            }
            else
            {
                menu.AddItem(iSkins2[ssDef], sEntry);
            }
        }
    }
}

public int Sort_Skins(int i, int j, Handle array, Handle hndl)
{
    int iTemp1[skinsList];
    int iTemp2[skinsList];

    g_aSkins.GetArray(i, iTemp1[0]);
    g_aSkins.GetArray(j, iTemp2[0]);

    return strcmp(iTemp1[ssName], iTemp2[ssName]);
}

public int Sort_Weapons(int i, int j, Handle array, Handle hndl)
{
    int iTemp1[weaponsList];
    int iTemp2[weaponsList];

    g_aWeapons.GetArray(i, iTemp1[0]);
    g_aWeapons.GetArray(j, iTemp2[0]);

    return strcmp(iTemp1[ssName], iTemp2[ssName]);
}

bool CanChange(int client)
{
    if (((g_iLastChange[client] + g_cInterval.IntValue) <= GetTime()) || g_iLastChange[client] == -1)
    {
        g_iLastChange[client] = GetTime();
        return true;
    }
    
    int iLeft = (GetTime() - g_iLastChange[client] - g_cInterval.IntValue) * -1;
    
    if (iLeft == 1)
    {
        CPrintToChat(client, "%T", "Remaining One", client, OUTBREAK);
    }
    else
    {
        CPrintToChat(client, "%T", "Remaining", client, OUTBREAK, iLeft);
    }
    
    return false;
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
