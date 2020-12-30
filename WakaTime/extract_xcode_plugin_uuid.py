#!/usr/bin/env python3

import sys
import plistlib

try:
    readPlist = plistlib.load
except AttributeError:
    raise Exception('Please use Python3.')


def main():
    plist_file = sys.argv[1] if len(sys.argv) == 2 else '/Applications/Xcode.app/Contents/Info.plist'
    with open(plist_file, 'rb') as fh:
        plist = plistlib.load(fh)

    print(plist['DVTPlugInCompatibilityUUID'])

    return 0


if __name__ == '__main__':
    sys.exit(main())
