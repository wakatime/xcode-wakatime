#!/usr/bin/env bash

set -euo pipefail

osascript -e 'display notification "Please type your sudo password." with title "WakaTime"'

set +e
xcrun xcodebuild -version > /dev/null 2>/dev/null
RESULT="$?"
set -e
if [ $RESULT != 0 ]; then
  sudo xcode-select --reset
fi

DOWNLOAD_URI=https://github.com/wakatime/xcode-wakatime/archive/master.tar.gz
PLUGINS_DIR="${HOME}/Library/Application Support/Developer/Shared/Xcode/Plug-ins"
RESOURCES_DIR="${HOME}/Library/Application Support/Developer/Shared/Xcode/Plug-ins/WakaTime.xcplugin/Contents/Resources"
XCODE_VERSION="$(xcrun xcodebuild -version | head -n1 | awk '{ print $2 }')"
PLIST_PLUGINS_KEY="DVTPlugInManagerNonApplePlugIns-Xcode-${XCODE_VERSION}"
BUNDLE_ID="WakaTime.WakaTime"
APP="/Applications/Xcode.app"
CERT_PASS="xcodesigner"
ME="${USER}"
ALREADYHASCRON=false
if sudo grep -q WakaTime "/var/at/tabs/$ME"; then
  ALREADYHASCRON=true
fi

args=($@)

contains() {
  string="$1"
  if [[ -z ${2+x} ]]; then
    echo "";
  else
    substring="$2"
    if printf %s\\n "${string}" | grep -qF "${substring}"; then
      echo "1";
    else
      echo "";
    fi
  fi
}

running=$(pgrep Xcode || true)
if [ "$running" != "" ]; then
  echo "Error: Please quit Xcode then try running this script again."
  exit 1
fi

if [[ ${#args[@]} != "0" ]]; then

  if [[ $(contains ${args[0]} "beta") ]]; then
    APP="/Applications/Xcode-beta.app"
  fi

  if [[ $(contains ${args[0]} "custom") ]]; then
    APP=${args[${#args[@]} - 1]}
  fi

  if [[ $(contains ${args[0]} "copy") ]]; then
    echo "Copying Xcode.app to XcodeWithPlugins.app..."
    if [[ $(diskutil info $(stat -f "%Sd" /Applications/Xcode.app) | grep APFS | wc -l) -gt 0 ]]; then
      sudo cp -Rpc "/Applications/Xcode.app" "/Applications/XcodeWithPlugins.app"
    else
      sudo cp -Rp "/Applications/Xcode.app" "/Applications/XcodeWithPlugins.app"
    fi
    APP="/Applications/XcodeWithPlugins.app"
  fi

fi

if [ ! -f "$APP/Contents/Info.plist" ]; then
  echo "Error: Xcode is not installed at $APP."
  exit 1
fi

echo "Installing Alcatraz..."
curl -fsSL https://raw.github.com/alanhamlett/Alcatraz/master/Scripts/install.sh | sh

# Remove WakaTime from Xcode's skipped plugins list if needed
echo "Remove WakaTime from skipped plugins list..."
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
echo "Download WakaTime..."
mkdir -p "${PLUGINS_DIR}"
curl -L $DOWNLOAD_URI | tar xvz -C "${PLUGINS_DIR}"

# Build WakaTime plugin
echo "Installing WakaTime..."
/usr/bin/xcodebuild build -project "$PLUGINS_DIR/xcode-wakatime-master/WakaTime.xcodeproj"
echo "Cleaning up after installing WakaTime..."
rm -r "$PLUGINS_DIR/xcode-wakatime-master"

echo "Make sure all installed plugins have the latest Xcode compatibility UUID..."
DVTUUIDS=$(defaults read $APP/Contents/Info.plist DVTPlugInCompatibilityUUID)
find ~/Library/Application\ Support/Developer/Shared/Xcode/Plug-ins -name Info.plist -maxdepth 3 | xargs -I{} defaults write {} DVTPlugInCompatibilityUUIDs -array-add $DVTUUIDS

# Check every 10 minutes if WakaTime needs re-installing
if ! $ALREADYHASCRON; then
  echo "*/10 * * * * \"${RESOURCES_DIR}/check_need_reinstall_plugin.py\"" | sudo tee -a "/var/at/tabs/$ME"
fi

# Install a self-signing cert to enable plugins in Xcode 8
delPem=false
if [ ! -f XcodeSigner2018.pem ]; then
  echo "Downloading public key..."
  curl -L https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/XcodeSigner2018.pem -o XcodeSigner2018.pem
  delPem=true
fi
delP12=false
if [ ! -f XcodeSigner2018.p12 ]; then
  echo "Downloading private key..."
  curl -L https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/XcodeSigner2018.p12 -o XcodeSigner2018.p12
  delP12=true
fi
delCert=false
if [ ! -f XcodeSigner2018.cert ]; then
  echo "Downloading self-signed cert..."
  curl -L https://raw.githubusercontent.com/wakatime/xcode-wakatime/master/XcodeSigner2018.cert -o XcodeSigner2018.cert
  delCert=true
fi

# fix for https://stackoverflow.com/q/24023639/1290627
osascript -e 'display notification "Please type your login keychain password." with title "WakaTime"'
security unlock-keychain login.keychain

KEYCHAIN=$(tr -d "\"" <<< `security default-keychain`)
echo "Importing self-signed cert to default keychain, select Allow when prompted..."
security import ./XcodeSigner2018.cert -k "$KEYCHAIN" || true
echo "Importing public key to default keychain, select Allow when prompted..."
security import ./XcodeSigner2018.pem -k "$KEYCHAIN" || true
echo "Importing private key to default keychain, select Allow when prompted..."
security import ./XcodeSigner2018.p12 -k "$KEYCHAIN" -P $CERT_PASS || true

echo "Resigning $APP, this may take a while..."
osascript -e "display notification \"Re-signing $APP. This may take several minutes.\" with title \"WakaTime\""
sudo codesign -f -s XcodeSigner2018 $APP

if [ "$delPem" = true ]; then
  echo "Cleaning up public key..."
  rm XcodeSigner2018.pem
fi
if [ "$delP12" = true ]; then
  echo "Cleaning up private key..."
  rm XcodeSigner2018.p12
fi
if [ "$delCert" = true ]; then
  echo "Cleaning up self-signed cert..."
  rm XcodeSigner2018.cert
fi

echo "Finished installing WakaTime. Launching Xcode..."
open "$APP"

exit 0
