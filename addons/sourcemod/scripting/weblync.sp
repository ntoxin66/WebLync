/**
 * =============================================================================
 * WebLync for SourceMod (C)2017 Matthew J Dunn.   All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */
#include <weblync>
#include <dynamic>
#include <steamworks>
#pragma newdecls required
#pragma semicolon 1

#include <dynamic/methodmaps/weblync/settings>

static WebLyncSettings Settings;
static Dynamic ServerLinks;

public Plugin myinfo =
{
	name = "WebLync",
	author = "Neuro Toxin",
	description = "Browser redirection for CS:GO",
	version = "0.0.2",
	url = "https://weblync.tokenstash.com"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();
	RegPluginLibrary("weblync");
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	Settings = WebLyncSettings();
	ServerLinks = Dynamic();
	LoadSettings();
	RegisterCommands();
}

public void OnPluginEnd()
{
	if (Settings.IsValid)
		Settings.Dispose();
		
	if (ServerLinks.IsValid)
		ServerLinks.Dispose();
}

public void OnMapStart()
{
	GetServerLinks();
}

stock void CreateNatives()
{
	CreateNative("WebLync_OpenUrl", Native_WebLync_OpenUrl);
}

stock void LoadSettings()
{
	if (Settings.IsValid)
		Settings.Dispose();
	
	Settings = WebLyncSettings();
	Settings.ReadConfig("cfg\\sourcemod\\weblync.cfg");
}

stock void SaveSettings()
{
	Settings.WriteConfig("cfg\\sourcemod\\weblync.cfg");
}

stock void RegisterCommands()
{
	RegAdminCmd("sm_weblync", OnWebLyncCommand, ADMFLAG_CONFIG, "WebLync administration menu");
	RegAdminCmd("sm_weblyncregserver", OnWebLyncRegServerCommand, ADMFLAG_CONFIG, "Register server with WebLync API");
	RegAdminCmd("sm_weblyncsyncserver", OnWebLyncSyncServerCommand, ADMFLAG_CONFIG, "Syncs new commands to server");
}

public Action OnWebLyncCommand(int client, int args)
{
	DisplayWebLync(client, "sm_weblync");
	return Plugin_Handled;
}

public Action OnWebLyncRegServerCommand(int client, int args)
{
	char[] url = "http://weblync.tokenstash.com/api/registerserver/v0001.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	
	if (request == null)
		ReplyToCommand(client, "WebLync: Unable to create SteamWorks HTTP request.");
	
	char ServerKey[65]; char SteamId[25]; char ServerName[129]; char IpAddress[17]; char Port[13];
	GetCmdArg(1, ServerKey, sizeof(ServerKey));
	GetCmdArg(2, SteamId, sizeof(SteamId));
	GetServerHostname(ServerName, sizeof(ServerName));
	GetServerIpAddress(IpAddress, sizeof(IpAddress));
	GetServerPort(Port, sizeof(Port));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "ServerKey", ServerKey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "SteamId", SteamId);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "ServerName", ServerName);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "IpAddress", IpAddress);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "Port", Port);
	SteamWorks_SetHTTPCallbacks(request, OnRegisterServerCallback);
	SteamWorks_SendHTTPRequest(request);
	
	ReplyToCommand(client, "WebLync: Registering server...");
	PrintToServer("WebLync: Registering server...");
	return Plugin_Handled;
}

public Action OnWebLyncSyncServerCommand(int client, int args)
{
	GetServerLinks();
	return Plugin_Handled;
}

stock void GetServerHostname(char[] buffer, int length)
{
	ConVar cvar = FindConVar("hostname");
	cvar.GetString(buffer, length);
	delete cvar;
}

stock void GetServerIpAddress(char[] buffer, int length)
{
	ConVar cvar = FindConVar("ip");
	cvar.GetString(buffer, length);
	delete cvar;
}

stock void GetServerPort(char[] buffer, int length)
{
	ConVar cvar = FindConVar("hostport");
	cvar.GetString(buffer, length);
	delete cvar;
}

public int OnRegisterServerCallback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode)
{
	if (!failure && requestSuccessful && statusCode == k_EHTTPStatusCode200OK)
		SteamWorks_GetHTTPResponseBodyCallback(request, RegisterServerResponse);
	else
		LogError("Unable to register server");
	
	delete request;
}

public int RegisterServerResponse(char[] response)
{
	if (StrContains(response, "ERROR ") == 0)
	{
		PrintToChatAll("[WebLync] There was an error registering the server (%s).", response[6]);
	}
	else if (StrContains(response, "OK ") == 0)
	{
		Settings.SetServerKey(response[3]);
		SaveSettings();
		PrintToChatAll("[WebLync] Server registration successful.");
		PrintToServer("WebLync: Server registration successful.");
		GetServerLinks();
	}
	else
	{
		LogError("Invalid API response (%s).", response);
	}
}

stock void GetServerLinks()
{
	char[] url = "http://weblync.tokenstash.com/api/getserverlinks/v0001.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	
	if (request == null)
		PrintToServer("WebLync: Unable to create SteamWorks HTTP request.");
	
	char ServerKey[65];
	Settings.GetServerKey(ServerKey, sizeof(ServerKey));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "ServerKey", ServerKey);
	SteamWorks_SetHTTPCallbacks(request, OnGetServerLinksCallback);
	SteamWorks_SendHTTPRequest(request);
	
	PrintToServer("WebLync: Getting server links...");
}

public int OnGetServerLinksCallback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode)
{
	if (!failure && requestSuccessful && statusCode == k_EHTTPStatusCode200OK)
		SteamWorks_GetHTTPResponseBodyCallback(request, ServerLinksResponse);
	else
		PrintToServer("WebLync: Unable to get server links");
	
	delete request;
}

public int ServerLinksResponse(char[] response)
{
	if (StrContains(response, "ERROR ") == 0)
	{
		LogError("Error reported from API (%s).", response[6]);
	}
	else if (StrContains(response, "OK ") == 0)
	{
		char links[256][65];
		int count = ExplodeString(response[3], " ", links, sizeof(links), sizeof(links[]), false);
		
		for (int i=0; i<count;i++)
		{
			if (ServerLinks.GetBool(links[i]))
				continue;
				
			RegConsoleCmd(links[i], OnWebLyncLinkCommand);
			ServerLinks.SetBool(links[i], true);
		}
		PrintToServer("WebLync: %d link(s) received", count);
	}
	else
	{
		LogError("Invalid API response (%s).", response);
	}
}

public Action OnWebLyncLinkCommand(int client, int args)
{
	char LinkCommand[65];
	GetCmdArg(0, LinkCommand, sizeof(LinkCommand));
	DisplayWebLync(client, LinkCommand);
	return Plugin_Handled;
}

stock void DisplayWebLync(int client, const char[] linkname)
{
	char[] url = "http://weblync.tokenstash.com/api/requestlink/v0001.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	
	if (request == null)
	{
		PrintToChat(client, "WebLync: Error requesting link.");
		PrintToConsole(client, "WebLync: Error requesting link.");
		return;
	}
	
	char ServerKey[65]; char UserId[16];
	Settings.GetServerKey(ServerKey, sizeof(ServerKey));
	IntToString(GetClientUserId(client), UserId, sizeof(UserId));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "ServerKey", ServerKey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "UserId", UserId);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "LinkName", linkname[3]);
	
	AddUrlReplacementsToRequest(client, request);
	
	SteamWorks_SetHTTPCallbacks(request, OnRequestWebLyncCallback);
	SteamWorks_SendHTTPRequest(request);
	PrintToChat(client, "[WebLync] Requesting link `%s`...", linkname[3]);
	PrintToConsole(client, "[WebLync] Requesting link `%s`...", linkname[3]);
}

stock void DisplayWebLyncUrl(int client, const char[] url)
{
	char[] apiurl = "http://weblync.tokenstash.com/api/requestcustomlink/v0001.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, apiurl);
	
	if (request == null)
	{
		PrintToChat(client, "WebLync: Error requesting link.");
		PrintToConsole(client, "WebLync: Error requesting link.");
		return;
	}
	
	char ServerKey[65]; char UserId[16];
	Settings.GetServerKey(ServerKey, sizeof(ServerKey));
	IntToString(GetClientUserId(client), UserId, sizeof(UserId));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "ServerKey", ServerKey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "UserId", UserId);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "Url", url);
	
	SteamWorks_SetHTTPCallbacks(request, OnRequestWebLyncCallback);
	SteamWorks_SendHTTPRequest(request);
	PrintToChat(client, "[WebLync] Requesting custom link...");
	PrintToConsole(client, "[WebLync] Requesting custom link...");
}

stock void AddUrlReplacementsToRequest(int client, Handle request)
{
	char buffer[256];
	GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "SteamID", buffer);
	
	GetClientAuthId(client, AuthId_SteamID64, buffer, sizeof(buffer));
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "SteamID64", buffer);
	
	GetServerHostname(buffer, sizeof(buffer));
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "Hostname", buffer);
	
	GetServerIpAddress(buffer, sizeof(buffer));
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "IpAddress", buffer);
	
	GetServerPort(buffer, sizeof(buffer));
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "Port", buffer);
	
	IntToString(GetClientUserId(client), buffer, sizeof(buffer));
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "UserId", buffer);
	
	IntToString(client, buffer, sizeof(buffer));
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "Client", buffer);
	
	GetCmdArgString(buffer, sizeof(buffer));
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "Args", buffer);
}

public int OnRequestWebLyncCallback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode)
{
	if (!failure && requestSuccessful && statusCode == k_EHTTPStatusCode200OK)
		SteamWorks_GetHTTPResponseBodyCallback(request, ProcessWebLyncRequest);
	else
		PrintToServer("WebLync: Unable to request link");
	
	delete request;
}

public int ProcessWebLyncRequest(char[] response)
{
	if (StrContains(response, "OK ") == 0)
	{
		int userid = StringToInt(response[3]);
		int client = GetClientOfUserId(userid);
		
		if (client == 0)
			return 0;
		
		char ServerKey[65]; char UserId[16]; char Url[512];
		Settings.GetServerKey(ServerKey, sizeof(ServerKey));
		IntToString(GetClientUserId(client), UserId, sizeof(UserId));
		
		Format(Url, sizeof(Url), "http://weblync.tokenstash.com/api/redirect/v0001.php?UserId=%s&ServerKey=%s", UserId, ServerKey);
		ShowMOTDPanel(client, "WebLync", Url, MOTDPANEL_TYPE_URL);
		PrintToChat(client, "[WebLync] Opening Link...");
		PrintToConsole(client, "[WebLync] Opening Link...");
		PrintToConsole(client, Url);
	}
	else if (StrContains(response, "ERROR ") == 0)
	{
		char errordetails[3][256];
		ExplodeString(response, " ", errordetails, sizeof(errordetails), sizeof(errordetails[]), true);
		int client = GetClientOfUserId(StringToInt(errordetails[1]));
		if (client > 0)
		{
			PrintToChat(client, "[WebLync] Error opening link (%s)", errordetails[2]);
			PrintToConsole(client, "[WebLync] Error opening link (%s)", errordetails[2]);
		}
		LogError("Error reported from API (%s).", errordetails[2]);
	}
	else
	{
		LogError("Invalid API response (%s).", response);
	}
	return 1;
}

// native void WebLync_OpenUrl(int client, const char[] url);
public int Native_WebLync_OpenUrl(Handle plugin, int params)
{
	int client = GetNativeCell(1);
	
	int urllength;
	GetNativeStringLength(2, urllength);
	char[] url = new char[urllength];
	GetNativeString(2, url, urllength);
	
	DisplayWebLyncUrl(client, url);
	return 1;
}