#if defined _sprays_included
 #endinput
#endif
#define _sprays_included

native int Sprays_GetClientSpray(int client);
native void Sprays_ResetClientTime(int client);
native int Sprays_SetClientSpray(int client, int sprayIndex);
native int Sprays_SetSprayContest(int client);

forward Action Sprays_OnClientSpray(int client, float[3] position);

public SharedPlugin __pl_discord =
{
	name = "sprays",
	file = "sprays.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public __pl_discord_SetNTVOptional()
{
	MarkNativeAsOptional("Sprays_GetClientSpray");
	MarkNativeAsOptional("Sprays_ResetClientTime");
	MarkNativeAsOptional("Sprays_SetClientSpray");
	MarkNativeAsOptional("Sprays_SetSprayContest");
}
#endif
