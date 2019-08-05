/*
    ToDo:
        Translations (untested!)
        clean up
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
#include <csgoitems>
#include <multicolors>
#include <autoexecconfig>
#include <groupstatus>
#include <PTaH>

#pragma newdecls required

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))
#define PTAG "{darkblue}[DNG]{default}"

#define CHANGE_INTERVAL 5
#define KNIFE_LENGTH 128

bool g_bDebug = false;

int g_iKnife[MAXPLAYERS + 1] =  { -1, ... };
int g_iSite[MAXPLAYERS + 1] =  { 0, ... };
int g_iLastChange[MAXPLAYERS + 1] =  { -1, ... };

ConVar g_cMessage = null;
ConVar g_cShowDisableKnifes = null;
ConVar g_cAllowThrow = null;
ConVar g_cGiveKnife = null;

Database g_dDB = null;

ArrayList g_aIgnore = null;

public Plugin myinfo = 
{
    name = "Knifes",
    author = "Bara",
    description = "",
    version = "1.0.0",
    url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Knifes_GetIndex", Native_GetIndex);

    RegPluginLibrary("knifes");

    return APLRes_Success;
}

public int Native_GetIndex(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    return g_iKnife[client];
}

public void OnPluginStart()
{
    LoadTranslations("knifes.phrases");
    LoadTranslations("groupstatus.phrases");
    
    RegConsoleCmd("sm_knife", Command_Knife);
    RegConsoleCmd("sm_knifes", Command_Knife);
    RegConsoleCmd("sm_rknife", Command_RKnife);
    
    RegAdminCmd("sm_aknife", Command_AKnife, ADMFLAG_ROOT);
    RegAdminCmd("sm_active", Command_Active, ADMFLAG_ROOT);
    RegAdminCmd("sm_dknife", Command_DKnife, ADMFLAG_ROOT);
    
    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("plugin.knifes");
    g_cMessage = AutoExecConfig_CreateConVar("knifes_show_message", "1", "Show message on knife selection", _, true, 0.0, true, 1.0);
    g_cShowDisableKnifes = AutoExecConfig_CreateConVar("knifes_show_disabled_knife", "1", "Show disabled knifes (for user without flag)", _, true, 0.0, true, 1.0);
    g_cAllowThrow = AutoExecConfig_CreateConVar("knifes_allow_throw", "0", "Allow throw of axe, spanner and wrench?", _, true, 0.0, true, 1.0);
    g_cGiveKnife = AutoExecConfig_CreateConVar("knifes_give_knife", "0", "Give knife to client if client doesn't have one.", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    
    LoopClients(i)
    {
        OnClientPutInServer(i);
    }
    
    connectSQL();

    LoadIgnoreIDs();

    PTaH(PTaH_GiveNamedItemPre, Hook, GiveNamedItemPre);
    PTaH(PTaH_GiveNamedItemPost, Hook, GiveNamedItemPost);
}

public void OnMapStart()
{
    connectSQL();

    LoadIgnoreIDs();
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

void LoadIgnoreIDs()
{
    delete g_aIgnore;
    g_aIgnore = new ArrayList();

    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/knifes_ignore.ini");

    File hFile = OpenFile(sFile, "rt");

    if (hFile == null)
    {
        SetFailState("[Knifes] Can't open File: %s", sFile);
    }

    char sLine[MAX_NAME_LENGTH];

    while (!hFile.EndOfFile() && hFile.ReadLine(sLine, sizeof(sLine)))
    {
        TrimString(sLine);
        StripQuotes(sLine);

        if (strlen(sLine) > 1)
        {
            g_aIgnore.Push(StringToInt(sLine));
        }
    }

    delete hFile;
}

public void OnClientPutInServer(int client)
{
    // SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
    SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitchPost);
    SDKHook(client, SDKHook_PreThink, OnPreThink);
}

public void OnClientPostAdminCheck(int client)
{
    if(IsClientValid(client))
    {
        LoadClientKnifes(client);
    }
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (IsValidEntity(entity))
    {
        char sClass[32];
        GetEntityClassname(entity, sClass, sizeof(sClass));

        if (StrContains(sClass, "knife", false) != -1 || StrContains(sClass, "bayonet", false) != -1)
        {
            RequestFrame(Frame_GetOwner, EntIndexToEntRef(entity));
        }
    }
}

public void Frame_GetOwner(int ref)
{
    int entity = EntRefToEntIndex(ref);

    if (IsValidEntity(entity))
    {
        char sClass[32];
        GetEntityClassname(entity, sClass, sizeof(sClass));

        int iOwner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

        if (!IsClientValid(iOwner))
        {
            AcceptEntityInput(entity, "Kill");
        }
    }
}

public void OnWeaponSwitchPost(int client, int weapon)
{
    if (g_cAllowThrow.BoolValue)
    {
        return;
    }

    if (!IsValidWeapon(weapon))
    {
        return;
    }

    if (IsClientValid(client) && IsPlayerAlive(client))
    {
        int iDef = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
        
        if (iDef == 75 || iDef == 76 || iDef == 78)
        {
            SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 99999999.9);
        }
    }
}

public Action OnPreThink(int client)
{
    if (g_cAllowThrow.BoolValue)
    {
        return;
    }

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    if (!IsValidWeapon(weapon))
    {
        return;
    }

    if (IsClientValid(client) && IsPlayerAlive(client))
    {
        int iDef = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
        
        if (iDef == 75 || iDef == 76 || iDef == 78)
        {
            SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 99999999.9);
        }
    }
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if (g_cAllowThrow.BoolValue)
    {
        return Plugin_Continue;
    }

    if (!IsValidWeapon(weapon))
    {
        return Plugin_Continue;
    }

    if (IsClientValid(client) && IsPlayerAlive(client))
    {
        if(buttons & IN_ATTACK2)
        {
            int iDef = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
            
            if (iDef == 75 || iDef == 76 || iDef == 78)
            {
                SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 99999999.9);
                buttons &= ~IN_ATTACK2;
                return Plugin_Changed;
            }
        }
    }

    return Plugin_Continue;
}

public void OnWeaponEquipPost(int client, int weapon)
{
    if (!IsValidWeapon(weapon))
    {
        return;
    }

    if (IsClientValid(client) && g_iKnife[client] > 0 && IsPlayerAlive(client))
    {
        int iDef = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
        
        if (CSGOItems_IsDefIndexKnife(iDef))
        {
            if (g_bDebug)
            {
                PrintToChat(client, "OnWeaponEquipPost1 - iDef: %d | g_iKnife: %d", iDef, g_iKnife[client]);
            }
            
            if (g_iKnife[client] < 1 && (iDef == 42 || iDef == 59))
            {
                return;
            }
            
            if (g_bDebug)
            {
                PrintToChat(client, "OnWeaponEquipPost2 - iDef: %d | g_iKnife: %d", iDef, g_iKnife[client]);
            }
            
            char sClassname[KNIFE_LENGTH], sClass[KNIFE_LENGTH];
            CSGOItems_GetWeaponClassNameByDefIndex(g_iKnife[client], sClassname, sizeof(sClassname));
            CSGOItems_GetWeaponClassNameByDefIndex(iDef, sClass, sizeof(sClass));
            
            if(!StrEqual(sClassname, sClass, false))
            {
                if (g_bDebug)
                {
                    PrintToChat(client, "OnWeaponEquipPost3 - iDef: %d (%s) | g_iKnife: %d (%s)", iDef, sClass, g_iKnife[client], sClassname);
                }
                
                ReplaceClientKnife(client);
                return;
            }
        }
    }
}

Action GiveNamedItemPre(int client, char classname[64], CEconItemView &item, bool &ignoredCEconItemView, bool &OriginIsNULL, float Origin[3])
{
    if (IsClientValid(client))
    {
        int iDef = CSGOItems_GetWeaponDefIndexByClassName(classname);

        char sClass[KNIFE_LENGTH];
        CSGOItems_GetWeaponClassNameByDefIndex(g_iKnife[client], sClass, sizeof(sClass));

        if (g_bDebug) PrintToChat(client, "GiveNamedItemPre - g_iKnife: %d, classname: %s, sClass: %s", g_iKnife[client], classname, sClass);
        
        if (g_iKnife[client] > 0 && CSGOItems_IsDefIndexKnife(iDef) && !StrEqual(classname, sClass, false))
        {
            ignoredCEconItemView = true;
            strcopy(classname, sizeof(classname), sClass);
            return Plugin_Changed;
        }
    }
    return Plugin_Continue;
}

void GiveNamedItemPost(int client, const char[] classname, const CEconItemView item, int entity, bool OriginIsNULL, const float Origin[3])
{
    if (IsClientValid(client) && IsValidEntity(entity))
    {
        if (g_iKnife[client] < 1)
        {
            return;
        }

        int iDef = CSGOItems_GetWeaponDefIndexByClassName(classname);

        if (CSGOItems_IsDefIndexKnife(iDef))
        {
            SetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex", iDef);
            EquipPlayerWeapon(client, entity);
        }
    }
}

public Action Command_DKnife(int client, int args)
{
    if (g_bDebug)
    {
        g_bDebug = false;
    }
    else
    {
        g_bDebug = true;
    }
    
    CPrintToChat(client, "%s Debug: {yellow}%d", PTAG, g_bDebug);
    
    CPrintToChat(client, "%s Items Synced: {yellow}%d", PTAG, CSGOItems_AreItemsSynced());
}

public Action Command_AKnife(int client, int args)
{
    if (args != 1)
    {
        ReplyToCommand(client, "sm_aknife <#UserID|Name>");
        return Plugin_Handled;
    }
    
    int targets[129];
    bool ml = false;
    char buffer[MAX_NAME_LENGTH], arg1[MAX_NAME_LENGTH], arg2[5];
    
    GetCmdArg(1, arg1, sizeof(arg1));
    GetCmdArg(2, arg2, sizeof(arg2));

    int count = ProcessTargetString(arg1, client, targets, sizeof(targets), COMMAND_FILTER_CONNECTED, buffer, sizeof(buffer), ml);
    if (count <= 0)
    {
        ReplyToCommand(client, "Invalid Target");
        return Plugin_Handled;
    }
    else for (int i = 0; i < count; i++)
    {
        int target = targets[i];
        
        if(!IsClientValid(target))
        {
            return Plugin_Handled;
        }
        
        int iDef = g_iKnife[target];
        char sDisplay[KNIFE_LENGTH];
        
        if (iDef > 0)
        {
            CSGOItems_GetWeaponDisplayNameByDefIndex(iDef, sDisplay, sizeof(sDisplay));
        }
        
        if (iDef == 42 || iDef == 59)
        {
            CPrintToChat(client, "%T", "Target Default Knife", client, PTAG, target);
        }
        else
        {
            if (IsPlayerAlive(target))
            {
                char sWeapon[32];
                
                int iWeapon = -1;
                while((iWeapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE)) != -1)
                {
                    if (IsValidWeapon(iWeapon))
                    {
                        int def = CSGOItems_GetWeaponDefIndexByWeapon(iWeapon);
                        
                        if (CSGOItems_IsDefIndexKnife(def))
                        {
                            CSGOItems_GetWeaponClassNameByDefIndex(def, sWeapon, sizeof(sWeapon));
                            break;
                        }
                    }
                }
                
                CPrintToChat(client, "%T", "Target Knife Active", client, PTAG, target, sDisplay, sWeapon);
            }
            else
            {
                CPrintToChat(client, "%T", "Target Knife", client, PTAG, target, sDisplay);
            }
        }
    }
    
    return Plugin_Continue;
}

public Action Command_Active(int client, int args)
{
    if (!IsClientValid(client))
    {
        return Plugin_Handled;
    }

    int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

    if (IsValidEntity(iWeapon))
    {
        ReplyToCommand(client, "Weapon Index: %d", iWeapon);
    }

    return Plugin_Handled;
}

public Action Command_Knife(int client, int args)
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
    
    ShowKnifeMenu(client);
    
    return Plugin_Continue;
}

public Action Command_RKnife(int client, int args)
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
    
    char sCommunityID[32];
            
    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
    {
        LogError("Auth failed for client index %d", client);
        return Plugin_Handled;
    }
    
    char sQuery[2048];
    
    Format(sQuery, sizeof(sQuery), "DELETE FROM `knifes` WHERE communityid = \"%s\";", sCommunityID);
    
    if (g_bDebug)
    {
        LogMessage(sQuery);
    }
    
    g_dDB.Query(Knife_DeletePlayer, sQuery, GetClientUserId(client));
    
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    RequestFrame(Frame_PlayerSpawn, event.GetInt("userid"));
}

public void Frame_PlayerSpawn(any userid)
{
    int client = GetClientOfUserId(userid);
    
    if (IsClientValid(client) && IsPlayerAlive(client) && g_iKnife[client] > 0)
    {
        if (g_bDebug)
        {
            PrintToChat(client, "Frame_PlayerSpawn");
        }
        ReplaceClientKnife(client);
    }
}

public void Frame_OpenMenu(any userid)
{
    int client = GetClientOfUserId(userid);
    
    if (IsClientValid(client))
    {
        ShowKnifeMenu(client);
    }
}

void ShowKnifeMenu(int client)
{
    Menu menu = new Menu(Menu_Knife);
    
    if (g_iKnife[client] > 0)
    {
        char sDisplay[KNIFE_LENGTH];
        CSGOItems_GetWeaponDisplayNameByDefIndex(g_iKnife[client], sDisplay, sizeof(sDisplay));
        
        if(g_iKnife[client] == 59)
        {
            Format(sDisplay, sizeof(sDisplay), "%T", "T Knife", client, sDisplay);
        }
        
        menu.SetTitle("%T", "Choose a Knife Currently", client, sDisplay);
    }
    
    int iDef = CSGOItems_GetActiveWeaponDefIndex(client);
    
    if (g_bDebug)
    {
        PrintToChat(client, "ShowKnifeMenu Def: %d", CSGOItems_GetActiveWeaponDefIndex(client));
    }
    
    if (iDef != 42 && iDef != 59)
    {
        menu.AddItem("0", "Default");
    }
    else if (g_iKnife[client] < 1)
    {
        menu.SetTitle("%T", "Choose a Knife Currently", client, "Default");
        menu.AddItem("0", "Default", ITEMDRAW_DISABLED);
    }
    else
    {
        menu.SetTitle("%T", "Choose a Knife Currently", client, "Default");
        menu.AddItem("0", "Default", ITEMDRAW_DISABLED);
    }

    int iCount = CSGOItems_GetWeaponCount();
    
    for (int i = 0; i <= iCount; i++)
    {
        int defIndex = CSGOItems_GetWeaponDefIndexByWeaponNum(i);
        
        if(CSGOItems_IsDefIndexKnife(defIndex))
        {
            char sClassName[KNIFE_LENGTH], sDisplayName[KNIFE_LENGTH];
            CSGOItems_GetWeaponClassNameByDefIndex(defIndex, sClassName, sizeof(sClassName));
            CSGOItems_GetWeaponDisplayNameByDefIndex(defIndex, sDisplayName, sizeof(sDisplayName));

            if (g_bDebug)
            {
                PrintToConsole(client, "DefIndex: %d, className: %s, displayName: %s", defIndex, sClassName, sDisplayName);
            }
            
            if(defIndex == 59 || defIndex == 42)
            {
                Format(sDisplayName, sizeof(sDisplayName), "%T", "T Knife", client, sDisplayName);
                continue;
            }

            bool bContinue = false;

            if (g_aIgnore.Length > 0)
            {
                for (int j = 0; j < g_aIgnore.Length; j++)
                {
                    if (g_aIgnore.Get(j) == defIndex)
                    {
                        bContinue = true;
                        break;
                    }
                }
            }

            if (bContinue)
            {
                continue;
            }

            if (g_bDebug)
            {
                Format(sDisplayName, sizeof(sDisplayName), "[%d] %s", defIndex, sDisplayName);
            }
            
            if (g_iKnife[client] != defIndex)
            {
                menu.AddItem(sClassName, sDisplayName);
            }
            else if (g_iKnife[client] == defIndex || g_cShowDisableKnifes.BoolValue)
            {
                menu.AddItem(sClassName, sDisplayName, ITEMDRAW_DISABLED);
            }
        }
    }
    
    menu.ExitButton = true;
    menu.DisplayAt(client, g_iSite[client], MENU_TIME_FOREVER);
}

public int Menu_Knife(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (((g_iLastChange[client] + CHANGE_INTERVAL) <= GetTime()) || g_iLastChange[client] == -1)
        {
            char sClassname[KNIFE_LENGTH];
            menu.GetItem(param, sClassname, sizeof(sClassname));
            int defIndex = CSGOItems_GetWeaponDefIndexByClassName(sClassname);
            
            g_iLastChange[client] = GetTime();
            g_iKnife[client] = defIndex;
            UpdateClientKnife(client);
            
            if (g_cMessage.BoolValue)
            {
                char sDisplay[KNIFE_LENGTH];
                CSGOItems_GetWeaponDisplayNameByDefIndex(g_iKnife[client], sDisplay, sizeof(sDisplay));
                
                if (g_bDebug)
                {
                    PrintToChat(client, "Menu_Knife defIndex: %d - g_iKnife: %d - CSGOItems_GetActiveWeaponDefIndex: %d", defIndex, g_iKnife[client],CSGOItems_GetActiveWeaponDefIndex(client));
                }
                
                if (defIndex != 42 && defIndex != 59 && defIndex > 0)
                {
                    CPrintToChat(client, "%T", "Knife Choosed", client, PTAG, sDisplay);
                }
                else
                {
                    CPrintToChat(client, "%T", "Knife Choosed", client, PTAG, "Standard");
                }
            }
            
            g_iSite[client] = menu.Selection;
            
            if (IsPlayerAlive(client))
            {
                ReplaceClientKnife(client);
            }
        }
        else
        {
            int iLeft = (GetTime() - g_iLastChange[client] - CHANGE_INTERVAL) * -1;
            
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

public void OnSQLConnect(Handle owner, Handle hndl, const char[] error, any data)
{
    if (hndl == null)
    {
        SetFailState("(OnSQLConnect) Can't connect to mysql");
        return;
    }
    
    g_dDB = view_as<Database>(CloneHandle(hndl));
    
    CreateTable();
}

void CreateTable()
{
    char sQuery[1024];
    Format(sQuery, sizeof(sQuery),
    "CREATE TABLE IF NOT EXISTS `knifes` ( \
        `id` INT NOT NULL AUTO_INCREMENT, \
        `communityid` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL, \
        `defindex` int(11) NOT NULL DEFAULT '0', \
        PRIMARY KEY (`id`), \
        UNIQUE KEY (`communityid`) \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;");
    
    if (g_bDebug)
    {
        LogMessage(sQuery);
    }
    
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
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientValid(i))
        {
            LoadClientKnifes(i);
        }
    }
}

void LoadClientKnifes(int client)
{
    char sCommunityID[32];
    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
    {
        LogError("Auth failed for client index %d", client);
        return;
    }
    
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "SELECT defindex FROM knifes WHERE communityid = \"%s\" LIMIT 1;", sCommunityID);
    
    if (g_bDebug)
    {
        LogMessage(sQuery);
    }
    
    g_dDB.Query(SQL_LoadClientKnife, sQuery, GetClientUserId(client));
}

public void SQL_LoadClientKnife(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_LoadClientKnife) Fail at Query: %s", error);
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
                    g_iKnife[client] = results.FetchInt(0);
                }
            }
        }
    }
}

void UpdateClientKnife(int client)
{
    char sCommunityID[32];
            
    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
    {
        LogError("Auth failed for client index %d", client);
        return;
    }
    
    char sQuery[2048];
    
    Format(sQuery, sizeof(sQuery), "INSERT INTO knifes (communityid, defindex) VALUES (\"%s\", '%d') ON DUPLICATE KEY UPDATE defindex = '%d';", sCommunityID, g_iKnife[client], g_iKnife[client]);
    
    if (g_bDebug)
    {
        LogMessage(sQuery);
    }
    
    g_dDB.Query(Knife_OnUpdateClientArray, sQuery);
}

public void Knife_OnUpdateClientArray(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(Knife_OnUpdateClientArray) Fail at Query: %s", error);
        return;
    }
}

public void Knife_DeletePlayer(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(Knife_DeletePlayer) Fail at Query: %s", error);
        return;
    }
    
    int client = GetClientOfUserId(data);
    
    if (IsClientValid(client))
    {
        g_iKnife[client] = -1;
        ReplaceClientKnife(client);
    }
}

void ReplaceClientKnife(int client)
{
    if (g_bDebug) PrintToChat(client, "ReplaceClientKnife - 1");
    bool bRemove = RemoveKnife(client);
    if (g_bDebug) PrintToChat(client, "ReplaceClientKnife - 2, bRemove: %d", bRemove);
    
    if (g_cGiveKnife.BoolValue)
    {
        DataPack pack = new DataPack();
        RequestFrame(Frame_GivePlayerItem, pack);
        pack.WriteCell(GetClientUserId(client));
    }
}

public void Frame_GivePlayerItem(DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    char sClass[KNIFE_LENGTH];

    if (g_iKnife[client] > 0)
    {
        CSGOItems_GetWeaponClassNameByDefIndex(g_iKnife[client], sClass, sizeof(sClass));
    }

    delete pack;
    
    if(IsClientValid(client))
    {
        int iWeapon = -1;
        
        if (strlen(sClass) > 2)
        {
            iWeapon = PTaH_GivePlayerItem(client, sClass);
            if (g_bDebug)  PrintToChat(client, "PTaH_GivePlayerItem sClass: %s", sClass);
        }
        else
        {
            iWeapon = GivePlayerItem(client, "weapon_knife");
            if (g_bDebug)  PrintToChat(client, "GivePlayerItem");
        }
        
        if (IsValidWeapon(iWeapon))
        {
            EquipPlayerWeapon(client, iWeapon);
        
            pack = new DataPack();
            RequestFrame(Frame_SetActionWeapon, pack);
            pack.WriteCell(GetClientUserId(client));
            pack.WriteCell(iWeapon);
        }
    }
}

public void Frame_SetActionWeapon(DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    int weapon = pack.ReadCell();
    delete pack;
    
    if (IsClientValid(client) && IsValidWeapon(weapon))
    {
        CSGOItems_SetActiveWeapon(client, weapon);
    }
}

stock bool IsClientValid(int client)
{
    if (client > 0 && client <= MaxClients)
    {
        if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
        {
            return true;
        }
    }
    
    return false;
}

bool IsValidWeapon(int weapon)
{
    if (weapon < 1)
    {
        return false;
    }

    if (!IsValidEntity(weapon))
    {
        return false;
    }

    if (!HasEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"))
    {
        return false;
    }

    return true;
}

bool RemoveKnife(int client)
{
    for(int offset = 0; offset < 128; offset += 4)
    {
        int weapon = GetEntDataEnt2(client, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);

        if (IsValidEntity(weapon))
        {
            char sClass[32];
            GetEntityClassname(weapon, sClass, sizeof(sClass));

            if ((StrContains(sClass, "melee", false) != -1) || (StrContains(sClass, "taser", false) != -1) || (StrContains(sClass, "knife", false) != -1) || (StrContains(sClass, "bayonet", false) != -1))
            {
                return SafeRemoveWeapon(client, weapon);
            }
        }
    }

    return false;
}

stock bool SafeRemoveWeapon(int iClient, int iWeapon)
{
    if (!IsValidEntity(iWeapon) || !IsValidEdict(iWeapon))
        return false;
    
    if (!HasEntProp(iWeapon, Prop_Send, "m_hOwnerEntity"))
        return false;
    
    int iOwnerEntity = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
    
    if (iOwnerEntity != iClient)
        SetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity", iClient);
    
    CS_DropWeapon(iClient, iWeapon, false);
    
    if (HasEntProp(iWeapon, Prop_Send, "m_hWeaponWorldModel"))
    {
        int iWorldModel = GetEntPropEnt(iWeapon, Prop_Send, "m_hWeaponWorldModel");
        
        if (IsValidEdict(iWorldModel) && IsValidEntity(iWorldModel))
            if (!AcceptEntityInput(iWorldModel, "Kill"))
                return false;
    }
    
    if (!AcceptEntityInput(iWeapon, "Kill"))
        return false;
    
    return true;
}
