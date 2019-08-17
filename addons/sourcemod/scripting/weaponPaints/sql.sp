public void OnSQLConnect(Handle owner, Handle hndl, const char[] error, any data)
{
    if (hndl == null)
    {
        SetFailState("(OnSQLConnect) Can't connect to mysql");
        return;
    }
    
    g_dDB = view_as<Database>(CloneHandle(hndl));

    LogMessage("[WeaponPaints] (OnSQLConnect) Connected to database (Handle: %d vs. g_dDB)", hndl, g_dDB);
    
    CreateTable();
}

void CreateTable()
{
    char sQuery[1024];
    Format(sQuery, sizeof(sQuery),
    "CREATE TABLE IF NOT EXISTS `weaponPaints` ( \
        `id` INT NOT NULL AUTO_INCREMENT, \
        `communityid` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL, \
        `classname` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL, \
        `defindex` int(11) NOT NULL DEFAULT '0', \
        `wear` FLOAT NOT NULL DEFAULT '%f', \
        `seed` int(11) NOT NULL DEFAULT '%d', \
        `quality` int(11) NOT NULL DEFAULT '%d', \
        `nametag` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL, \
        PRIMARY KEY (`id`), \
        UNIQUE KEY (`communityid`, `classname`) \
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;", DEFAULT_WEAR, DEFAULT_SEED, DEFAULT_QUALITY);
    
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
            LoadClientPaints(i);
        }
    }
}

void LoadClientPaints(int client)
{
    char sCommunityID[32];
    if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
    {
        return;
    }
    
    char sQuery[512];
    Format(sQuery, sizeof(sQuery), "SELECT communityid, classname, defindex, wear, seed, quality, nametag FROM weaponPaints WHERE communityid = \"%s\";", sCommunityID);
    
    if (g_bDebug)
    {
        LogMessage(sQuery);
    }
    
    g_dDB.Query(SQL_LoadClientPaints, sQuery, GetClientUserId(client));
}

public void SQL_LoadClientPaints(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null || strlen(error) > 0)
    {
        SetFailState("(SQL_LoadClientPaints) Fail at Query: %s", error);
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
                    char sClass[WP_CLASSNAME], sCommunityID[WP_COMMUNITYID], sNametag[128];
                    int iDefIndex, iSeed, iQuality;
                    float fWear;
                    
                    results.FetchString(0, sCommunityID, sizeof(sCommunityID));
                    results.FetchString(1, sClass, sizeof(sClass));
                    iDefIndex = results.FetchInt(2);
                    fWear = results.FetchFloat(3);
                    iSeed = results.FetchInt(4);
                    iQuality = results.FetchInt(5);
                    results.FetchString(6, sNametag, sizeof(sNametag));
                    
                    if (strlen(sClass) > 7)
                    {
                        Player pCache;
                        
                        strcopy(pCache.CommunityID, WP_COMMUNITYID, sCommunityID);
                        strcopy(pCache.ClassName, WP_CLASSNAME, sClass);
                        pCache.DefIndex = iDefIndex;
                        pCache.Wear = fWear;
                        pCache.Seed = iSeed;
                        pCache.Quality = iQuality;
                        strcopy(pCache.Nametag, 128, sNametag);
                        
                        g_aCache.PushArray(pCache);
                        
                        if (g_bDebug)
                        {
                            LogMessage("[SQL_LoadClientPaints] Player: \"%L\" - CommunityID: %s - Classname: %s - DefIndex: %d - Wear: %f - Seed: %d - Quality: %d - Nametag: %s", client, pCache.CommunityID, pCache.ClassName, pCache.DefIndex, pCache.Wear, pCache.Seed, pCache.Quality, pCache.Nametag);
                        }
                    }
                }
            }
        }
    }
}
