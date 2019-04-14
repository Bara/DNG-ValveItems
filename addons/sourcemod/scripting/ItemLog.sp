#pragma semicolon 1

#define PLUGIN_AUTHOR "SM9"
#define PLUGIN_VERSION "0.1"

#include <csgoitems>

bool g_bLateLoaded;

public Plugin myinfo = 
{
	name = "CSGOItems Item Log", 
	author = PLUGIN_AUTHOR, 
	description = "Logs gloves and weapon skins", 
	version = PLUGIN_VERSION, 
	url = "www.fragdeluxe.com"
};

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] chError, int iErrMax) {
	g_bLateLoaded = bLate;
}

public void OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSGO) {
		SetFailState("This plugin is for CSGO only.");
	}
	
	if (g_bLateLoaded) {
		if (CSGOItems_AreItemsSynced()) {
			CSGOItems_OnItemsSynced();
		} else if (!CSGOItems_AreItemsSyncing()) {
			CSGOItems_ReSync();
		}
	}
	
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "logs/ItemLog");
	
	if (!DirExists(szPath)) {
		CreateDirectory(szPath, 511);
	}
	
	BuildPath(Path_SM, szPath, sizeof(szPath), "logs/ItemLog/Weapons");
	
	if (!DirExists(szPath)) {
		CreateDirectory(szPath, 511);
	}
	
	BuildPath(Path_SM, szPath, sizeof(szPath), "logs/ItemLog/Gloves");
	
	if (!DirExists(szPath)) {
		CreateDirectory(szPath, 511);
	}
}

public void CSGOItems_OnItemsSynced()
{
	char szBuffer[128]; char szPath[PLATFORM_MAX_PATH];
	char szSplitBuffer[128][128];
	int iSkinNum;
	File fFile;
	
	ArrayList alPaints = new ArrayList(128);
	
	// First we are going to push paints into an ArrayList so we can sort them alphabetically.
	for (int i = 0; i < CSGOItems_GetSkinCount(); i++) {
		if (CSGOItems_GetSkinDefIndexBySkinNum(i) <= -1) {
			continue;
		}
		
		if (!CSGOItems_GetSkinDisplayNameBySkinNum(i, szBuffer, sizeof(szBuffer))) {
			continue;
		}
		
		FormatEx(szBuffer, 128, "%s;%d", szBuffer, i);
		alPaints.PushString(szBuffer);
	}
	
	SortADTArray(alPaints, Sort_Ascending, Sort_String);
	
	// Lets create a paint list for each weapon.
	for (int i = 0; i < CSGOItems_GetWeaponCount(); i++) {
		if (CSGOItems_GetWeaponDefIndexByWeaponNum(i) <= -1) {
			continue;
		}
		
		CSGOItems_GetWeaponDisplayNameByWeaponNum(i, szBuffer, sizeof(szBuffer));
		BuildPath(Path_SM, szPath, sizeof(szPath), "logs/ItemLog/Weapons/%s.txt", szBuffer);
		
		for (int x = 0; x < alPaints.Length; x++) {
			alPaints.GetString(x, szBuffer, sizeof(szBuffer)); ExplodeString(szBuffer, ";", szSplitBuffer, 128, 128);
			iSkinNum = StringToInt(szSplitBuffer[1]);
			
			if (CSGOItems_IsNativeSkin(iSkinNum, i, ITEMTYPE_WEAPON)) {
				if (fFile == null) {
					fFile = OpenFile(szPath, "w+");
				}
				
				FormatEx(szBuffer, sizeof(szBuffer), "%s -- %d", szSplitBuffer[0], CSGOItems_GetSkinDefIndexBySkinNum(iSkinNum));
				fFile.WriteLine(szBuffer);
			}
		}
		
		if (fFile != null) {
			fFile.Close();
			fFile = null;
		}
	}
	
	// Lets create a paint list for each gloves.
	for (int i = 0; i < CSGOItems_GetGlovesCount(); i++) {
		if (CSGOItems_GetGlovesDefIndexByGlovesNum(i) <= -1) {
			continue;
		}
		
		CSGOItems_GetGlovesDisplayNameByGlovesNum(i, szBuffer, sizeof(szBuffer));
		BuildPath(Path_SM, szPath, sizeof(szPath), "logs/ItemLog/Gloves/%s.txt", szBuffer);
		
		for (int x = 0; x < alPaints.Length; x++) {
			alPaints.GetString(x, szBuffer, sizeof(szBuffer)); ExplodeString(szBuffer, ";", szSplitBuffer, 128, 128);
			iSkinNum = StringToInt(szSplitBuffer[1]);
			
			if (CSGOItems_IsNativeSkin(iSkinNum, i, ITEMTYPE_GLOVES)) {
				if (fFile == null) {
					fFile = OpenFile(szPath, "w+");
				}
				
				FormatEx(szBuffer, sizeof(szBuffer), "%s -- %d", szSplitBuffer[0], CSGOItems_GetSkinDefIndexBySkinNum(iSkinNum));
				fFile.WriteLine(szBuffer);
			}
		}
		
		if (fFile != null) {
			fFile.Close();
			fFile = null;
		}
	}
} 