#!/bin/bash
# Builds, notarises and packages TapSpaces for distribution.
#
# Notarisation credentials live in the macOS Keychain under the profile name
# below, put there once with:
#
#   xcrun notarytool store-credentials tapspaces \
#       --apple-id "<apple-id>" --team-id "<team-id>"
#
# No secret is ever passed on the command line or stored in this repository.
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="TapSpaces"
VERSION="$(cat VERSION)"
PROFILE="${NOTARY_PROFILE:-tapspaces}"
APP="build/${APP_NAME}.app"
DIST="dist"
ZIP="${DIST}/${APP_NAME}-${VERSION}.zip"

echo "==> Sürüm ${VERSION}"
./build.sh

# Matched with a shell test rather than `| grep -q`: under `pipefail`, grep
# closing the pipe early makes codesign exit on SIGPIPE, so a successful match
# would fail the check.
SIGNATURE="$(codesign -dvvv "${APP}" 2>&1 || true)"
if [[ "${SIGNATURE}" != *"Authority=Developer ID Application"* ]]; then
    echo "HATA: uygulama Developer ID ile imzalanmamış. Notarization reddedecektir." >&2
    exit 1
fi

mkdir -p "${DIST}"
rm -f "${ZIP}"

# Notarisation takes an archive, not a bundle. ditto preserves the symlinks and
# extended attributes that a plain `zip` would flatten and invalidate the
# signature over.
echo "==> Arşivleniyor"
ditto -c -k --keepParent "${APP}" "${ZIP}"

echo "==> Apple'a gönderiliyor (birkaç dakika sürebilir)"
xcrun notarytool submit "${ZIP}" --keychain-profile "${PROFILE}" --wait

# The ticket is stapled to the bundle, not the archive, so the app has to be
# re-zipped afterwards for the stapled copy to be the one distributed.
echo "==> Onay mührü ekleniyor"
xcrun stapler staple "${APP}"

rm -f "${ZIP}"
ditto -c -k --keepParent "${APP}" "${ZIP}"

echo "==> Doğrulanıyor"
xcrun stapler validate "${APP}"
spctl -a -vvv -t install "${APP}" 2>&1 | sed 's/^/    /'

SHA=$(shasum -a 256 "${ZIP}" | awk '{print $1}')
echo
echo "==> Hazır"
echo "    dosya : ${ZIP}"
echo "    sha256: ${SHA}"
