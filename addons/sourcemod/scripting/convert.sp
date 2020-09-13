#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <profiler>
#include <dynamic>

public Plugin myinfo = 
{
    name = "ItemsParser", 
    author = "Bara", 
    description = "Converts the english resource file and stuff inside items_games.txt will be merged", 
    version = "1.0.0", 
    url = "github.com/Bara"
};

public void OnPluginStart()
{
    Profiler profiler = new Profiler();
    profiler.Start();

    ConvertResourceFile("english");
    RebaseItemsGame();

    profiler.Stop();
    float fTime = profiler.Time;
    delete profiler;

    PrintToServer("OnPluginStart took %f seconds.", fTime);
}

void RebaseItemsGame()
{
    if (!CheckDirectory())
    {
        SetFailState("Can't create directory!");
        return;
    }

    LogMessage("Rebase `items_game.txt`");

    Profiler profiler = new Profiler();
    profiler.Start();

    char sFile[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sFile, sizeof(sFile), "data/itemparser/items_game.txt");

    Dynamic dItemsGame = Dynamic();
    dItemsGame.ReadKeyValues("scripts/items/items_game.txt", PLATFORM_MAX_PATH, ReadDynamicKeyValue);
    dItemsGame.GetDynamic("items");
    dItemsGame.GetDynamic("paint_kits");
    dItemsGame.GetDynamic("music_definitions");
    dItemsGame.GetDynamic("item_sets");
    dItemsGame.GetDynamic("sticker_kits");
    dItemsGame.GetDynamic("paint_kits_rarity");
    dItemsGame.GetDynamic("used_by_classes");
    dItemsGame.GetDynamic("attributes");
    dItemsGame.GetDynamic("prefabs");
    dItemsGame.WriteKeyValues(sFile, "items_game");
    dItemsGame.Dispose(true);

    profiler.Stop();
    float fTime = profiler.Time;
    delete profiler;

    PrintToServer("RebaseItemsGame took %f seconds.", fTime);
}

public Action ReadDynamicKeyValue(Dynamic obj, const char[] member, int depth)
{
    if (depth == 0)
    {
        return Plugin_Continue;
    }
    
    if (depth == 1)
    {
        if (StrEqual(member, "items"))
        {
            return Plugin_Continue;
        }
        else if (StrEqual(member, "paint_kits"))
        {
            return Plugin_Continue;
        }
        else if (StrEqual(member, "music_definitions"))
        {
            return Plugin_Continue;
        }
        else if (StrEqual(member, "item_sets"))
        {
            return Plugin_Continue;
        }
        else if (StrEqual(member, "sticker_kits"))
        {
            return Plugin_Continue;
        }
        else if (StrEqual(member, "paint_kits_rarity"))
        {
            return Plugin_Continue;
        }
        else if (StrEqual(member, "used_by_classes"))
        {
            return Plugin_Continue;
        }
        else if (StrEqual(member, "attributes"))
        {
            return Plugin_Continue;
        }
        else if (StrEqual(member, "prefabs"))
        {
            return Plugin_Continue;
        }
        else
        {
            return Plugin_Stop;
        }
    }
    
    return Plugin_Continue;
}

void ConvertResourceFile(const char[] language)
{
    if (!CheckDirectory())
    {
        SetFailState("Can't create directory!");
        return;
    }

    Profiler profiler = new Profiler();
    profiler.Start();

    LogMessage("Converting `csgo_%s.txt` to UTF-8", language);

    char sOriginal[PLATFORM_MAX_PATH + 1];
    Format(sOriginal, sizeof(sOriginal), "resource/csgo_%s.txt", language);

    char sModified[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sModified, sizeof(sModified), "data/itemparser/csgo_%s.txt", language);

    File fiOriginal = OpenFile(sOriginal, "rb");
    File fiModified = OpenFile(sModified, "wb");
    
    int iBytes;
    int iBuffer[4096];
    
    fiOriginal.Read(iBuffer, 1, 2);
    
    int iByte = 0;
    int iLasteByte = 0;
    
    while ((iBytes = fiOriginal.Read(iBuffer, sizeof(iBuffer), 2)) != 0)
    {
        for (int i = 0; i < iBytes; i++)
        {
            iByte = iBuffer[i];
            if (iByte > 255)
                iBuffer[i] = 32;
            
            if (iLasteByte == 92 && iByte == 34)
            {
                iBuffer[i-1] = 32;
                iBuffer[i] = 39;
            }
            
            iLasteByte = iBuffer[i];
        }
        fiModified.Write(iBuffer, iBytes, 1);
    }
    
    delete fiOriginal;
    delete fiModified;

    profiler.Stop();
    float fTime = profiler.Time;
    delete profiler;

    PrintToServer("ConvertResourceFile took %f seconds.", fTime);
}

bool CheckDirectory()
{
    char sBuffer[PLATFORM_MAX_PATH + 1];
    BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "data/itemparser");

    if (!DirExists(sBuffer))
    {
        return CreateDirectory(sBuffer, FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_O_READ|FPERM_O_EXEC);
    }

    return true;
}
