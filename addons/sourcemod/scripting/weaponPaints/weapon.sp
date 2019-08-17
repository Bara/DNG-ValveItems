static int g_iwDefIndex[MAXPLAYERS + 1] =  { -1, ... };
static int g_iSiteWeapons[MAXPLAYERS + 1] =  { 0, ... };
static int g_iSiteSkins[MAXPLAYERS + 1] =  { 0, ... };

void ChooseWeaponMenu(int client)
{
    Menu menu = new Menu(Menu_ChooseWeaponMenu);
    
    menu.SetTitle("%T", "Choose Weapon", client);
    
    AddWeaponsToMenu(client, menu);
    
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, g_iSiteWeapons[client], MENU_TIME_FOREVER);
}

public int Menu_ChooseWeaponMenu(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sDefIndex[12];
        menu.GetItem(param, sDefIndex, sizeof(sDefIndex));
        
        g_iwDefIndex[client] = StringToInt(sDefIndex);
        
        g_iSiteWeapons[client] = menu.Selection;
        
        ChooseWeaponSkin(client, g_iwDefIndex[client]);
        
        if (g_bDebug)
        {
            char sDisplay[WP_DISPLAY], sClass[WP_CLASSNAME];
            
            CSGOItems_GetWeaponClassNameByDefIndex(g_iwDefIndex[client], sClass, sizeof(sClass));
            CSGOItems_GetWeaponDisplayNameByDefIndex(g_iwDefIndex[client], sDisplay, sizeof(sDisplay));
            
            if (g_bDebug)
            {
                PrintToChat(client, "You've choosen: [%d/%s] %s ", g_iwDefIndex[client], sClass, sDisplay);
            }
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

void ChooseWeaponSkin(int client, int defIndex)
{
    Menu menu = new Menu(Menu_ChooseWeaponSkin);
    
    char sDisplay[WP_DISPLAY];
    CSGOItems_GetWeaponDisplayNameByDefIndex(defIndex, sDisplay, sizeof(sDisplay));
    
    g_iwDefIndex[client] = defIndex;
    
    menu.SetTitle("%T", "Choose Weapon Skin", client, sDisplay);
    
    AddWeaponSkinsToMenu(menu, client, _, false, defIndex);
    
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    menu.DisplayAt(client, g_iSiteSkins[client], MENU_TIME_FOREVER);
}

public int Menu_ChooseWeaponSkin(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        g_iSiteSkins[client] = menu.Selection;
        
        if (CanChange(client))
        {
            char sDefIndex[12];
            menu.GetItem(param, sDefIndex, sizeof(sDefIndex));
            
            int defIndex = StringToInt(sDefIndex);
            
            char sDisplay[WP_DISPLAY], swDisplay[WP_DISPLAY], sClass[WP_CLASSNAME];
            CSGOItems_GetSkinDisplayNameByDefIndex(defIndex, sDisplay, sizeof(sDisplay));
            CSGOItems_GetWeaponDisplayNameByDefIndex(g_iwDefIndex[client], swDisplay, sizeof(swDisplay));
            CSGOItems_GetWeaponClassNameByDefIndex(g_iwDefIndex[client], sClass, sizeof(sClass));
            
            if (g_bDebug)
            {
                PrintToChat(client, "You've choosen: [%d/%s] %s and skin: [%d] %s", g_iwDefIndex[client], sClass, swDisplay, defIndex, sDisplay);
            }
            
            SetClientSkin(client, -1, defIndex, g_iwDefIndex[client], 2, false);
            
            g_iwDefIndex[client] = -1;
        }
        else
        {
            ChooseWeaponSkin(client, g_iwDefIndex[client]);
        }
    }
    else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
    {
        ChooseWeaponMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void AddWeaponsToMenu(int client, Menu menu)
{
    delete g_aWeapons;
    g_aWeapons = new ArrayList(sizeof(Weapons));
    
    for (int i = 0; i <= CSGOItems_GetWeaponCount(); i++)
    {
        int defIndex = CSGOItems_GetWeaponDefIndexByWeaponNum(i);
        
        char sDefIndex[12], sDisplay[WP_DISPLAY];
        IntToString(defIndex, sDefIndex, sizeof(sDefIndex));
        CSGOItems_GetWeaponDisplayNameByDefIndex(defIndex, sDisplay, sizeof(sDisplay));
        
        if (IsValidDef(client, defIndex, false) && strlen(sDisplay) > 2)
        {
            Weapons wWeapon;
            wWeapon.IntDef = defIndex;
            strcopy(wWeapon.StringDef, 12, sDefIndex);
            strcopy(wWeapon.Name, WP_DISPLAY, sDisplay);
                
            g_aWeapons.PushArray(wWeapon);
        }
    }
    
    SortADTArrayCustom(g_aWeapons, Sort_Weapons);
    
    for (int i = 0; i < g_aWeapons.Length; i++)
    {
        Weapons wWeapon;
        g_aWeapons.GetArray(i, wWeapon, sizeof(wWeapon));
        
        char sEntry[WP_DISPLAY + 8];
        Format(sEntry, sizeof(sEntry), "[%d] %s", wWeapon.IntDef, wWeapon.Name);
        
        if (g_bDebug)
        {
            PrintToChat(client, "iWeapons2: %d [%s]", wWeapon.IntDef, wWeapon.StringDef);
        }
        
        if (!g_bDebug)
        {
            menu.AddItem(wWeapon.StringDef, wWeapon.Name);
        }
        else
        {
            menu.AddItem(wWeapon.StringDef, sEntry);
        }
    }
}
