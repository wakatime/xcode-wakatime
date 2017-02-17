xcode-wakatime
==============

Xcode plugin to quantify your coding using https://wakatime.com/.

Note: Xcode8 disables all plugins including WakaTime. Use [this app](https://s3-us-west-1.amazonaws.com/wakatime/MakeXcodeGr8Again.app.zip) to re-enable plugins in Xcode8.
Extract the zip, run `MakeXcodeGr8Again.app`, then drag and drop your `Xcode.app` into the program's window to patch your Xcode.
Alternatively, you can compile this program on your own from [this source code](https://github.com/fpg1503/MakeXcodeGr8Again).


Installation
------------

Xcode8 disables all plugins. To enable plugins again we have to sign Xcode with a self-signed cert. There are two ways to do this:

* Copy the Xcode.app and leave the original Xcode.app unmodified. If you need to publish apps and have enough disk space, this is the way to go.

* Modify the original Xcode.app to save storage space. If you need to publish apps you will have to re-install Xcode from the app store.

### Signing Xcode and Installing Alcatraz Plugin Manager

To modify your original Xcode.app:

1. Run this in your Terminal:

```
export APP=/Applications/Xcode.app; curl -fsSL https://raw.githubusercontent.com/alanhamlett/MakeXcodeGr8Again/master/selfsign.sh | bash
```

2. Skip to the [Installing the WakaTime plugin using Alcatraz](#installing-the-wakatime-plugin-using-alcatraz) section below.

To modify a copy of Xcode, follow these steps:

1. Download [MakeXcodeGr8Again](https://s3-us-west-1.amazonaws.com/wakatime/MakeXcodeGr8Again.app.zip).

2. Extract the zip, run `MakeXcodeGr8Again.app`, then drag and drop your `Xcode.app` into the program's window.
  
  ![usage animation](https://raw.githubusercontent.com/alanhamlett/MakeXcodeGr8Again/master/usage.gif)

3. Run this in your Terminal:

```
curl -fsSL https://raw.githubusercontent.com/alanhamlett/MakeXcodeGr8Again/master/selfsign.sh | bash
```

### Installing the WakaTime plugin using Alcatraz

1. Click `Window` -> `Package Manager` inside Xcode.

2. Type `WakaTime`, then click the plugin icon on the left to install.
  
  ![Alcatraz Window](https://wakatime.com/static/img/ScreenShots/alcatraz_window.png)

3. Restart Xcode.
  
4. Enter your [api key](https://wakatime.com/settings#apikey), then click `OK`.

5. Use Xcode like you normally do and your time will be tracked for you automatically.

6. Visit https://wakatime.com to see your logged time.


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
