#if defined _groupstatus_included
 #endinput
#endif
#define _groupstatus_included

native bool GroupStatus_IsClientInGroup(int client);

public SharedPlugin __pl_groupstatus = 
{
	name = "groupstatus",
	file = "groupstatus.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_groupstatus_SetNTVOptional()
{
	MarkNativeAsOptional("GroupStatus_IsClientInGroup");
}
#endif
