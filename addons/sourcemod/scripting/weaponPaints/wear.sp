static int g_iWeapon[MAXPLAYERS + 1] =  { -1, ... };
static int g_iDefIndex[MAXPLAYERS + 1] =  { -1, ... };
static int g_iSite[MAXPLAYERS + 1] =  { 0, ... };

void ChangeWearMenu(int client)
{
    g_iWeapon[client] = CSGOItems_GetActiveWeapon(client);
    g_iDefIndex[client] = CSGOItems_GetActiveWeaponDefIndex(client);
    
    float fWear = GetEntPropFloat(g_iWeapon[client], Prop_Send, "m_flFallbackWear");
    
    char sDisplay[WP_DISPLAY];
    CSGOItems_GetWeaponDisplayNameByDefIndex(g_iDefIndex[client], sDisplay, sizeof(sDisplay));
    
    Menu menu = new Menu(Menu_ChangeWear);

    char sDefault[18];
    Format(sDefault, sizeof(sDefault), "%T", "Default Wear", client);
    
    menu.SetTitle("%T", "Adjust Wear", client, sDisplay, fWear);
    menu.AddItem("default", sDefault);
    menu.AddItem("+1.0", "+1");
    menu.AddItem("+0.1", "+0,1");
    menu.AddItem("+0.01", "+0,01");
    menu.AddItem("-0.01", "-0,01");
    menu.AddItem("-0.1", "-0,1");
    menu.AddItem("-1.0", "-1");
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    
    menu.DisplayAt(client, g_iSite[client], MENU_TIME_FOREVER);
}


public int Menu_ChangeWear(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        if (!IsValidEntity(g_iWeapon[client]))
        {
            return;
        }

        g_iSite[client] = menu.Selection;
        
        if (CanChange(client))
        {
            char sValue[12];
            menu.GetItem(param, sValue, sizeof(sValue));
            
            if (StrEqual(sValue, "default", false))
            {
                SetClientWear(client, g_iWeapon[client], g_iDefIndex[client], DEFAULT_WEAR);
            }
            else if (ReplaceString(sValue, sizeof(sValue), "+", "") > 0)
            {
                float fWear = GetEntPropFloat(g_iWeapon[client], Prop_Send, "m_flFallbackWear");
                float fBuf = StringToFloat(sValue);
                
                fBuf += fWear;
                
                if(fBuf > 0.001 && fBuf < 1.0)
                {
                    SetClientWear(client, g_iWeapon[client], g_iDefIndex[client], fBuf);
                }
                else
                {
                    SetClientWear(client, g_iWeapon[client], g_iDefIndex[client], 1.0);
                }
            }
            else if (ReplaceString(sValue, sizeof(sValue), "-", "") > 0)
            {
                float fWear = GetEntPropFloat(g_iWeapon[client], Prop_Send, "m_flFallbackWear");
                float fBuf = StringToFloat(sValue);
                
                fWear -= fBuf;
                
                if(fWear > 0.001 && fWear < 1.0)
                {
                    SetClientWear(client, g_iWeapon[client], g_iDefIndex[client], fWear);
                }
                else
                {
                    SetClientWear(client, g_iWeapon[client], g_iDefIndex[client], DEFAULT_WEAR);
                }
            }
            
            g_iDefIndex[client] = -1;
            g_iWeapon[client] = -1;
        }
        else
        {
            ChangeWearMenu(client);
        }
    }
    else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
    {
        Command_WS(client, 0);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void SetClientWear(int client, int iWeapon, int defIndex, float fWear)
{
    char sWeapon[WP_DISPLAY], sClass[WP_CLASSNAME];
    CSGOItems_GetWeaponDisplayNameByDefIndex(defIndex, sWeapon, sizeof(sWeapon));
    CSGOItems_GetWeaponClassNameByDefIndex(defIndex, sClass, sizeof(sClass));
    
    if (!IsValidDef(client, defIndex, true))
    {
        Command_WS(client, 0);
        return;
    }
    
    int iDef = GetEntProp(iWeapon, Prop_Send, "m_nFallbackPaintKit");
    
    if (g_bDebug)
    {
        PrintToChat(client, "You've choosen: [%d/%d] %s and wear: %.4f", defIndex, iDef, sWeapon, fWear);
    }
    
    int iSeed = GetEntProp(iWeapon, Prop_Send, "m_nFallbackSeed");
    int iClip = GetEntData(iWeapon, g_iClip1);
    int iAmmo = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
    
    char sNametag[128];
    GetEntDataString(iWeapon, FindSendPropInfo("CBaseAttributableItem", "m_szCustomName"), sNametag, sizeof(sNametag));
    
    UpdateClientArray(client, sClass, iDef, fWear, iSeed, DEFAULT_QUALITY, sNametag);
    UpdateClientMySQL(client, sClass, iDef, fWear, iSeed, DEFAULT_QUALITY, sNametag);
    
    bool bSuccess = CSGOItems_RemoveWeapon(client, iWeapon);
        
    if (bSuccess)
    {
        DataPack pack = new DataPack();
        RequestFrame(Frame_GivePlayerItem, pack);
        pack.WriteCell(GetClientUserId(client));
        pack.WriteString(sClass);
        pack.WriteCell(3);
        pack.WriteCell(iClip);
        pack.WriteCell(iAmmo);
        pack.WriteCell(true);
    }
}
