#!/usr/bin/env python3

# Run this script with cron to receive a notification whenever you need to reinstall the WakaTime extension.
# For ex, run crontab -e and paste:
#   */5 * * * * /path/to/check_need_reinstall_plugin.py


import os
import plistlib
import sys
from subprocess import Popen

try:
    readPlist = plistlib.load
except AttributeError:
    raise Exception('Please use Python3.')


def main():
    dvtp_file = os.path.join(os.path.expanduser("~"), '.xcode-dvtp-uuid')
    dvtp_uuid = None
    try:
        with open(dvtp_file) as fh:
            dvtp_uuid = fh.read()
    except:
        pass

    plist_file = '/Applications/Xcode.app/Contents/Info.plist'
    with open(plist_file, 'rb') as fh:
        plist = plistlib.load(fh)

    current_uuid = plist['DVTPlugInCompatibilityUUID']
    if dvtp_uuid and dvtp_uuid.strip() != current_uuid.strip():
        Popen(['/usr/bin/osascript', '-e', 'display notification "Please re-install the WakaTime extension after updating Xcode." with title "WakaTime"'])

    with open(dvtp_file, 'w') as fh:
        fh.write(current_uuid)

    return 0


if __name__ == '__main__':
    sys.exit(main())
