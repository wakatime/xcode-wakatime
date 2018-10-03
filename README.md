xcode-wakatime
==============

Xcode plugin to quantify your coding using https://wakatime.com/.

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

Try re-installing, which fixes most problems related to upgrading Xcode:

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

The config file contains your API Key, so make sure to at least run the first two commands.
Uninstalling Alcatraz is optional, and will prevent other non-WakaTime plugins from loading.
After uninstalling, restart Xcode and you should no longer see WakaTime under the `File` menu.
