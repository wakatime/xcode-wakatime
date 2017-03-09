#!/usr/bin/env python

import sys
import plistlib

try:
    readPlist = plistlib.load
except AttributeError:
    raise Exception('Please use Python3 not py2.')


def main():

    if not len(sys.argv) == 2:
        return 'Missing Info.plist file from Xcode app contents.'

    file_path = sys.argv[1]
    with open(file_path, 'rb') as fh:
        plist = plistlib.load(fh)

    print(plist['DVTPlugInCompatibilityUUID'])

    return 0


if __name__ == '__main__':
    sys.exit(main())
