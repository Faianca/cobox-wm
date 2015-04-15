module cboxapp;

import std.stdio;
import deimos.X11.X;
import deimos.X11.Xlib;
import deimos.X11.keysymdef;
import deimos.X11.Xutil;
import deimos.X11.Xatom;
import window;
import types;

alias DGC = core.memory.GC;
alias XGC = deimos.X11.Xlib.GC;

import core.sys.posix.signal;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;

/**
* Singleton to hold our main Display
**/
class AppDisplay 
{   

  Display *dpy;
  bool running = true;

  static AppDisplay instance() 
  {
    if (!instantiated_) {
      synchronized {
        if (instance_ is null) {
          instance_ = new AppDisplay;
          instance_.dpy = XOpenDisplay(null);
        }
        instantiated_ = true;
      }
    }
    return instance_;
  }

 private:
  this() {}
  static bool instantiated_;  // Thread local
  __gshared AppDisplay instance_;

 }

struct Client 
{
  string name;
  float mina, maxa;
  int x, y, w, h;
  int oldx, oldy, oldw, oldh;
  int basew, baseh, incw, inch, maxw, maxh, minw, minh;
  int bw, oldbw;
  uint tags;
  bool isfixed, isfloating, isurgent, neverfocus, oldstate, isfullscreen;
  Client *next;
  Client *snext;
  Monitor *mon;
  Window win;

    /**
     * A range to iterate over the client list via 'next' or 'snext',
     * as specified by the template string.
     * Example:
     * ---
     * auto r = ClientRange!"next"(clientPtr);
     * auto sr = ClientRange!"snext"(clientPtr);
     * ---
     */
    struct ClientRange(string NextField) 
    {
        Client* client;
        @property bool empty() 
        {
          return client is null;
        }

        @property auto front() 
        {
          return client;
        }

        auto popFront() 
        {
            mixin(`client = client.`~NextField~`;`);
        }
    }
}

struct Monitor 
{
  string ltsymbol;
  float mfact;
  int nmaster;
  int num;
  int by;               /* bar geometry */
  int mx, my, mw, mh;   /* screen size */
  int wx, wy, ww, wh;   /* window area  */
  uint seltags;
  uint sellt;
  uint[2] tagset;
  bool showbar;
  bool topbar;
  Client *clients;
  Client *sel;
  Client *stack;
  Monitor *next;
  Window barwin;
  const(Layout)*[2] lt;

    struct MonitorRange 
    {
        Monitor* monitor;

        @property empty() 
        {
            return monitor is null;
        }

        @property auto front() 
        {
            return monitor;
        }

        auto popFront() 
        {
            monitor = monitor.next;
        }

        int opApply(int delegate(Monitor*) dg)
        {
            int result = 0;
            while(!this.empty)
            {
                result = dg(this.front);
                if(result)
                {
                    break;
                }
                this.popFront;
            }
            return result;
        }

        int opApply(int delegate(size_t, Monitor*) dg) 
        {
            int result = 0;
            size_t ii = 0;
            while(!this.empty)
            {
                result = dg(ii++, this.front);
                if(result)
                {
                    break;
                }
                this.popFront;
            }
            return result;
        }
    }
}
