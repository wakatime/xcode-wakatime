#!/usr/bin/env bash

set -euo pipefail

DOWNLOAD_URI=https://github.com/wakatime/xcode-wakatime/archive/master.tar.gz
PLUGINS_DIR="${HOME}/Library/Application Support/Developer/Shared/Xcode/Plug-ins"
XCODE_VERSION="$(xcrun xcodebuild -version | head -n1 | awk '{ print $2 }')"
PLIST_PLUGINS_KEY="DVTPlugInManagerNonApplePlugIns-Xcode-${XCODE_VERSION}"
BUNDLE_ID="WakaTime.WakaTime"
APP="/Applications/Xcode.app"

running=$(ps -ef | grep "$APP/Contents/MacOS/Xcode" | wc -l)
if [ $running != 1 ]; then
  echo "Please quit Xcode before installing."
  exit 1
fi

if [ "$@" = "copy" ]; then
  echo "Copying Xcode.app to XcodeWithPlugins.app..."
  sudo cp -Rp "/Applications/Xcode.app" "/Applications/XcodeWithPlugins.app"
  APP="/Applications/XcodeWithPlugins.app"
fi

echo "Installing Alcatraz..."
curl -fsSL https://raw.github.com/alcatraz/Alcatraz/master/Scripts/install.sh | sh

echo "Installing WakaTime..."

# Remove WakaTime from Xcode's skipped plugins list if needed
TMP_FILE="$(mktemp -t ${BUNDLE_ID})"
if defaults read com.apple.dt.Xcode "$PLIST_PLUGINS_KEY" &> "$TMP_FILE"; then
  # We read the prefs successfully, delete WakaTime from the skipped list if needed
  /usr/libexec/PlistBuddy -c "delete skipped:$BUNDLE_ID" "$TMP_FILE" > /dev/null 2>&1 && {
    defaults write com.apple.dt.Xcode "$PLIST_PLUGINS_KEY" "$(cat "$TMP_FILE")"
    echo 'WakaTime was removed from Xcode'\''s skipped plugins list.' \
         'Next time you start Xcode select "Load Bundle" when prompted.'
  }
else
    # Could not read the prefs. Filter known warnings, and exit for any other.
    KNOWN_WARNING="The domain/default pair of \(.+, $PLIST_PLUGINS_KEY\) does not exist"

    # tr: For some mysterious reason, some `defaults` errors are outputed on two lines.
    # grep: -v returns 1 when output is empty (ie. we filtered the known warning)
    # so we exit on 0, which means an unknown error occured.
    tr -d '\n' < "$TMP_FILE" | egrep -v "$KNOWN_WARNING" && exit 1
fi
rm -f "$TMP_FILE"

# Download and install WakaTime
mkdir -p "${PLUGINS_DIR}"
curl -L $DOWNLOAD_URI | tar xvz -C "${PLUGINS_DIR}"

echo "Installing dependencies..."
curl -fsSL https://raw.github.com/wakatime/xcode-wakatime/master/WakaTime/install_dependencies.sh | sh

echo "Make sure plugins have the latest Xcode compatibility UUIDs..."
UUIDS=$(defaults read $APP/Contents/Info.plist DVTPlugInCompatibilityUUID)
find ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins -name Info.plist -maxdepth 3 | xargs -I{} defaults write {} DVTPlugInCompatibilityUUIDs -array-add $UUIDS

# Install a self-signing cert to enable plugins in Xcode 8
delPem=false
if [ ! -f XcodeSigner.pem ]; then
  echo "Downloading self-signed cert public key..."
  curl -L https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/XcodeSigner.pem -o XcodeSigner.pem
  delPem=true
fi
delP12=false
if [ ! -f XcodeSigner.p12 ]; then
  echo "Downloading self-signed cert private key..."
  curl -L https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/XcodeSigner.p12 -o XcodeSigner.p12
  delP12=true
fi

echo "Importing self-signed cert to default keychain, select Allow when prompted..."
KEYCHAIN=$(tr -d "\"" <<< `security default-keychain`)
security import ./XcodeSigner.pem -k "$KEYCHAIN"
security import ./XcodeSigner.p12 -k "$KEYCHAIN" -P xcodesigner

echo "Resigning $APP, this may take a while..."
sudo codesign -f -s XcodeSigner $APP

if [ "$delPem" = true ]; then
  echo "Cleaning up public key..."
  rm XcodeSigner.pem
fi
if [ "$delP12" = true ]; then
  echo "Cleaning up private key..."
  rm XcodeSigner.p12
fi

echo "Finished installing WakaTIme. Please re-launch Xcode:"
echo "open $APP"
exit 0
