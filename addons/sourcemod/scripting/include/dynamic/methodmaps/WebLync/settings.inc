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
#if defined _dynamic_class_weblyncsettings_
  #endinput
#endif
#define _dynamic_class_weblyncsettings_

methodmap WebLyncSettings < Dynamic
{
	public WebLyncSettings()
	{
		// First we make a new dymanic object
		Dynamic myclass = Dynamic(68, 0);

		// Next we will define all the members
		// -> We do this to force the offsets to always be in the same location
		//    over multiple instances of the same class.
		myclass.SetString("ServerKey", "", 65);
		myclass.SetBool("ShowMessages", true);
		return view_as<WebLyncSettings>(myclass);
	}
	
	// Note that I use static offsets to access members.
	// -> This improves performance by caching member offsets
	// -> This is why we force the members in during the contructor
	// -> Failure to force members in the constructor will cause corruption
	
	public bool GetServerKey(char[] buffer, int length)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("ServerKey");
			if (offset == INVALID_DYNAMIC_OFFSET)
				SetFailState("A serious error occured in Dynamic!");
		}
		this.GetStringByOffset(offset, buffer, length);
		return true;
	}
	
	public void SetServerKey(const char[] buffer)
	{
		static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
		if (offset == INVALID_DYNAMIC_OFFSET)
		{
			offset = this.GetMemberOffset("ServerKey");
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.SetString("ServerKey", buffer);
				return;
			}
		}
		this.SetStringByOffset(offset, buffer);
	}
	
	property bool ShowMessages
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("ShowMessages");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetBoolByOffset(offset);
		}
		public set(bool value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("ShowMessages");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetBool("ShowMessages", value);
					return;
				}
			}
			this.SetBoolByOffset(offset, value);
		}
	}
	
	property bool ServerRegistered
	{
		public get()
		{
			char serverkey[2];
			this.GetServerKey(serverkey, sizeof(serverkey));
			if (StrEqual(serverkey, ""))
				return false;
			else
				return true;
		}
	}
}