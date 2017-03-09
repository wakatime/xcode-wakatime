xcode-wakatime
==============

Xcode plugin to quantify your coding using https://wakatime.com/.

Note: Xcode8 disables plugins. Installing WakaTime re-signs Xcode.app with a self-signed cert.


Installation
------------

1. Run this in a Terminal:

  ```
  curl -fsSL https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/install.sh | sh
  ```

2. Restart Xcode.
  
3. Enter your [api key](https://wakatime.com/settings#apikey), then click `OK`.
  (Skip this step if you already have another WakaTime plugin)

4. Use Xcode and your coding activity will be displayed on your [WakaTime dashboard](https://wakatime.com).


Screen Shots
------------

![Project Overview](https://wakatime.com/static/img/ScreenShots/Screen-Shot-2016-03-21.png)


Troubleshooting
---------------

Try running this Terminal command:

```
curl -fsSL https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/WakaTime/install_dependencies.sh | bash
```

That will re-download the [wakatime-cli dependency](https://github.com/wakatime/wakatime).

If that doesn't work, turn on debug mode and check your wakatime cli log file (`~/.wakatime.log`).

If there are no errors in your `~/.wakatime.log` file, check your Xcode log file (`/var/log/system.log`).

For more general troubleshooting information, see [wakatime/wakatime#troubleshooting](https://github.com/wakatime/wakatime#troubleshooting).
