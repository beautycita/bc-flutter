# BeautyCita Build Rules (Fedora)

## WHEN TO BUILD
- "build" = release APK. ONLY when BC explicitly says "build"
- Between tasks: debug compile check only (~10 sec)
- DO NOT do release builds after every code change

## DEBUG COMPILE CHECK (between tasks)
```bash
cd ~/futureBeauty/beautycita_app
flutter build apk --debug 2>&1 | tail -5
```

## RELEASE BUILD (only when BC says "build")

### Step 0: Bump BUILD NUMBER only
- Edit pubspec.yaml: increment build number (e.g. 50238 -> 50239)
- NEVER change version string (1.1.1) — BC decides when to bump version
- Current version: 1.1.1 — do NOT change this

### Step 1: Build
```bash
cd ~/futureBeauty/beautycita_app
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
flutter build apk --split-per-abi \
  --dart-define=SUPABASE_URL=https://beautycita.com/supabase \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzM1Njg5NjAwLCJleHAiOjE4OTM0NTYwMDB9.rz0oLwpK6HMsRI3PStAW3K1gl79d6z1PqqW8lvCtF9Q
```
Output: build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

### Step 2: Deploy APK to R2
```bash
aws s3 cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  s3://beautycita-medias/apk/beautycita.apk --profile r2 \
  --content-type application/vnd.android.package-archive
```

### Step 3: Update version.json (build = pubspec + 2000)
```bash
# Example: pubspec 50239 -> version.json build = 52239
echo '{"version":"1.1.1","build":52239,"buildNumber":52239,"required":false,"forceUpdate":false,"url":"https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/apk/beautycita.apk","releaseNotes":"NOTES"}' \
  | aws s3 cp - s3://beautycita-medias/version.json --profile r2 \
  --content-type application/json \
  --cache-control "no-cache, no-store, must-revalidate"
```

### Step 4: Verify
```bash
curl -s https://pub-56305a12c77043c9bd5de9db79a5e542.r2.dev/version.json
```

### Step 5: Install to test devices
```bash
adb -s 192.168.0.40:5555 install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
adb -s 192.168.0.25:5555 install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## WEB BUILD + DEPLOY
```bash
cd ~/futureBeauty/beautycita_web
flutter build web --release
rsync -avz --delete --exclude sativa build/web/ www-bc:/var/www/beautycita.com/frontend/dist/
```

## FEDORA-SPECIFIC PATHS
- JAVA_HOME: /usr/lib/jvm/java-21-openjdk (no -amd64 suffix)
- Project: ~/futureBeauty/ (user: kriket)
- Flutter: ~/flutter/bin/flutter
- AWS R2: check with `aws s3 ls s3://beautycita-medias --profile r2`

## RULES (NON-NEGOTIABLE)
1. NEVER build release without BC saying "build"
2. NEVER change version string — BC decides. Build number only.
3. NEVER upload version.json to /apk/ — always ROOT of bucket
4. version.json build = pubspec build + 2000
5. Include BOTH build AND buildNumber fields (same value)
6. Include BOTH required AND forceUpdate fields (same value)
7. Always --cache-control on version.json
8. Always --split-per-abi on APK build
