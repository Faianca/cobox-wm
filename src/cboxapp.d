module cboxapp;

import std.stdio;
import deimos.X11.Xlib;

/**
* Singleton to hold our main Display
**/
class AppDisplay 
{   

  Display *dpy;

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