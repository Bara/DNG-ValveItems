void ChangeNameTag(int client)
{
    char sDisplay[WP_DISPLAY];
    CSGOItems_GetWeaponDisplayNameByDefIndex(CSGOItems_GetActiveWeaponDefIndex(client), sDisplay, sizeof(sDisplay));
    
    Menu menu = new Menu(Menu_ChangeNametag);

    char sExit[18];
    Format(sExit, sizeof(sExit), "%T", "Exit", client);
    
    menu.SetTitle("%T", "Nametag Menu", client, sDisplay);
    menu.AddItem("exit", sExit);
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}


public int Menu_ChangeNametag(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
    {
        Command_WS(client, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action Command_Nametag(int client, int args)
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
    
    if(!IsPlayerAlive(client))
    {
        CPrintToChat(client, "%T", "Dead Player", client, OUTBREAK);
        return Plugin_Handled;
    }
    
    if (CanChange(client))
    {
        char sName[512];
        GetCmdArgString(sName, sizeof(sName));
        StripQuotes(sName);
        TrimString(sName);
        
        if (strlen(sName) < 3)
        {
            CPrintToChat(client, "%T", "Too short", client, OUTBREAK);
            return Plugin_Handled;
        }
        
        int iWeapon = CSGOItems_GetActiveWeapon(client);
        int iWDef = CSGOItems_GetActiveWeaponDefIndex(client);	
        
        char sWeapon[WP_DISPLAY], sClass[WP_CLASSNAME];
        CSGOItems_GetWeaponDisplayNameByDefIndex(iWDef, sWeapon, sizeof(sWeapon));
        CSGOItems_GetWeaponClassNameByDefIndex(iWDef, sClass, sizeof(sClass));
        
        if (g_bDebug)
        {
            CPrintToChat(client, "Command_Nametag 1");
        }
        
        if (!IsValidDef(client, iWDef, true))
        {
            if (g_bDebug)
            {
                CPrintToChat(client, "Weapon is invalid !?");
            }
            
            return Plugin_Handled;
        }
        
        if (g_bDebug)
        {
            CPrintToChat(client, "You're nametag of %s is now %s", sWeapon, sName);
        }
        
        int iDef = GetEntProp(iWeapon, Prop_Send, "m_nFallbackPaintKit");
        int iSeed = GetEntProp(iWeapon, Prop_Send, "m_nFallbackSeed");
        float fWear = GetEntPropFloat(iWeapon, Prop_Send, "m_flFallbackWear");
        
        if (g_bDebug)
        {
            CPrintToChat(client, "Command_Nametag 2 - Nametag: %s", sName);
        }
        
        UpdateClientArray(client, sClass, iDef, fWear, iSeed, DEFAULT_QUALITY, sName);
        UpdateClientMySQL(client, sClass, iDef, fWear, iSeed, DEFAULT_QUALITY, sName);
        
        if (g_bDebug)
        {
            CPrintToChat(client, "Command_Nametag 2 - iWeapon: %d", iWeapon);
        }
        
        if (iWeapon != -1)
        {
            int iClip = GetEntData(iWeapon, g_iClip1);
            int iAmmo = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
            
            if (g_bDebug)
            {
                CPrintToChat(client, "Command_Nametag 2.1");
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
                CPrintToChat(client, "Command_Nametag 2.2");
            }
        }
    }
    
    return Plugin_Continue;
}
