module helper.x11;

import cboxapp;
import window;

import std.conv;
import std.string;
import x11.X;
import x11.Xlib;
import x11.keysymdef;
import x11.Xutil;
import x11.Xatom;

class X11Helper
{
	static bool gettextprop(Window w, Atom atom, out string text) 
	{
	    static immutable size_t MAX_TEXT_LENGTH = 256;
	    XTextProperty name;
	    XGetTextProperty(AppDisplay.instance().dpy, w, &name, atom);

	    if(!name.nitems)
	        return false;

	    if(name.encoding == XA_STRING) {
	        text = (cast(char*)(name.value)).fromStringz.to!string;
	    } else {
	        char **list = null;
	        int n;
	        if(XmbTextPropertyToTextList(AppDisplay.instance().dpy, &name, &list, &n) >= XErrorCode.Success &&
	                n > 0 &&
	                *list) {
	            text = (*list).fromStringz.to!string;
	            XFreeStringList(list);
	        }
	    }

	    XFree(name.value);
	    return true;
	}
}

