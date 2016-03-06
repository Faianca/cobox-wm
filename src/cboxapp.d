module cboxapp;

import std.stdio;
import x11.X;
import x11.Xlib;
import x11.keysymdef;
import x11.Xutil;
import x11.Xatom;
import window;
import types;
import theme.layout;
import monitor;

alias DGC = core.memory.GC;
alias XGC = x11.Xlib.GC;

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

  void quit()
  {
     this.running = false;
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
