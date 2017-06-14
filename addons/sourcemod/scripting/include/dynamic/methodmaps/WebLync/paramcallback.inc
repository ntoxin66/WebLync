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
#if defined _dynamic_class_weblyncparamcallback_
  #endinput
#endif
#define _dynamic_class_weblyncparamcallback_

methodmap WebLyncParamCallback < Dynamic
{
	public WebLyncParamCallback()
	{
		// First we make a new dymanic object
		Dynamic myclass = Dynamic(2, 0);

		// Next we will define all the members
		// -> We do this to force the offsets to always be in the same location
		//    over multiple instances of the same class.
		myclass.SetHandle("OwnerPlugin", null);
		myclass.SetInt("Callback", -1);
		return view_as<WebLyncParamCallback>(myclass);
	}

	// Note that I use static offsets to access members.
	// -> This improves performance by caching member offsets
	// -> This is why we force the members in during the contructor
	// -> Failure to force members in the constructor will cause corruption

	property Handle OwnerPlugin
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("OwnerPlugin");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetHandleByOffset(offset);
		}
		public set(Handle value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("OwnerPlugin");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetHandle("OwnerPlugin", value);
					return;
				}
			}
			this.SetHandleByOffset(offset, value);
		}
	}

	property int Callback
	{
		public get()
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Callback");
				if (offset == INVALID_DYNAMIC_OFFSET)
					SetFailState("A serious error occured in Dynamic!");
			}
			return this.GetIntByOffset(offset);
		}
		public set(int value)
		{
			static DynamicOffset offset = INVALID_DYNAMIC_OFFSET;
			if (offset == INVALID_DYNAMIC_OFFSET)
			{
				offset = this.GetMemberOffset("Callback");
				if (offset == INVALID_DYNAMIC_OFFSET)
				{
					offset = this.SetInt("Callback", value);
					return;
				}
			}
			this.SetIntByOffset(offset, value);
		}
	}
}