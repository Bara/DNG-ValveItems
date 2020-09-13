#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <csgoitems>
#include <clientprefs>
#include <multicolors>
#include <autoexecconfig>
#include <knifes>
#include <PTaH>

#pragma newdecls required

#define WP_COMMUNITYID 32
#define WP_CLASSNAME 32
#define WP_DISPLAY 128

#define DEFAULT_WEAR 0.00001
#define DEFAULT_SEED 0
#define DEFAULT_QUALITY 3
#define DEFAULT_FLAG ""

#define OUTBREAK "{darkblue}[DNG]{default}"

enum struct Skins {
    int IntDef;
    char StringDef[6];
    char Name[WP_DISPLAY];
}

enum struct Weapons {
    int IntDef;
    char StringDef[6];
    char Name[WP_DISPLAY];
}

enum struct Player {
    char CommunityID[32];
    char ClassName[32];
    char Nametag[128];
    float Wear;
    int DefIndex;
    int Seed;
    int Quality;
}

bool g_bDebug = false;
bool g_bChangeC4 = false;
bool g_bChangeGrenade = false;

int g_iLastChange[MAXPLAYERS + 1] =  { -1, ... };

Database g_dDB = null;

int g_iClip1 = -1;

// int g_iWeaponPSite[MAXPLAYERS + 1] =  { 0, ... };

ArrayList g_aCache = null;
ArrayList g_aSkins = null;
ArrayList g_aWeapons = null;
StringMap g_sExtraNames = null;

Handle g_hAllSkins = null;
bool g_bAllSkins[MAXPLAYERS + 1] = { false, ... };

ConVar g_cInterval = null;

int g_iNametag = -1;

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
    g_cInterval = AutoExecConfig_CreateConVar("weaponpaints_interval", "5", "Interval between changes");
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    
    if (g_aCache != null)
        g_aCache.Clear();
    
    g_aCache = new ArrayList(sizeof(Player));

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

    PTaH(PTaH_GiveNamedItemPost, Hook, GiveNamedItemPost);

    CreateTimer(5.0, Timer_SetValve);

    g_iNametag = FindSendPropInfo("CBaseAttributableItem", "m_szCustomName");
}

public Action Timer_SetValve(Handle timer)
{
    GameRules_SetProp("m_bIsValveDS", 1);
    GameRules_SetProp("m_bIsQuestEligible", 1);
    
    return Plugin_Stop;
}

public void OnClientPutInServer(int client)
{
    // SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);

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
            Player pCache;
            g_aCache.GetArray(i, pCache, sizeof(pCache));
            
            if (StrEqual(sCommunityID, pCache.CommunityID, true))
            {
                g_aCache.Erase(i);
            }
        }
    }
}

/* public void OnWeaponEquipPost(int client, int weapon)
{
    SetPaints(client, weapon);
} */

void GiveNamedItemPost(int client, const char[] classname, const CEconItemView item, int entity, bool OriginIsNULL, const float Origin[3])
{
    if (IsClientValid(client) && IsValidEntity(entity))
    {
        SetPaints(client, entity);
    }
}

public void OnMapStart()
{
    LogMessage("[WeaponPaints] Connect SQL OnMapStart");
    connectSQL();
    LoadExtraNames();
}

public Action Command_AllSkins(int client, int args)
{
    if(!IsClientValid(client))
    {
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
    
    if(g_iNametag > 0 && IsPlayerAlive(client))
    {
        Format(sBuffer, sizeof(sBuffer), "%T", "Menu Change nametag", client);
        menu.AddItem("nametag", sBuffer);
    }
    
    if (!g_bAllSkins[client])
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

void LoadExtraNames()
{
    char sFile[PREFIX_MAX_LENGTH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/skin_extra_names.cfg");

    KeyValues kvNames = new KeyValues("Skin-Extra-Names");

    if (!kvNames.ImportFromFile(sFile))
    {
        LogError("[Weapon Paints] (AddWeaponSkinsToMenu) Can't read \"%s\"! (ImportFromFile)", sFile);
        delete kvNames;
        return;
    }

    delete g_sExtraNames;
    g_sExtraNames = new StringMap();

    if (kvNames.GotoFirstSubKey(false))
    {
        do
        {
            char sID[12];
            char sName[WP_DISPLAY];

            kvNames.GetSectionName(sID, sizeof(sID));
            kvNames.GetString(NULL_STRING, sName, sizeof(sName));

            g_sExtraNames.SetString(sID, sName);

            if (g_bDebug)
            {
                LogMessage("[WeaponPaints] (AddWeaponSkinsToMenu) sID: %s, Name: %s", sID, sName);
            }
        }
        while (kvNames.GotoNextKey(false));
    }

    delete kvNames;
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
        
        Format(sQuery, sizeof(sQuery), "INSERT INTO weaponPaints (communityid, classname, defindex, wear, seed, quality, nametag) VALUES (\"%s\", \"%s\", '%d', %f, '%d', '%d', \"%s\") ON DUPLICATE KEY UPDATE  defindex = '%d', wear = %f, seed = '%d', quality = '%d', nametag = \"%s\";", sCommunityID, sClass, defIndex, fWear, iSeed, iQuality, sEName, defIndex, fWear, iSeed, iQuality, sEName);
        
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

void UpdateClientArray(int client, const char[] sClass, int defIndex, float fWear, int iSeed, int iQuality, char[] sNametag, bool giveWeapon = false)
{
    if (g_dDB != null)
    {
        char sCommunityID[WP_COMMUNITYID];
        
        if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
        {
            return;
        }
        
        char oldName[512];

        if (g_bDebug)
        {
            PrintToChat(client, "(UpdateClientArray) 1 - Nametag: %s", sNametag);
        }

        int iIndex = -1;
        
        // Remove current/old array entry
        for (int i = 0; i < g_aCache.Length; i++)
        {
            Player pCache;
            g_aCache.GetArray(i, pCache, sizeof(pCache));
            
            if (StrEqual(sCommunityID, pCache.CommunityID, true) && StrEqual(sClass, pCache.ClassName, true))
            {
                if (g_bDebug)
                {
                    PrintToChat(client, "------");
                    PrintToChat(client, "sCommunityID: %s, pCache.CommunityID: %s", sCommunityID, pCache.CommunityID);
                    PrintToChat(client, "sClass: %s, pCache.ClassName: %s", sClass, pCache.ClassName);
                }
                
                strcopy(oldName, sizeof(oldName), pCache.Nametag);
                if (g_bDebug)
                {
                    LogMessage("[UpdateClientArray] Player: \"%L\" - CommunityID: %s - Classname: %s - DefIndex: %d - Wear: %.4f - Seed: %d - Quality: %d - Nametag: %s", client, pCache.CommunityID, pCache.ClassName, pCache.DefIndex, pCache.Wear, pCache.Seed, pCache.Quality, pCache.Nametag);
                }
                
                // g_aCache.Erase(i);
                iIndex = i;

                if (g_bDebug)
                {
                    PrintToChat(client, "Erase: %d", i);
                    PrintToChat(client, "------");
                }

                break;
            }
        }

        if (g_bDebug)
        {
            PrintToChat(client, "(UpdateClientArray) Compare... sNametag: %s, oldName: %s", sNametag, oldName);
        }
        
        // Insert new array entry
        Player pCache;
        strcopy(pCache.CommunityID, WP_COMMUNITYID, sCommunityID);
        strcopy(pCache.ClassName, WP_CLASSNAME, sClass);
        pCache.DefIndex = defIndex;
        pCache.Wear = fWear;
        pCache.Seed = iSeed;
        pCache.Quality = iQuality;
        
        if(strlen(sNametag) > 2 && !StrEqual(sNametag, "delete", false))
            strcopy(pCache.Nametag, sizeof(Player::Nametag), sNametag);
        else if (StrEqual(sNametag, "delete", false))
            Format(pCache.Nametag, sizeof(Player::Nametag), "");
        else
        {
            strcopy(pCache.Nametag, sizeof(Player::Nametag), oldName);
        }
        
        if (g_bDebug)
        {
            PrintToChat(client, "pCache.Nametag: %s, sNametag: %s", pCache.Nametag, sNametag);
        }
        
        if (g_bDebug)
        {
            PrintToChat(client, "nametag: %s new: %s", pCache.Nametag, sNametag);
        }

        if (iIndex != -1)
        {
            g_aCache.SetArray(iIndex, pCache);
        }
        else
        {
            g_aCache.PushArray(pCache);
        }

        if (giveWeapon)
        {
            int iWeapon = CSGOItems_GetActiveWeapon(client);

            if (iWeapon != -1)
            {
                int iClip = GetEntData(iWeapon, g_iClip1);
                int iAmmo = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
                
                if (g_bDebug)
                {
                    CPrintToChat(client, "UpdateClientArray 2.1");
                }
                
                bool bSuccess = CSGOItems_RemoveWeapon(client, iWeapon);
                
                if (g_bDebug)
                {
                    CPrintToChat(client, "CSGOItems_RemoveWeapon: %d", bSuccess);
                }
                
                if (bSuccess)
                {
                    DataPack pack = new DataPack();
                    RequestFrame(Frame_GivePlayerItem, pack);
                    pack.WriteCell(GetClientUserId(client));
                    pack.WriteString(sClass);
                    pack.WriteCell(-1);
                    pack.WriteCell(iClip);
                    pack.WriteCell(iAmmo);
                    pack.WriteCell(true);
                }
                
                if (g_bDebug)
                {
                    CPrintToChat(client, "UpdateClientArray 2.2");
                }
            }
        }
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
    delete g_aSkins;
    g_aSkins = new ArrayList(sizeof(Skins));
    
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

        char sBuffer[32];
        if (g_sExtraNames.GetString(sDefIndex, sBuffer, sizeof(sBuffer)))
        {
            Format(sDisplay, sizeof(sDisplay), "%s %s", sDisplay, sBuffer);
        }
        
        Skins sSkins;
        
        sSkins.IntDef = defIndex;
        strcopy(sSkins.StringDef, 12, sDefIndex);
        strcopy(sSkins.Name, WP_DISPLAY, sDisplay);
        
        g_aSkins.PushArray(sSkins);
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
        Skins sSkins;
        g_aSkins.GetArray(i, sSkins, sizeof(sSkins));
        
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
            Format(sEntry, sizeof(sEntry), "[%d] %s", sSkins.IntDef, sSkins.Name);
            
            if (StrEqual(sSkins.Name, "default", false))
            {
                continue;
            }

            if (!g_bAllSkins[client])
            {
                int iWeaponNum = CSGOItems_GetWeaponNumByWeapon(weapon);
                int iSkinNum = CSGOItems_GetSkinNumByDefIndex(sSkins.IntDef);

                if (!CSGOItems_IsNativeSkin(iSkinNum, iWeaponNum, ITEMTYPE_WEAPON))
                {
                    continue;
                }
            }
            
            if(sSkins.IntDef != isDef)
            {
                if (g_bDebug)
                {
                    PrintToChat(client, "iSkins2: %d [%s] - isDef: %d", sSkins.IntDef, sSkins.StringDef, isDef);
                }
                
                if (!g_bDebug)
                {
                    menu.AddItem(sSkins.StringDef, sSkins.Name);
                }
                else
                {
                    menu.AddItem(sSkins.StringDef, sEntry);
                }
            }
            else
            {
                if (!g_bDebug)
                {
                    menu.AddItem(sSkins.StringDef, sSkins.Name, ITEMDRAW_DISABLED);
                }
                else
                {
                    menu.AddItem(sSkins.StringDef, sEntry, ITEMDRAW_DISABLED);
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
            Format(sEntry, sizeof(sEntry), "[%d] %s", sSkins.IntDef, sSkins.Name);
            
            if (g_bDebug)
            {
                PrintToChat(client, "iSkins2: %d [%s]", sSkins.IntDef, sSkins.StringDef);
            }

            if (!g_bAllSkins[client])
            {
                int iWeaponNum = CSGOItems_GetWeaponNumByDefIndex(wDefIndex);
                int iSkinNum = CSGOItems_GetSkinNumByDefIndex(sSkins.IntDef);

                if (!CSGOItems_IsNativeSkin(iSkinNum, iWeaponNum, ITEMTYPE_WEAPON))
                {
                    continue;
                }
            }
            
            if (!g_bDebug)
            {
                menu.AddItem(sSkins.StringDef, sSkins.Name);
            }
            else
            {
                menu.AddItem(sSkins.StringDef, sEntry);
            }
        }
    }
}

public int Sort_Skins(int i, int j, Handle array, Handle hndl)
{
    Skins sSkins1;
    Skins sSkins2;

    g_aSkins.GetArray(i, sSkins1, sizeof(sSkins1));
    g_aSkins.GetArray(j, sSkins2, sizeof(sSkins2));

    return strcmp(sSkins1.Name, sSkins2.Name);
}

public int Sort_Weapons(int i, int j, Handle array, Handle hndl)
{
    Weapons wWeapon1;
    Weapons wWeapon2;

    g_aWeapons.GetArray(i, wWeapon1, sizeof(wWeapon1));
    g_aWeapons.GetArray(j, wWeapon2, sizeof(wWeapon2));

    return strcmp(wWeapon1.Name, wWeapon2.Name);
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
