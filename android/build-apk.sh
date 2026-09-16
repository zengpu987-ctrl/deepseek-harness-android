#!/bin/bash
set -euo pipefail

export JAVA_HOME=/Users/zp/jdks/jdk-17.0.20.1+1/Contents/Home
export ANDROID_HOME=/Users/zp/android-sdk
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/build-tools/35.0.0:$ANDROID_HOME/platform-tools:$PATH"

BASE=/Users/zp/Documents/Codex/2026-09-11/ge/work/android
APP="$BASE/app"
ANDROID_JAR="$ANDROID_HOME/platforms/android-35/android.jar"

cd "$BASE"

# 1. Compile resources.
aapt2 compile --dir "$APP/res" -o res.zip

# 2. Link resources + manifest into an unsigned APK.
aapt2 link -o unsigned.apk -I "$ANDROID_JAR" --manifest "$APP/AndroidManifest.xml" -R res.zip -A "$APP/assets" --auto-add-overlay

# 3. Compile Java sources.
mkdir -p classes
find "$APP/src" -name '*.java' > sources.txt
javac --release 8 -classpath "$ANDROID_JAR" -d classes @sources.txt

# 4. Dex.
mkdir -p dexout
d8 --lib "$ANDROID_JAR" --release --min-api 26 --output dexout $(find classes -name '*.class')

# 5. Add classes.dex to the APK.
cd dexout
zip -q -j ../unsigned.apk classes.dex
cd "$BASE"

# 6. Align.
zipalign -f 4 unsigned.apk aligned.apk

# 7. Generate a debug keystore if missing.
if [ ! -f debug.keystore ]; then
  keytool -genkeypair -keystore debug.keystore -storepass android \
    -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
    -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
fi

# 8. Sign.
apksigner sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android \
  --ks-key-alias androiddebugkey --out "DeepSeek-harness-android.apk" aligned.apk
apksigner verify "DeepSeek-harness-android.apk"

echo "built: $BASE/DeepSeek-harness-android.apk"
