xcode-wakatime
==============

[![Coding time tracker](https://wakatime.com/badge/github/wakatime/xcode-wakatime.svg)](https://wakatime.com/badge/github/wakatime/xcode-wakatime)

[WakaTime][wakatime] is an open source Xcode plugin for metrics, insights, and time tracking automatically generated from your programming activity.

Note: Xcode8 disables plugins. Installing WakaTime re-signs Xcode.app with a self-signed cert.


Installation
------------

1. Run this Terminal command:

  ```
  curl -fsSL https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/install.sh | sh
  ```

2. Restart Xcode.

3. Enter your [api key](https://wakatime.com/settings#apikey), then click `OK`.
  (Skip this step if you already have another WakaTime plugin)

4. Use Xcode and your coding activity will be displayed on your [WakaTime dashboard](https://wakatime.com).


To install WakaTime for Xcode Beta, run this instead of step 1:

  ```
  curl -fsSL https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/install.sh | sh -s beta
  ```


To install WakaTime for Xcode where Xcode was installed to a non-standard folder:

  ```
  curl -fsSL https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/install.sh | sh -s custom /Path/To/Your/Xcode.app
  ```


To clone your `Xcode.app` to preserve the original app signature, run this instead of step 1:

  ```
  curl -fsSL https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/install.sh | sh -s copy
  ```

Screen Shots
------------

![Project Overview](https://wakatime.com/static/img/ScreenShots/Screen-Shot-2016-03-21.png)


Troubleshooting
---------------

First, do you see the `Xcode → File → WakaTime API Key` menu?

![plugin menu](https://wakatime.com/static/img/plugins/troubleshooting/xcode-menu.png)

If you see that menu, it means the plugin was installed correctly and is running in Xcode... yay! Have a blank dashboard but see the plugin menu? Check your `~/.wakatime.log` file for error messages.

If you don’t see that menu, try re-installing the plugin. That’s needed anytime `Xcode.app` is updated and generally solves most issues:

```
curl -fsSL https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/install.sh | sh
```

If that doesn't work, turn on debug mode and check your wakatime cli log file (`~/.wakatime.log`).

If there are no errors in your `~/.wakatime.log` file, check your Xcode log file (`/var/log/system.log`).

For more general troubleshooting information, see [wakatime/wakatime#troubleshooting](https://github.com/wakatime/wakatime#troubleshooting).


Uninstalling
------------

To uninstall the WakaTime plugin, config file, and Alcatraz run these Terminal commands:

    rm -r "${HOME}/Library/Application Support/Developer/Shared/Xcode/Plug-ins/WakaTime.xcplugin"
    rm "${HOME}/.wakatime.cfg"
    rm -r "${HOME}/Library/Application Support/Developer/Shared/Xcode/Plug-ins/Alcatraz.xcplugin"
    crontab -e

When crontab opens, remove the WakaTime line.
Uninstalling Alcatraz is optional, and will prevent other non-WakaTime plugins from loading.
After uninstalling, restart Xcode and you should no longer see WakaTime under the `File` menu.

[wakatime]: https://wakatime.com/xcode
