static int g_iDefIndex[MAXPLAYERS + 1] =  { -1, ... };
static int g_iWeapon[MAXPLAYERS + 1] =  { -1, ... };
static int g_iSite[MAXPLAYERS + 1] =  { 0, ... };

void ChooseCurrentWeapon(int client)
{
    g_iDefIndex[client] = CSGOItems_GetActiveWeaponDefIndex(client);
    g_iWeapon[client] = CSGOItems_GetActiveWeapon(client);
    
    char sDisplay[WP_DISPLAY];
    CSGOItems_GetWeaponDisplayNameByDefIndex(g_iDefIndex[client], sDisplay, sizeof(sDisplay));
    
    if (g_bDebug)
    {
        PrintToChat(client, "(ChooseCurrentWeapon) Weapon: %s weaponIndex: %d/%d, defIndex: %d/%d", sDisplay, CSGOItems_GetActiveWeapon(client), g_iWeapon[client], CSGOItems_GetActiveWeaponDefIndex(client), g_iDefIndex[client]);
    }
    
    Menu menu = new Menu(Menu_ChooseCurrentWeapon);
    
    menu.SetTitle("%T", "Choose Weapon Skin Site", client, sDisplay, RoundToNearest(g_iSite[client] / 6.0 + 1.0), RoundToNearest(CSGOItems_GetSkinCount() / 6.0 + 1.0));
    
    AddWeaponSkinsToMenu(menu, client, g_iWeapon[client]);
    
    menu.ExitButton = true;
    menu.ExitBackButton = true;
    
    menu.DisplayAt(client, g_iSite[client], MENU_TIME_FOREVER);
}

public int Menu_ChooseCurrentWeapon(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        g_iSite[client] = menu.Selection;
        
        if (CanChange(client))
        {
            char sDefIndex[12];
            menu.GetItem(param, sDefIndex, sizeof(sDefIndex));
            if (g_bDebug)
            {
                PrintToChat(client, "(Menu_ChooseCurrentWeapon) sDef: %s", sDefIndex);
            }
            int defIndex = StringToInt(sDefIndex);
            
            // CLIENT, WEAPON, SKIN, DEF, MENU(?)
            SetClientSkin(client, g_iWeapon[client], defIndex, g_iDefIndex[client], 1);
            
            g_iDefIndex[client] = -1;
            g_iWeapon[client] = -1;
        }
        else
        {
            ChooseCurrentWeapon(client);
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
