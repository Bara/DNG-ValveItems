void SetClientSkin(int client, int iWeapon = -1, int skinIndex, int defIndex, int iMenu, bool switchWeapon = true)
{
    char sDisplay[WP_DISPLAY], sWeapon[WP_DISPLAY], sClass[WP_CLASSNAME];
    CSGOItems_GetSkinDisplayNameByDefIndex(skinIndex, sDisplay, sizeof(sDisplay));
    
    CSGOItems_GetWeaponDisplayNameByDefIndex(defIndex, sWeapon, sizeof(sWeapon));
    CSGOItems_GetWeaponClassNameByDefIndex(defIndex, sClass, sizeof(sClass));
    
    if (!IsValidDef(client, defIndex, true))
    {
        Command_WS(client, 0);
        return;
    }
    
    if (g_bDebug)
    {
        PrintToChat(client, "You've choosen: [%d] %s for [%d] %s", skinIndex, sDisplay, defIndex, sWeapon);
    }
    
    CPrintToChat(client, "%T", "Choosed Skin", client, OUTBREAK, sDisplay, sWeapon);
    
    float fWear = DEFAULT_WEAR;
    int iSeed = DEFAULT_SEED;
    
    if (iWeapon == -1 && IsPlayerAlive(client))
    {
        for(int offset = 0; offset < 128; offset += 4)
        {
            int weapon = GetEntDataEnt2(client, FindSendPropInfo("CBasePlayer", "m_hMyWeapons") + offset);
            
            if (CSGOItems_IsValidWeapon(weapon))
            {
                int iwDef = CSGOItems_GetWeaponDefIndexByWeapon(weapon);
                
                if (defIndex == iwDef)
                {
                    iWeapon = weapon;
                    
                    if (CSGOItems_GetActiveWeaponDefIndex(client) == defIndex)
                    {
                        switchWeapon = true;
                    }
                    
                    break;
                }
            }
        }
    }
    
    char sNametag[128];

    bool updated = false;
    
    if (iWeapon != -1 && IsValidEntity(iWeapon) && IsPlayerAlive(client))
    {
        int iClip = GetEntData(iWeapon, g_iClip1);
        int iAmmo = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
        fWear = GetEntPropFloat(iWeapon, Prop_Send, "m_flFallbackWear");
        iSeed = GetEntProp(iWeapon, Prop_Send, "m_nFallbackSeed");
        
        if (g_iNametag > 0)
        {
            GetEntDataString(iWeapon, g_iNametag, sNametag, sizeof(sNametag));
        }
        
        bool bSuccess = CSGOItems_RemoveWeapon(client, iWeapon);
        if (g_bDebug)
        {
            PrintToChat(client, "preRemove");
        }
        if (bSuccess)
        {
            if (g_bDebug)
            {
                PrintToChat(client, "preRemove2");
            }

            if (!updated)
            {
                UpdateClientArray(client, sClass, skinIndex, fWear, iSeed, DEFAULT_QUALITY, sNametag);
                UpdateClientMySQL(client, sClass, skinIndex, fWear, iSeed, DEFAULT_QUALITY, sNametag);

                updated = true;
            }

            DataPack pack = new DataPack();
            RequestFrame(Frame_GivePlayerItem, pack);
            pack.WriteCell(GetClientUserId(client));
            pack.WriteString(sClass);
            pack.WriteCell(iMenu);
            pack.WriteCell(iClip);
            pack.WriteCell(iAmmo);
            pack.WriteCell(switchWeapon);
        }
    }
    
    if (updated)
    {
        UpdateClientArray(client, sClass, skinIndex, fWear, iSeed, DEFAULT_QUALITY, sNametag);
        UpdateClientMySQL(client, sClass, skinIndex, fWear, iSeed, DEFAULT_QUALITY, sNametag);
    }
}

public void Frame_GivePlayerItem(any pack)
{
    ResetPack(pack);
    int client = GetClientOfUserId(ReadPackCell(pack));
    char sClass[WP_CLASSNAME];
    ReadPackString(pack, sClass, sizeof(sClass));
    int iMenu = ReadPackCell(pack);
    int iClip = ReadPackCell(pack);
    int iAmmo = ReadPackCell(pack);
    bool bSwitch = view_as<bool>(ReadPackCell(pack));
    delete view_as<DataPack>(pack);
    
    if(IsClientValid(client))
    {
        int iWeapon = GivePlayerItem(client, sClass);
        EquipPlayerWeapon(client, iWeapon);
        
        SetEntData(iWeapon, g_iClip1, iClip);
        SetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", iAmmo);
        
        SetPaints(client, iWeapon);
        
        DataPack pack2 = new DataPack();
        RequestFrame(Frame_SetActionWeapon, pack2);
        pack2.WriteCell(GetClientUserId(client));
        pack2.WriteCell(iWeapon);
        pack2.WriteCell(iMenu);
        pack2.WriteCell(bSwitch);
    }
}

public void Frame_SetActionWeapon(any pack)
{
    ResetPack(pack);
    int client = GetClientOfUserId(ReadPackCell(pack));
    int weapon = ReadPackCell(pack);
    int iMenu = ReadPackCell(pack);
    bool bSwitch = view_as<bool>(ReadPackCell(pack));
    delete view_as<DataPack>(pack);
    
    if (IsClientValid(client) && CSGOItems_IsValidWeapon(weapon))
    {
        if (bSwitch)
        {
            CSGOItems_SetActiveWeapon(client, weapon);
        }
        
        if (iMenu == 1)
        {
            if (CheckMenuWeapon(client))
            {
                ChooseCurrentWeapon(client);
            }
        }
        else if (iMenu == 2)
        {
            int defIndex = CSGOItems_GetWeaponDefIndexByWeapon(weapon);
            ChooseWeaponSkin(client, defIndex);
        }
        else if (iMenu == 3)
        {
            if (CheckMenuWeapon(client))
            {
                ChangeWearMenu(client);
            }
        }
    }
}

void SetPaints(int client, int weapon)
{
    if (IsClientValid(client) && CSGOItems_IsValidWeapon(weapon) && IsPlayerAlive(client))
    {
        int iDef = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
        
        char sClass[WP_CLASSNAME];
        CSGOItems_GetWeaponClassNameByDefIndex(iDef, sClass, sizeof(sClass));
        
        if (g_aCache != null)
        {
            for (int i = 0; i < g_aCache.Length; i++)
            {
                Player pCache;
                g_aCache.GetArray(i, pCache, sizeof(pCache));
                
                char sCommunityID[WP_COMMUNITYID];
                
                if (!GetClientAuthId(client, AuthId_SteamID64, sCommunityID, sizeof(sCommunityID)))
                {
                    return;
                }
                
                if (StrEqual(sCommunityID, pCache.CommunityID, true) && StrEqual(sClass, pCache.ClassName, true))
                {
                    if (g_bDebug)
                    {
                        LogMessage("[OnWeaponEquipPost] Player: \"%L\" - CommunityID/cCommunityID: %s/%s - Classname/cClassname: %s/%s - DefIndex: %d - Wear: %.4f - Seed: %d - Quality: %d - Nametag: %s", client, sCommunityID, pCache.CommunityID, sClass, pCache.ClassName, pCache.DefIndex, pCache.Wear, pCache.Seed, pCache.Quality, pCache.Nametag);
                    }
                    
                    if(CSGOItems_IsDefIndexKnife(iDef) && (Knifes_GetIndex(client) < 1))
                    {
                        return;
                    }
                    
                    SetEntProp(weapon, Prop_Send, "m_iItemIDLow", -1);
                    static int IDHigh = 11111;
                    SetEntProp(weapon, Prop_Send, "m_iItemIDHigh", IDHigh++);
                    
                    if (pCache.DefIndex > 0)
                    {
                        if (pCache.DefIndex == 1)
                        {
                            SetEntProp(weapon, Prop_Send, "m_nFallbackPaintKit", CSGOItems_GetRandomSkin());
                        }
                        else
                        {
                            SetEntProp(weapon, Prop_Send, "m_nFallbackPaintKit", pCache.DefIndex);
                        }
                    }
                    
                    SetEntPropFloat(weapon, Prop_Send, "m_flFallbackWear", pCache.Wear);
                    SetEntProp(weapon, Prop_Send, "m_nFallbackSeed", pCache.Seed);
                    SetEntProp(weapon, Prop_Send, "m_iEntityQuality", pCache.Quality);
                    // m_nFallbackStatTrak for stattrak kills
                    // m_nFallbackSeed for pattern/seed
                    
                    if(g_iNametag > 0 && strlen(pCache.Nametag) > 2 && !StrEqual(pCache.Nametag, "delete", false))
                    {
                        SetEntDataString(weapon, g_iNametag,  pCache.Nametag, sizeof(Player::Nametag));
                    }
                    
                    if (g_bDebug)
                    {
                        LogMessage("[OnWeaponEquipPost (Equal)] Player: \"%L\" - Skin Index: %d", client, pCache.DefIndex);
                    }
                    
                    break;
                }
            }
        }
    }
}
