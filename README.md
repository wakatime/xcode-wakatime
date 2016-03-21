xcode-wakatime
==============

Xcode plugin to quantify your coding using https://wakatime.com/.


Installation
------------

1. Install [Alcatraz](https://github.com/supermarin/Alcatraz#installation), the Xcode plugin manager.

2. Using [Alcatraz](https://github.com/supermarin/Alcatraz):

  a) Click `Window` -> `Package Manager` inside Xcode.

  b) Type `WakaTime`, then click the plugin icon on the left to install.
  
  ![Alcatraz Window](https://wakatime.com/static/img/ScreenShots/alcatraz_window.png)

  c) Restart Xcode.
  
3. Enter your [api key](https://wakatime.com/settings#apikey), then click `OK`.

4. Use Xcode like you normally do and your time will be tracked for you automatically.

5. Visit https://wakatime.com to see your logged time.


Screen Shots
------------

![Project Overview](https://wakatime.com/static/img/ScreenShots/Screen-Shot-2016-03-21.png)


Troubleshooting
---------------

First, try running this Terminal command:

```
rm -rf "~/Library/Application Support/Developer/Shared/Xcode/Plug-ins/WakaTime.xcplugin/Contents/Resources/wakatime-master”
```

Then re-install the WakaTime plugin using Alcatraz.

If that doesn't work, turn on debug mode and check your Xcode log file (`/var/log/system.log`) and your wakatime cli log file (`~/.wakatime.log`).

For more general troubleshooting information, see [wakatime/wakatime#troubleshooting](https://github.com/wakatime/wakatime#troubleshooting).
