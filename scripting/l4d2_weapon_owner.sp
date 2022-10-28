#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1.0"
//materials/vgui/white_additive.vmt

//#define DEBUG

#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_VALID_HUMAN(%1)		(IS_VALID_CLIENT(%1) && IsClientConnected(%1) && !IsFakeClient(%1))
#define IS_SPECTATOR(%1)        (GetClientTeam(%1) == TEAM_SPECTATOR)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == TEAM_SURVIVOR)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == TEAM_INFECTED)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_VALID_SPECTATOR(%1)  (IS_VALID_INGAME(%1) && IS_SPECTATOR(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))
#define IS_HUMAN_SURVIVOR(%1)   (IS_VALID_HUMAN(%1) && IS_SURVIVOR(%1))
#define IS_HUMAN_INFECTED(%1)   (IS_VALID_HUMAN(%1) && IS_INFECTED(%1))

#define CONFIG_FILE "weapon_owner.cfg"

public Plugin myinfo = 
{
	name = "Weaponer owner", 
	author = "kahdeg", 
	description = "Locking dropped weapon.", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?t=335071"
};

ConVar g_bCvarAllow, g_bCvarWeaponOwnershipTimeout, g_iCvarWeaponOwnershipTimeout;
Handle g_hWeaponLockToggleCookie;

char g_ConfigPath[PLATFORM_MAX_PATH];
ArrayList g_WeaponOwnerRef; //each client can lock 1 primary and 1 offhand for themself

public void OnPluginStart()
{
	//Make sure we are on left 4 dead 2!
	if (GetEngineVersion() != Engine_Left4Dead2) {
		SetFailState("This plugin only supports left 4 dead 2!");
		return;
	}
	
	g_WeaponOwnerRef = new ArrayList(3);
	
	BuildPath(Path_SM, g_ConfigPath, sizeof(g_ConfigPath), "configs/%s", CONFIG_FILE);
	
	/**
	 * @note For the love of god, please stop using FCVAR_PLUGIN.
	 * Console.inc even explains this above the entry for the FCVAR_PLUGIN define.
	 * "No logic using this flag ever existed in a released game. It only ever appeared in the first hl2sdk."
	 */
	CreateConVar("sm_wpowner_version", PLUGIN_VERSION, "Plugin Version.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_bCvarAllow = CreateConVar("weapon_owner_on", "1", "Enable plugin. 1=Plugin On. 0=Plugin Off", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_bCvarWeaponOwnershipTimeout = CreateConVar("weapon_owner_lock_timeout", "0", "1=enable Weapon Ownership timeout. 0=disable Weapon Ownership timeout", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_iCvarWeaponOwnershipTimeout = CreateConVar("weapon_owner_lock_timeout_duration", "30", "Duration for weapon claim.", FCVAR_NOTIFY, true, 5.0, true, 9999.0);
	
	g_hWeaponLockToggleCookie = RegClientCookie("weaponowner_toggle_cookie", "Weapon owner Toggle", CookieAccess_Protected);
	
	RegConsoleCmd("sm_weapon_lock_toggle", Command_ToggleLock, "Toggle on using weapon owner or not.");	
	RegConsoleCmd("sm_wpl", Command_ToggleLock, "Toggle on using weapon owner or not.");
	RegConsoleCmd("sm_weapon_unlock", Command_Unlock, "Unlock currently claimed weapon.");
	RegConsoleCmd("sm_wpu", Command_Unlock, "Unlock currently claimed weapon.");
	
	AutoExecConfig(true, "l4d2_weaponowner");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_WeaponCanUse, OnWeaponCanUse);
			SDKHook(i, SDKHook_WeaponDrop, OnWeaponDrop);
		}
	}
	
	CreateTimer(2.0, Timer_CheckOwnerTimeout, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
}

Action Command_ToggleLock(int clientId, int args) {
	if (IsPluginDisabled()) {
		ReplyToCommand(clientId, "Cannot execute command. Weapon owner is currently disabled.");
		return Plugin_Handled;
	}
	
	if (!IS_VALID_HUMAN(clientId)) {
		ReplyToCommand(clientId, "Client '%d' is not valid.", clientId);
		return Plugin_Handled;
	}
	
	char sCookieValue[4];
	if (GetClientWeaponOwnerToggleState(clientId)) {
		//toggle off
		IntToString(0, sCookieValue, sizeof(sCookieValue));
		SetClientCookie(clientId, g_hWeaponLockToggleCookie, sCookieValue);
		Claim(clientId, -1);
		//PrintHintText(clientId, "Weapon lock off.");
		PrintToChat(clientId, "Weapon Lock Off");
	} else {
		//toggle on
		IntToString(1, sCookieValue, sizeof(sCookieValue));
		SetClientCookie(clientId, g_hWeaponLockToggleCookie, sCookieValue);
		//PrintHintText(clientId, "Weapon lock on.");
		PrintToChat(clientId, "Weapon Lock On");
	}
	
	return Plugin_Handled;
}

Action Command_Unlock(int clientId, int args) {
	if (IsPluginDisabled()) {
		ReplyToCommand(clientId, "Cannot execute command. Weapon owner is currently disabled.");
		return Plugin_Handled;
	}
	
	if (!IS_VALID_HUMAN(clientId)) {
		ReplyToCommand(clientId, "Client '%d' is not valid.", clientId);
		return Plugin_Handled;
	}
	
	Claim(clientId, -1);
	//PrintHintText(clientId, "Unlocked all.");
	PrintToChat(clientId, "Unlocked weapon.");
	
	return Plugin_Handled;
}

/**
* Callback for timer to expire weapon ownership.
*/
Action Timer_CheckOwnerTimeout(Handle timer) {
	if (IsPluginDisabled()) {
		return Plugin_Continue;
	}
	if (IsWeaponOwnershipTimeoutDisabled()) {
		return Plugin_Continue;
	}
	int n = g_WeaponOwnerRef.Length;
	int currentTimestamp = GetTime();
	for (int i = 0; i < n; i++) {
		int clientId = g_WeaponOwnerRef.Get(i, 0);
		int weaponEntId = g_WeaponOwnerRef.Get(i, 1);
		int weaponTimestamp = g_WeaponOwnerRef.Get(i, 2);
		
		if (weaponEntId != -1 && (currentTimestamp - weaponTimestamp > GetWeaponOwnershipTimeout())) {
			PrintToChat(clientId, "Weapon unlocked");
			g_WeaponOwnerRef.Set(i, -1, 1);
		}
	}
	return Plugin_Continue;
}

/**
* Callback for WeaponCanUse hook.
*/
Action OnWeaponCanUse(int clientId, int weaponEntId)
{
	if (IsPluginDisabled()) {
		return Plugin_Continue;
	}
	
	if (IS_VALID_CLIENT(clientId)) {
		
		//survivor pickup weapon
		if (IS_VALID_HUMAN(clientId) && IS_VALID_SURVIVOR(clientId)) {
			
			char weaponName[64];
			GetEntityClassname(weaponEntId, weaponName, sizeof(weaponName));
			if (!IsWeapon(weaponName)) {
				return Plugin_Continue;
			}
			
			bool isClaim = IsClaimed(weaponEntId);
			bool isOwner = IsOwner(clientId, weaponEntId);
			int ownerClientId = GetOwner(weaponEntId);
			char ownerClientName[255];
			if (ownerClientId != -1) {
				GetClientName(ownerClientId, ownerClientName, sizeof(ownerClientName));
			}
			
			DebugPrint("picked up: %s | %d | %s | %s | %s", weaponName, weaponEntId, isClaim ? "c":"nc", isOwner ? "o" : "no", ownerClientId == -1 ? "None" : ownerClientName);
			
			if (isClaim && !isOwner)
			{
				//PrintHintText(clientId, "This weapon is claimed by %s!", ownerClientName);
				PrintToChat(clientId, "This weapon is claimed by %s!", ownerClientName);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

Action OnWeaponDrop(int clientId, int weaponEntId){
	if (IsPluginDisabled()) {
		return Plugin_Continue;
	}
	
	if (IS_VALID_CLIENT(clientId)) {
		
		//survivor pickup weapon
		if (IS_VALID_HUMAN(clientId) && IS_VALID_SURVIVOR(clientId)) {
			
			//check for weapon owner toggle
			if (!GetClientWeaponOwnerToggleState(clientId)) {
				return Plugin_Continue;
			}
			
			char weaponName[64];
			GetEntityClassname(weaponEntId, weaponName, sizeof(weaponName));
			if (!IsWeapon(weaponName)) {
				return Plugin_Continue;
			}
			
			Claim(clientId, weaponEntId);
			char ownerClientName[255];
			GetClientName(clientId, ownerClientName, sizeof(ownerClientName));
			DebugPrint("dropped(sdk): %s | %d | c | o | %s", weaponName, weaponEntId, ownerClientName);
		}
	}
	return Plugin_Continue;
}

/**
* Check if a client own a weapon
*/
bool IsOwner(int clientId, int weaponEntId) {
	if (clientId < MaxClients) {
		int claimId = g_WeaponOwnerRef.FindValue(clientId, 0);
		if (claimId == -1) {
			return false;
		}
		return g_WeaponOwnerRef.Get(claimId, 1) == weaponEntId;
	}
	return false;
}

/**
* Check if a weapon is claimed
*/
bool IsClaimed(int weaponEntId) {
	int claimId = g_WeaponOwnerRef.FindValue(weaponEntId, 1);
	return claimId != -1;
}

/**
* Get a weapon's owner's clientid
*/
int GetOwner(int weaponEntId) {
	int claimId = g_WeaponOwnerRef.FindValue(weaponEntId, 1);
	if (claimId != -1) {
		return g_WeaponOwnerRef.Get(claimId, 0);
	}
	return -1;
}

/**
* Claim a weapon for a client
*/
int Claim(int clientId, int weaponEntId) {
	int claim[5];
	if (clientId < MaxClients) {
		
		int claimId = g_WeaponOwnerRef.FindValue(clientId, 0);
		int currentTime = GetTime();
		if (claimId == -1) {
			claim[0] = clientId;
			claim[1] = weaponEntId;
			claim[2] = currentTime;
			claimId = g_WeaponOwnerRef.PushArray(claim, 5);
			DebugPrint("new claim");
		} else {
			int oldwp = g_WeaponOwnerRef.Get(claimId, 1);
			g_WeaponOwnerRef.Set(claimId, weaponEntId, 1);
			g_WeaponOwnerRef.Set(claimId, currentTime, 2);
			DebugPrint("overwrite claim %d -> %d", oldwp, weaponEntId);
		}
		return claimId;
	}
	return -1;
}
/**
* Check if an item is a weapon
*/
bool IsWeapon(const char[] weaponName) {	
	//melee
	if (StrEqual(weaponName, "weapon_chainsaw") || StrEqual(weaponName, "weapon_melee")) {
		return true;
	}
	return false;
}

void DebugPrint(const char[] format, any...) {
	#if defined DEBUG
	char buffer[254];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintToChat(i, "%s", buffer);
		}
	}
	#endif
}

bool GetClientWeaponOwnerToggleState(int clientId) {
	char sCookieValue[4];
	GetClientCookie(clientId, g_hWeaponLockToggleCookie, sCookieValue, sizeof(sCookieValue));
	int cookieValue = StringToInt(sCookieValue);
	return cookieValue == 1;
}

bool IsPluginDisabled() {
	return !g_bCvarAllow.BoolValue;
}

int GetWeaponOwnershipTimeout() {
	return g_iCvarWeaponOwnershipTimeout.IntValue;
}

bool IsWeaponOwnershipTimeoutDisabled() {
	return !g_bCvarWeaponOwnershipTimeout.BoolValue;
}
