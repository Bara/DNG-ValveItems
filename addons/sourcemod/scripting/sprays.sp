/*
    ToDo
        Translations
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <emitsoundany>
#include <multicolors>
#include <csgoitems>
#include <autoexecconfig>

#pragma newdecls required

#define LoopClients(%1) for(int %1 = 1; %1 <= MaxClients; %1++) if(IsClientValid(%1))
#define PTAG "{darkblue}[DNG]{default}"

#define CATSIZE 32
#define SOUND_SPRAY "music/player/sprayer.mp3"
#define MAX_SPRAYS 1024
#define SPRAY_PATH_LENGTH PLATFORM_MAX_PATH * 2

enum sprayList
{
    String:sSpray[32],
    iPrecacheID,
    String:sCategory[32],
    String:_sFlag[32],
    bool:bValve
}

int g_iLastSprayed[MAXPLAYERS + 1];
int g_iSpray[MAXPLAYERS + 1] =  { 0, ... };
int g_iSprays[MAX_SPRAYS][sprayList];
int g_iCount = 1;

bool g_bDebug = false;

ConVar g_cDistance = null;
ConVar g_cTime = null;
ConVar g_cVIPTime = null;
ConVar g_cUse = null;
ConVar g_cFlag = null;
ConVar g_cValveFlag = null;
ConVar g_cEnableValve = null;
ConVar g_cEnableCustom = null;

Handle g_hCookie = null;
Handle g_hOnSpray = null;

char g_sFile[SPRAY_PATH_LENGTH];
char g_sFileAdd[SPRAY_PATH_LENGTH];
char g_sLog[SPRAY_PATH_LENGTH];

ArrayList g_aCategories = null;

public Plugin myinfo =
{
    name = "[Outbreak] Sprays",
    author = "Bara",
    description = "Use sprays in CSGO",
    version = "1.0.0",
    url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_hOnSpray = CreateGlobalForward("Sprays_OnClientSpray", ET_Event, Param_Cell, Param_Array);
    
    CreateNative("Sprays_GetClientSpray", Native_GetClientSpray);
    CreateNative("Sprays_SetClientSpray", Native_SetClientSpray);
    CreateNative("Sprays_ResetClientTime", Native_ResetClientTime);
    
    RegPluginLibrary("sprays");
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_hCookie = RegClientCookie("sprays_new", "Valve Sprays", CookieAccess_Private);
    
    RegConsoleCmd("sm_sprays", Command_Sprays);
    RegConsoleCmd("sm_myspray", Command_MySpray);
    
    HookEvent("player_spawn", Event_PlayerSpawn);

    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("plugin.sprays");
    g_cTime = AutoExecConfig_CreateConVar("sprays_time", "30", "Time to spray a new spray");
    g_cVIPTime = AutoExecConfig_CreateConVar("sprays_vip_time", "15", "Time to spray a new spray as vip");
    g_cDistance = AutoExecConfig_CreateConVar("sprays_distance", "115", "Max. distance from player");
    g_cUse = AutoExecConfig_CreateConVar("sprays_use", "1", "Spray with '+use'?", _, true, 0.0, true, 1.0);
    g_cFlag = AutoExecConfig_CreateConVar("sprays_flag", "", "Default flag for sprays");
    g_cValveFlag = AutoExecConfig_CreateConVar("sprays_valve_flag", "1", "Use VIP Flag to get access to valve sprays?", _, true, 0.0, true, 1.0);
    g_cEnableValve = AutoExecConfig_CreateConVar("sprays_enable_valve", "1", "Enable valve sprays?", _, true, 0.0, true, 1.0);
    g_cEnableCustom = AutoExecConfig_CreateConVar("sprays_enable_custom", "1", "Enable custom sprays?", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
    
    char sDate[16];
    FormatTime(sDate, sizeof(sDate), "%y-%m-%d");
    BuildPath(Path_SM, g_sFile, sizeof(g_sFile), "logs/sprays_%s.log", sDate);
    BuildPath(Path_SM, g_sFileAdd, sizeof(g_sFileAdd), "logs/sprays_add_%s.log", sDate);
    BuildPath(Path_SM, g_sLog, sizeof(g_sLog), "logs/sprays_add_debug_%s.log", sDate);

    if (g_aCategories != null)
    {
        delete g_aCategories;
    }

    g_aCategories = new ArrayList(CATSIZE);
    
    AddValveSprays();
}

public void CSGOItems_OnItemsSynced()
{
    AddValveSprays();
}

void AddValveSprays()
{
    if (!g_cEnableValve.BoolValue)
    {
        return;
    }
    
    int count = 0;
    for (int i = 0; i <= CSGOItems_GetSprayCount(); i++)
    {
        char sDisplay[64];
        CSGOItems_GetSprayDisplayNameBySprayNum(i, sDisplay, sizeof(sDisplay));
        
        char sVMT[SPRAY_PATH_LENGTH];
        CSGOItems_GetSprayVMTBySprayNum(i, sVMT, sizeof(sVMT));
        
        char sVTF[SPRAY_PATH_LENGTH];
        CSGOItems_GetSprayVTFBySprayNum(i, sVTF, sizeof(sVTF));
        
        if (strlen(sVMT) > 4)
        {
            bool bFound = false;
            for (int j = 1; j < g_iCount; j++)
            {
                if (StrEqual(g_iSprays[j][sSpray], sDisplay, false))
                {
                    bFound = true;
                    break;
                }
            }
            
            if (bFound)
            {
                continue;
            }
            
            char sPrecache[SPRAY_PATH_LENGTH];
            strcopy(sPrecache, sizeof(sPrecache), sVMT);
            ReplaceString(sPrecache, sizeof(sPrecache), "materials/", "");
            ReplaceString(sPrecache, sizeof(sPrecache), ".vmt", "");
            int iPrecache = PrecacheDecal(sPrecache, true);
            
            strcopy(g_iSprays[g_iCount][sSpray], sizeof(sDisplay), sDisplay);
            g_iSprays[g_iCount][iPrecacheID] = iPrecache;
            g_iSprays[g_iCount][bValve] = true;
            Format(g_iSprays[g_iCount][sCategory], CATSIZE, "Valve");
            
            if (g_bDebug)
            {
                LogToFile(g_sFileAdd, "[SPRAY] Name: %s, Category: %s, ID: %d, Decal: %s, PrecacheID: %d, isValve: %d", g_iSprays[g_iCount][sSpray], g_iSprays[g_iCount][sCategory], g_iCount, sPrecache, g_iSprays[g_iCount][iPrecacheID], g_iSprays[g_iCount][bValve]);
            }
            
            g_iCount++;
            count++;
        }
    }

    if (count > 0)
    {
        g_aCategories.PushString("Valve");
    }
    
    LoopClients(client)
    {
        OnClientCookiesCached(client);
    }
}

public void OnPluginEnd()
{
    LoopClients(client)
    {
        OnClientDisconnect(client);
    }
}

public void OnMapStart()
{
    PrecacheSound(SOUND_SPRAY, true);
    
    char sBuffer[256];
    Format(sBuffer, sizeof(sBuffer), "sound/%s", SOUND_SPRAY);
    AddFileToDownloadsTable(sBuffer);

    PrepareSpraysConfig();
}

void PrepareSpraysConfig()
{
    if (!g_cEnableCustom.BoolValue)
    {
        return;
    }

    char sFile[SPRAY_PATH_LENGTH];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/sprays.cfg");
    
    if (!FileExists(sFile))
    {
        LogError("Can't find file: %s", sFile);
        return;
    }

    KeyValues kv = new KeyValues("Sprays");
    kv.ImportFromFile(sFile);

    do
    {
        if (KvGotoFirstSubKey(kv))
        {
            GetSprays(kv);
            KvGoBack(kv);
        }
    } while (KvGotoNextKey(kv));

    if (g_bDebug)
    {
        LogToFile(g_sLog, "Categories:");
        for (int i = 0; i < g_aCategories.Length; i++)
        {
            char sCat[32];
            g_aCategories.GetString(i, sCat, sizeof(sCat));
            
            LogToFile(g_sLog, sCat);
        }
    }
}

public void OnClientPostAdminCheck(int client)
{
    g_iLastSprayed[client] = false;
}

public void OnClientCookiesCached(int client)
{
    char sBuffer[12];
    GetClientCookie(client, g_hCookie, sBuffer, sizeof(sBuffer));
    g_iSpray[client] = StringToInt(sBuffer);
}

public void OnClientDisconnect(int client)
{
    if(AreClientCookiesCached(client))
    {
        char sBuffer[12];
        Format(sBuffer, sizeof(sBuffer), "%i", g_iSpray[client]);
        SetClientCookie(client, g_hCookie, sBuffer);
    }
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) 
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (IsClientValid(client))
    {
        g_iLastSprayed[client] = false;
    }
}

public Action Command_Sprays(int client, int args)
{	
    ListCategories(client);
}

void ListCategories(int client)
{
    Menu menu = new Menu(Menu_ListCategories);
    
    menu.SetTitle("Wähle eine Kategorie:");
    menu.AddItem("0", "Zufälliges Spray");


    int count = 0;
    
    for (int i = 0; i < g_aCategories.Length; ++i)
    {
        char sCat[32];
        g_aCategories.GetString(i, sCat, sizeof(sCat));

        if (StrEqual(sCat, "Valve", false) && !g_cEnableValve.BoolValue)
        {
            continue;
        }
        
        if (!StrEqual(sCat, "Valve", false) && !g_cEnableCustom.BoolValue)
        {
            continue;
        }

        menu.AddItem(sCat, sCat);
        count++;

        if (g_bDebug)
        {
            PrintToChat(client, "Cat: %d, Count: %d", sCat, count);
        }
    }
    
    menu.ExitButton = true;

    if (count > 0)
    {
        menu.Display(client, 0);
    }
    else
    {
        delete menu;
    }
}

public int Menu_ListCategories(Handle menu, MenuAction action, int client, int param) 
{
    if (action == MenuAction_Select)
    {
        char sCat[32];
        GetMenuItem(menu, param, sCat, sizeof(sCat));

        if (!StrEqual(sCat, "0", false))
        {
            ListSprays(client, sCat);
        }
        else
        {
            g_iSpray[client] = StringToInt(sCat);
            SetClientCookie(client, g_hCookie, sCat);
            CPrintToChat(client, "%s Du hast ein zufälliges Spray ausgewählt.", PTAG);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ListSprays(int client, const char[] category)
{
    Menu menu = new Menu(Menu_ChangeSpray);
    
    menu.SetTitle("Wähle ein Spray:");
    
    for (int i = 1; i < g_iCount; ++i)
    {
        char sItem[6];
        IntToString(i, sItem, sizeof(sItem));

        if (!StrEqual(g_iSprays[i][sCategory], category, false))
        {
            continue;
        }
        
        if (!g_iSprays[i][bValve])
        {
            menu.AddItem(sItem, g_iSprays[i][sSpray]);
        }
        else if (g_iSprays[i][bValve] && (g_cValveFlag.BoolValue))
        {
            menu.AddItem(sItem, g_iSprays[i][sSpray]);
        }
    }
    
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, 0);
}

public Action Command_MySpray(int client, int args)
{
    if(!IsClientValid(client))
    {
        return Plugin_Handled;
    }
    
    if (g_iSprays[g_iSpray[client]][bValve] && !(g_cValveFlag.BoolValue))
    {
        CPrintToChat(client, "%s Dein Spray ist ungültig!", PTAG);
        g_iSpray[client] = 0;
        SetClientCookie(client, g_hCookie, "0");
        
        return Plugin_Handled;
    }
    
    if (g_iSpray[client] != 0)
    {
        CPrintToChat(client, "%s Dein Spray ist: {green}%s", PTAG, g_iSprays[g_iSpray[client]][sSpray]);
    }
    else
    {
        CPrintToChat(client, "%s Dein Spray ist: {green}Zufällig", PTAG);
    }
    
    return Plugin_Handled;
}

public int Menu_ChangeSpray(Handle menu, MenuAction action, int client, int param) 
{
    if (action == MenuAction_Select)
    {
        char info[4];
        GetMenuItem(menu, param, info, sizeof(info));
        
        g_iSpray[client] = StringToInt(info);
        SetClientCookie(client, g_hCookie, info);
        
        if (g_iSpray[client] != 0)
        {
            CPrintToChat(client, "%s Du hast %s als Spray ausgewählt.", PTAG, g_iSprays[g_iSpray[client]][sSpray]);
        }
        else
        {
            CPrintToChat(client, "%s Du hast ein zufälliges Spray ausgewählt.", PTAG);
        }
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_ExitBack)
        {
            ListCategories(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

stock bool GetPlayerEyeViewPoint(int client, float fPosition[3])
{
    float fAngles[3];
    GetClientEyeAngles(client, fAngles);

    float fOrigin[3];
    GetClientEyePosition(client, fOrigin);

    Handle hTrace = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    if(TR_DidHit(hTrace))
    {
        TR_GetEndPosition(fPosition, hTrace);
        delete hTrace;

        return true;
    }
    delete hTrace;

    return false;
}

public bool TraceEntityFilterPlayer(int iEntity, int iContentsMask)
{
    return iEntity > MaxClients;
}

void TE_SetupBSPDecal(const float fOrigin[3], int iIndex)
{
    TE_Start("World Decal");
    TE_WriteVector("m_vecOrigin", fOrigin);
    TE_WriteNum("m_nIndex", iIndex);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse)
{
    if(!g_cUse.BoolValue)
    {
        return;
    }
    
    if (buttons & IN_USE)
    {
        if(!IsPlayerAlive(client))
        {
            return;
        }

        int iRemain = (GetTime() - g_iLastSprayed[client]);
        
        int iDelay = g_cTime.IntValue;
        
        if (g_cValveFlag.BoolValue)
        {
            iDelay = g_cVIPTime.IntValue;
        }
        
        if(iRemain < iDelay || g_iLastSprayed[client] == -1)
        {
            return;
        }

        float fClientEyePosition[3];
        GetClientEyePosition(client, fClientEyePosition);

        float fClientEyeViewPoint[3];
        GetPlayerEyeViewPoint(client, fClientEyeViewPoint);

        float fVector[3];
        MakeVectorFromPoints(fClientEyeViewPoint, fClientEyePosition, fVector);

        if(GetVectorLength(fVector) > g_cDistance.FloatValue)
        {
            return;
        }

        Action res = Plugin_Continue;
        Call_StartForward(g_hOnSpray);
        Call_PushCell(client);
        Call_PushArray(fVector, 3);
        Call_Finish(res);

        if (res == Plugin_Handled || res == Plugin_Stop)
        {
            return;
        }

        if(g_iSpray[client] == 0)
        {
            int rand = GetRandomInt(1, g_iCount - 1);
            int spray = g_iSprays[rand][iPrecacheID];
            
            if (g_iSprays[rand][bValve] && !(g_cValveFlag.BoolValue))
            {
                g_iSpray[client] = 0;
                SetClientCookie(client, g_hCookie, "0");
                
                return;
            }
            
            TE_SetupBSPDecal(fClientEyeViewPoint, spray);

            if (g_bDebug)
            {
                void code = LogToFile(g_sFile, "[SPRAY] Player: %N, ID: %d, PrecacheID: %d", client, rand, spray);
                PrintToServer("[Spray] %d", code);
            }
        }
        else
        {
            if(g_iSprays[g_iSpray[client]][iPrecacheID] == 0)
            {
                CPrintToChat(client, "%s Ihr Spray funktioniert leider nicht. Wählen Sie ein neues mit '!sprays'.", PTAG);
                g_iSpray[client] = 0;
                SetClientCookie(client, g_hCookie, "0");
                
                return;
            }
            
            if (g_iSprays[g_iSpray[client]][bValve] && !(g_cValveFlag.BoolValue))
            {
                CPrintToChat(client, "%s Sie haben ein ungültiges Spray!", PTAG);
                g_iSpray[client] = 0;
                SetClientCookie(client, g_hCookie, "0");
                
                return;
            }
            
            TE_SetupBSPDecal(fClientEyeViewPoint, g_iSprays[g_iSpray[client]][iPrecacheID]);

            if (g_bDebug)
            {
                void code = LogToFile(g_sFile, "[SPRAY] Player: %N, ID: %d, PrecacheID: %d", client, g_iSpray[client], g_iSprays[g_iSpray[client]][iPrecacheID]);
                PrintToServer("[Spray] %d", code);
            }
        }
        TE_SendToAll();
        
        PostMessageAndSound(client, fVector);

        g_iLastSprayed[client] = GetTime();
    }
}

void PostMessageAndSound(int client, float[3] fVector)
{
    EmitAmbientSoundAny(SOUND_SPRAY, fVector, client, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);
}

public int Native_GetClientSpray(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    return g_iSpray[client];
}

public int Native_SetClientSpray(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    g_iSpray[client] = GetNativeCell(2);
    
    char sBuffer[12];
    IntToString(g_iSpray[client], sBuffer, sizeof(sBuffer));
    SetClientCookie(client, g_hCookie, sBuffer);
}

public int Native_ResetClientTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    g_iLastSprayed[client] = false;
}

void GetSprays(KeyValues kv, int level = 0, const char[] category = "", const char[] name = "")
{
    char sSection[32];
    char sValue[SPRAY_PATH_LENGTH];
    ArrayList array = new ArrayList(SPRAY_PATH_LENGTH);

    if (g_bDebug) LogToFile(g_sLog, "- Section start (level %d) -", level);
    do
    {
        kv.GetSectionName(sSection, sizeof(sSection));
        if (g_bDebug) LogToFile(g_sLog, "-- Current key: %s", sSection);
        if (kv.GotoFirstSubKey(false))
        {
            if (level == 0)
            {
                g_aCategories.PushString(sSection);
                GetSprays(kv, level + 1, sSection);
            }
            else if (level == 1)
            {
                GetSprays(kv, level + 1, category, sSection);
            }
            else
            {
                GetSprays(kv, level + 1);
            }
            kv.GoBack();
        }
        else
        {
            KvDataTypes dataType = KvGetDataType(kv, NULL_STRING);

            if (dataType != KvData_None)
            {
                if (!StrEqual(sSection, "flag", false))
                {
                    kv.GetString(NULL_STRING, sValue, sizeof(sValue));
                }
                else
                {
                    char sFlag[18];
                    g_cFlag.GetString(sFlag, sizeof(sFlag));
                    kv.GetString(NULL_STRING, sValue, sizeof(sValue), sFlag);
                }

                if (strlen(sValue) > 0)
                {
                    char sBuffer[SPRAY_PATH_LENGTH];
                    Format(sBuffer, sizeof(sBuffer), "%s;;%s", sSection, sValue);
                    array.PushString(sBuffer);
                    if (g_bDebug) LogToFile(g_sLog, "--- Regular key. (Category: %s, Name: %s) \"%s\"", category, name, sBuffer);
                }
            }
        }
    } while (kv.GotoNextKey(false));
    if (g_bDebug) LogToFile(g_sLog, "- Section end -");

    if (array.Length > 0)
    {
        if (g_bDebug)
        {
            LogToFile(g_sLog, "- Add spray start -");
            LogToFile(g_sLog, "- Category: %s -", category);
            LogToFile(g_sLog, "- Name: %s -", name);
        }


        // sSplit[0] - count, sSplit[1] - keyword, sSplit[2] - value
        char sSplit[12][12][SPRAY_PATH_LENGTH];

        for (int i = 0; i < array.Length; i++)
        {
            char sBuffer[SPRAY_PATH_LENGTH];
            array.GetString(i, sBuffer, sizeof(sBuffer));
            ExplodeString(sBuffer, ";;", sSplit[i], sizeof(sSplit[]), sizeof(sSplit[][]));
            if (g_bDebug) LogToFile(g_sLog, "- %s: %s -", sSplit[i][0], sSplit[i][1]);
        }

        AddSpray(name, category, sSplit);

        if (g_bDebug) LogToFile(g_sLog, "- Add spray end -");
    }

    delete array;
}

void AddSpray(const char[] name, const char[] category, const char values[12][12][SPRAY_PATH_LENGTH])
{
    bool bFound = false;
    for (int j = 1; j < g_iCount; j++)
    {
        if (StrEqual(g_iSprays[j][sSpray], name, false))
        {
            bFound = true;
            break;
        }
    }
    
    if (!bFound)
    {
        char sFile[SPRAY_PATH_LENGTH];
        Format(sFile, sizeof(sFile), "materials/%s.vmt", values[0][1]);
        
        if (!FileExists(sFile))
        {
            LogError("Can't find file: %s", sFile);
            return;
        }
        
        KeyValues kvVTF = CreateKeyValues("LightmappedGeneric");
        FileToKeyValues(kvVTF, sFile);
        kvVTF.GetString("$basetexture", values[0][1], (SPRAY_PATH_LENGTH), values[0][1]);
        delete kvVTF;
        
        char sFileVTF[SPRAY_PATH_LENGTH];
        Format(sFileVTF, sizeof(sFileVTF), "materials/%s.vtf", values[0][1]);
        
        AddFileToDownloadsTable(sFile);
        AddFileToDownloadsTable(sFileVTF);
        
        strcopy(g_iSprays[g_iCount][sSpray], (SPRAY_PATH_LENGTH), name);
        
        int iPrecache = PrecacheDecal(values[0][1], true);
        g_iSprays[g_iCount][iPrecacheID] = iPrecache;
        strcopy(g_iSprays[g_iCount][sCategory], CATSIZE, category);

        if (strlen(values[1][1]) > 0)
        {
            strcopy(g_iSprays[g_iCount][_sFlag], CATSIZE, values[1][1]);
        }

        g_iSprays[g_iCount][bValve] = false;
        
        if (g_bDebug)
        {
            LogToFile(g_sFileAdd, "[SPRAY] Name: %s, Category: %s, ID: %d, Decal: %s, PrecacheID: %d, isValve: %d, Flag: %s", g_iSprays[g_iCount][sSpray], g_iSprays[g_iCount][sCategory], g_iCount, values[0][1], g_iSprays[g_iCount][iPrecacheID], g_iSprays[g_iCount][bValve], g_iSprays[g_iCount][_sFlag]);
        }
        
        g_iCount++;
    }
    else
    {
        LogToFile(g_sLog, "- Spray \"%s\" already exists -", name);
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
