xcode-wakatime
==============

Xcode plugin to quantify your coding using https://wakatime.com/.

Note: Xcode8 disables all plugins including WakaTime. Use [this app](https://s3-us-west-1.amazonaws.com/wakatime/MakeXcodeGr8Again.app.zip) to re-enable plugins in Xcode8.
Extract the zip, run `MakeXcodeGr8Again.app`, then drag and drop your `Xcode.app` into the program's window to patch your Xcode.
Alternatively, you can compile this program on your own from [this source code](https://github.com/fpg1503/MakeXcodeGr8Again).


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

Try running this Terminal command:

```
bash <(curl -s https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/WakaTime/install_dependencies.sh)
```

That will re-download the [wakatime-cli dependency](https://github.com/wakatime/wakatime).

If that doesn't work, turn on debug mode and check your wakatime cli log file (`~/.wakatime.log`).

If there are no errors in your `~/.wakatime.log` file, check your Xcode log file (`/var/log/system.log`).

For more general troubleshooting information, see [wakatime/wakatime#troubleshooting](https://github.com/wakatime/wakatime#troubleshooting).
