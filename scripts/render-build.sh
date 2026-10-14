#!/usr/bin/env bash
# Render static-site build: the phone app as an installable web app
# (iPhone users add it via Share → Add to Home Screen).
set -euo pipefail
cd "$(dirname "$0")/.."

flutter_version="${FLUTTER_VERSION:-3.47.2}"
if [ ! -x .tools/flutter/bin/flutter ]; then
  git clone --depth 1 --branch "$flutter_version" \
    https://github.com/flutter/flutter.git .tools/flutter
fi
flutter_bin=.tools/flutter/bin/flutter
"$flutter_bin" config --no-analytics >/dev/null
"$flutter_bin" pub get

# Public build values only, taken from Render environment variables.
# Never put a service role key here: everything below ships to browsers.
mkdir -p build
node -e '
  const env = process.env;
  const config = {
    APP_NAME: "YouWELL",
    APP_ENV: "production",
    LOCAL_STORAGE_KEY: env.LOCAL_STORAGE_KEY || "youwell.local.v3",
    SHOW_PREVIEW_TOOLS: "false",
    SUPABASE_URL: env.SUPABASE_URL || "",
    SUPABASE_PUBLISHABLE_KEY: env.SUPABASE_PUBLISHABLE_KEY || "",
  };
  require("fs").writeFileSync("build/render-env.json", JSON.stringify(config));
'

"$flutter_bin" build web --release --no-web-resources-cdn \
  --dart-define=MOBILE_WEB=true \
  --dart-define-from-file=build/render-env.json
