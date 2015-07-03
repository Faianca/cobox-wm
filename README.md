# cbox-wm 
## check develop for the new updates
CteamBox Window Manager in D programming Language.

This is just the main release, soon will be a bigger release and hopefully 100% stable.

Thanks to DWM, DDWM project which alot of code has been forked and of course to fluxbox.

## Requirements
Dlang
DUB

## Installation
#### Download libX11 from Deimos
1. git clone https://github.com/D-Programming-Deimos/libX11
2. dub add-local libX11 0.0.1
3. 

#### Download Cobox
1. git clone https://github.com/jmeireles/cobox-wm
2. cd cobox-wm
3. dub build


### Testing with Xephyr
Xephyr -ac -br -noreset -screen 800x600 :1

DISPLAY=:1 ./cobox-wm


## Screen Shots
![ScreenShot](/screenshots/cobox.png)

![ScreenShot](/screenshots/cobox2.png)
