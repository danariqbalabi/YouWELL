#!/usr/bin/env bash
# Separate Render builds for the phone web app and moderator console.
set -euo pipefail
cd "$(dirname "$0")/.."

target="${1:-mobile}"
case "$target" in
  mobile) phone_web=true ;;
  admin) phone_web=false ;;
  *) echo 'Target harus mobile atau admin.' >&2; exit 1 ;;
esac
flutter_version="${FLUTTER_VERSION:-3.47.7}"
if [ ! -x .tools/flutter/bin/flutter ]; then
  git clone --depth 1 --branch "$flutter_version" \
    https://github.com/flutter/flutter.git .tools/flutter
fi
flutter_bin=.tools/flutter/bin/flutter
"$flutter_bin" config --no-analytics >/dev/null
"$flutter_bin" pub get

# Public client configuration only; never put a service role / secret key here.
mkdir -p build
node -e '
  const env = process.env;
  if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY?.startsWith("sb_publishable_")) {
    throw new Error("Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in Render first.");
  }
  const config = {
    APP_NAME: "YouWELL",
    APP_ENV: "production",
    LOCAL_STORAGE_KEY: env.LOCAL_STORAGE_KEY || "youwell.local.v3",
    SHOW_PREVIEW_TOOLS: "false",
    AUTH_ENABLED: "true",
    SUPABASE_URL: env.SUPABASE_URL,
    SUPABASE_PUBLISHABLE_KEY: env.SUPABASE_PUBLISHABLE_KEY,
  };
  require("fs").writeFileSync("build/render-env.json", JSON.stringify(config));
'

"$flutter_bin" build web --release --no-web-resources-cdn \
  --dart-define=MOBILE_WEB="$phone_web" \
  --dart-define=MOBILE_PREVIEW=false \
  --dart-define-from-file=build/render-env.json
