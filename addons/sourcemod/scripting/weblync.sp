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
#include <dynamic/methodmaps/weblync/paramcallback>

static WebLyncSettings Settings = view_as<WebLyncSettings>(INVALID_DYNAMIC_OBJECT);
static Dynamic ServerLinks = INVALID_DYNAMIC_OBJECT;
static Dynamic ParamCallbacks = INVALID_DYNAMIC_OBJECT;

public Plugin myinfo =
{
	name = "WebLync",
	author = "Neuro Toxin",
	description = "Browser redirection for CS:GO",
	version = "0.0.8",
	url = "https://weblync.tokenstash.com"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNatives();
	RegPluginLibrary("weblync");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("webblync.phrases");
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
		
	if (ParamCallbacks.IsValid)
		ParamCallbacks.Dispose();
}

public void OnMapStart()
{
	LoadSettings();
	GetServerLinks();
}

stock void CreateNatives()
{
	CreateNative("WebLync_OpenUrl", Native_WebLync_OpenUrl);
	CreateNative("WebLync_RegisterUrlParam", Native_WebLync_RegisterUrlParam);
	CreateNative("WebLync_UnregisterUrlParam", Native_WebLync_UnregisterUrlParam);
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
		ReplyToCommand(client, "[WebLync] %T", "WebLync.SteamWorks.RequestError", LANG_SERVER);
	
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
	
	ReplyToCommand(client, "[WebLync] %T", "WebLync.Server.Registering", LANG_SERVER);
	PrintToServer("[WebLync] %T", "WebLync.Server.Registering", LANG_SERVER);
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
		LogError("%T", "WebLync.Server.RegisterationFailed", LANG_SERVER);
	
	delete request;
}

public int RegisterServerResponse(char[] response)
{
	if (StrContains(response, "ERROR ") == 0)
	{
		PrintToChatAll("[WebLync] %T", "WebLync.Server.RegisterationError", LANG_SERVER, response[6]);
	}
	else if (StrContains(response, "OK ") == 0)
	{
		Settings.SetServerKey(response[3]);
		SaveSettings();
		PrintToChatAll("[WebLync] %T", "WebLync.Server.RegisterationSuccess", LANG_SERVER);
		PrintToServer("[WebLync] %T", "WebLync.Server.RegisterationSuccess", LANG_SERVER);
		GetServerLinks();
	}
	else
	{
		LogError("%T", "WebLync.API.InvalidResponse", LANG_SERVER, response);
	}
}

stock void GetServerLinks()
{
	char[] url = "http://weblync.tokenstash.com/api/getserverlinks/v0001.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	
	if (request == null)
		PrintToServer("[WebLync] %T", "WebLync.SteamWorks.RequestError", LANG_SERVER);
	
	char ServerKey[65];
	Settings.GetServerKey(ServerKey, sizeof(ServerKey));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "ServerKey", ServerKey);
	SteamWorks_SetHTTPCallbacks(request, OnGetServerLinksCallback);
	SteamWorks_SendHTTPRequest(request);
	
	PrintToServer("[WebLync] %T", "WebLync.Links.Getting", LANG_SERVER);
}

public int OnGetServerLinksCallback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode)
{
	if (!failure && requestSuccessful && statusCode == k_EHTTPStatusCode200OK)
		SteamWorks_GetHTTPResponseBodyCallback(request, ServerLinksResponse);
	else
		PrintToServer("[WebLync] %T", "WebLync.Links.Failed", LANG_SERVER);
	
	delete request;
}

public int ServerLinksResponse(char[] response)
{
	if (StrContains(response, "ERROR ") == 0)
	{
		LogError("%T", "WebLync.Links.Error", LANG_SERVER, response[6]);
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
		PrintToServer("[WebLync] %T", "WebLync.Links.Success", LANG_SERVER, count);
	}
	else
	{
		LogError("%T", "WebLync.API.InvalidResponse", LANG_SERVER, response);
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
	char[] url = "http://weblync.tokenstash.com/api/requestlink/v0003.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	
	if (request == null)
	{
		PrintToChat(client, "[WebLync] %T", "WebLync.Link.RequestError", LANG_SERVER);
		PrintToConsole(client, "[WebLync] %T", "WebLync.Link.RequestError", LANG_SERVER);
		return;
	}
	
	char ServerKey[65]; char UserId[16]; char SteamId[32];
	Settings.GetServerKey(ServerKey, sizeof(ServerKey));
	IntToString(GetClientUserId(client), UserId, sizeof(UserId));
	GetClientAuthId(client, AuthId_SteamID64, SteamId, sizeof(SteamId));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "ServerKey", ServerKey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "UserId", UserId);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "SteamId", SteamId);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "LinkName", linkname[3]);
	
	AddUrlReplacementsToRequest(client, request);
	AddThirdPartyPostReplacements(client, request);
	
	SteamWorks_SetHTTPCallbacks(request, OnRequestWebLyncCallback);
	SteamWorks_SendHTTPRequest(request);
	if (Settings.ShowMessages)
	{
		PrintToChat(client, "[WebLync] %T", "WebLync.Link.Requesting", LANG_SERVER, linkname[3]);
		PrintToConsole(client, "[WebLync] %T", "WebLync.Link.Requesting", LANG_SERVER, linkname[3]);
	}
}

stock void DisplayWebLyncUrl(int client, const char[] url)
{
	char[] apiurl = "http://weblync.tokenstash.com/api/requestcustomlink/v0002.php";
	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, apiurl);
	
	if (request == null)
	{
		PrintToChat(client, "[WebLync] %T", "WebLync.Link.RequestError", LANG_SERVER);
		PrintToConsole(client, "[WebLync] %T", "WebLync.Link.RequestError", LANG_SERVER);
		return;
	}
	
	char ServerKey[65]; char UserId[16]; char SteamId[32];
	Settings.GetServerKey(ServerKey, sizeof(ServerKey));
	IntToString(GetClientUserId(client), UserId, sizeof(UserId));
	GetClientAuthId(client, AuthId_SteamID64, SteamId, sizeof(SteamId));
	
	static char buffer[4096];
	strcopy(buffer, sizeof(buffer), url);
	AddThirdPartyUrlReplacements(client, buffer, sizeof(buffer));
	
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "ServerKey", ServerKey);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "UserId", UserId);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "SteamId", SteamId);
	SteamWorks_SetHTTPRequestGetOrPostParameter(request, "Url", buffer);
	
	SteamWorks_SetHTTPCallbacks(request, OnRequestWebLyncCallback);
	SteamWorks_SendHTTPRequest(request);
	if (Settings.ShowMessages)
	{
		PrintToChat(client, "[WebLync] %T", "WebLync.Link.RequestingCustom", LANG_SERVER);
		PrintToConsole(client, "[WebLync] %T", "WebLync.Link.RequestingCustom", LANG_SERVER);
	}
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

stock void AddThirdPartyPostReplacements(int client, Handle request)
{
	if (!ParamCallbacks.IsValid)
		return;
	
	int count = ParamCallbacks.MemberCount;
	DynamicOffset memberoffset;
	char paramname[DYNAMIC_MEMBERNAME_MAXLEN];
	char buffer[512];
	bool result;
	
	for (int i = 0; i < count; i++)
	{
		memberoffset = ParamCallbacks.GetMemberOffsetByIndex(i);
		ParamCallbacks.GetMemberNameByIndex(i, paramname, sizeof(paramname));
		
		WebLyncParamCallback callback = view_as<WebLyncParamCallback>(ParamCallbacks.GetDynamicByOffset(memberoffset));
		if (!callback.IsValid)
			continue;
			
		// typedef WebLyncGetUrlParam = function bool (int client, const char[] paramname, char[] buffer, int maxlength);
		Call_StartFunction(callback.OwnerPlugin, view_as<Function>(callback.Callback));
		Call_PushCell(client);
		Call_PushString(paramname);
		Call_PushStringEx(buffer, sizeof(buffer), SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
		Call_PushCell(sizeof(buffer));
		Call_Finish(result);
		
		if (!result)
			continue;
		
		Format(paramname, sizeof paramname, "customparam_%s", paramname);
		SteamWorks_SetHTTPRequestGetOrPostParameter(request, paramname, buffer);	
	}
}

stock void AddThirdPartyUrlReplacements(int client, char[] url, int maxlength)
{
	if (!ParamCallbacks.IsValid)
		return;
		
	int count = ParamCallbacks.MemberCount;
	DynamicOffset memberoffset;
	char paramname[DYNAMIC_MEMBERNAME_MAXLEN];
	char buffer[512];
	bool result;
	
	for (int i = 0; i < count; i++)
	{
		memberoffset = ParamCallbacks.GetMemberOffsetByIndex(i);
		ParamCallbacks.GetMemberNameByIndex(i, paramname, sizeof(paramname));
		
		if (StrContains(url, paramname) == -1)
			continue;
			
		WebLyncParamCallback callback = view_as<WebLyncParamCallback>(ParamCallbacks.GetDynamicByOffset(memberoffset));
		if (!callback.IsValid)
			continue;
			
		// typedef WebLyncGetUrlParam = function bool (int client, const char[] paramname, char[] buffer, int maxlength);
		Call_StartFunction(callback.OwnerPlugin, view_as<Function>(callback.Callback));
		Call_PushCell(client);
		Call_PushString(paramname);
		Call_PushStringEx(buffer, sizeof(buffer), SM_PARAM_STRING_UTF8, SM_PARAM_COPYBACK);
		Call_PushCell(sizeof(buffer));
		Call_Finish(result);
		
		if (!result)
			continue;
			
		ReplaceString(url, maxlength, paramname, buffer);
	}
}

public int OnRequestWebLyncCallback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode)
{
	if (!failure && requestSuccessful && statusCode == k_EHTTPStatusCode200OK)
		SteamWorks_GetHTTPResponseBodyCallback(request, ProcessWebLyncRequest);
	else
		PrintToServer("[WebLync] %T", "WebLync.Link.RequestError", LANG_SERVER);
	
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
		
		char ServerKey[65]; char UserId[16]; char SteamId[32]; char Url[512];
		Settings.GetServerKey(ServerKey, sizeof(ServerKey));
		IntToString(GetClientUserId(client), UserId, sizeof(UserId));
		GetClientAuthId(client, AuthId_SteamID64, SteamId, sizeof(SteamId));
		
		Format(Url, sizeof(Url), "http://weblync.tokenstash.com/api/redirect/v0002.php?UserId=%s&ServerKey=%s&SteamId=%s", UserId, ServerKey, SteamId);
		ShowMOTDPanel(client, "WebLync", Url, MOTDPANEL_TYPE_URL);
		if (Settings.ShowMessages)
		{
			PrintToChat(client, "[WebLync] %T", "WebLync.Link.Opening", LANG_SERVER);
			PrintToConsole(client, "[WebLync] %T", "WebLync.Link.Opening", LANG_SERVER);
		}
	}
	else if (StrContains(response, "ERROR ") == 0)
	{
		char errordetails[3][256];
		ExplodeString(response, " ", errordetails, sizeof(errordetails), sizeof(errordetails[]), true);
		int client = GetClientOfUserId(StringToInt(errordetails[1]));
		if (client > 0)
		{
			PrintToChat(client, "[WebLync] %T", "WebLync.API.InvalidResponse", LANG_SERVER, errordetails[2]);
			PrintToConsole(client, "[WebLync] %T", "WebLync.API.InvalidResponse", LANG_SERVER, errordetails[2]);
		}
		LogError("%T", "WebLync.API.InvalidResponse", LANG_SERVER, errordetails[2]);
	}
	else
	{
		LogError("%T", "WebLync.API.InvalidResponse", LANG_SERVER, response);
	}
	return 1;
}

// native void WebLync_OpenUrl(int client, const char[] url);
public int Native_WebLync_OpenUrl(Handle plugin, int params)
{
	int client = GetNativeCell(1);
	
	int urllength;
	GetNativeStringLength(2, urllength);
	char[] url = new char[++urllength];
	GetNativeString(2, url, urllength);
	
	DisplayWebLyncUrl(client, url);
	return 1;
}

// native void WebLync_RegisterUrlParam(const char[] paramname, WebLyncGetUrlParam callback);
public int Native_WebLync_RegisterUrlParam(Handle plugin, int params)
{
	if (!ParamCallbacks.IsValid)
		ParamCallbacks = Dynamic();
		
	int paramnamelength;
	GetNativeStringLength(1, paramnamelength);
	char[] paramname = new char[++paramnamelength];
	GetNativeString(1, paramname, paramnamelength);
	
	WebLyncParamCallback callback = WebLyncParamCallback();
	callback.OwnerPlugin = plugin;
	callback.Callback = GetNativeCell(2);
	
	ParamCallbacks.SetDynamic(paramname, callback);
	return 1;
}

// native void WebLync_UnregisterUrlParam(const char[] paramname);
public int Native_WebLync_UnregisterUrlParam(Handle plugin, int params)
{
	int paramnamelength;
	GetNativeStringLength(1, paramnamelength);
	char[] paramname = new char[++paramnamelength];
	GetNativeString(1, paramname, paramnamelength);
	
	Dynamic callback = ParamCallbacks.GetDynamic(paramname);
	if (callback.IsValid)
	{
		callback.Dispose();
		ParamCallbacks.SetDynamic(paramname, INVALID_DYNAMIC_OBJECT);
	}
	return 1;
}