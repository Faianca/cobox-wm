module xinerama;

import deimos.X11.Xlib;

struct XineramaScreenInfo 
{
   int   screen_number;
   short x_org;
   short y_org;
   short width;
   short height;
} 

// _XFUNCPROTOBEGIN

extern(C) Bool XineramaQueryExtension (
   Display *dpy,
   int     *event_base,
   int     *error_base
) nothrow @nogc @system;

extern(C) Status XineramaQueryVersion(
   Display *dpy,
   int     *major_versionp,
   int     *minor_versionp
) nothrow @nogc @system;

extern(C) Bool XineramaIsActive(Display *dpy) nothrow @nogc @system;

/*
   Returns the number of heads and a pointer to an array of
   structures describing the position and size of the individual
   heads.  Returns NULL and number = 0 if Xinerama is not active.

   Returned array should be freed with XFree().
*/

extern(C) XineramaScreenInfo *
XineramaQueryScreens(
   Display *dpy,
   int     *number
) nothrow @nogc @system;