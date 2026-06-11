#!/bin/sh

# Medusa has no web_root CLI flag and doesn't read it from the environment, so
# apply the reverse-proxy base path from $MEDUSA_WEBROOT into config.ini before
# startup.

set -eu

CONFIG="/config/config.ini"
WEB_ROOT="${MEDUSA_WEBROOT:-}"

echo "Setting Medusa webroot to '${WEB_ROOT}'"

PYTHONPATH=/opt/medusa/ext python3 - "$CONFIG" "$WEB_ROOT" <<'PY'
import sys
from configobj import ConfigObj

path, web_root = sys.argv[1], sys.argv[2]
cfg = ConfigObj(path, encoding='UTF-8', default_encoding='UTF-8')
if 'General' not in cfg:
    cfg['General'] = {}
cfg['General']['web_root'] = web_root
cfg.filename = path
cfg.write()
PY
