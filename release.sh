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

# The DMG is the direct-download artifact for the website: a drag-to-install
# window with an Applications symlink. It gets its own signature and its own
# notarisation — Gatekeeper checks the container as well as the app inside.
DMG="${DIST}/${APP_NAME}-${VERSION}.dmg"
echo "==> DMG hazırlanıyor"
STAGE="$(mktemp -d)"
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"
rm -f "${DMG}"
hdiutil create -volname "Tap Spaces" -srcfolder "${STAGE}" \
    -ov -format UDZO -quiet "${DMG}"
rm -rf "${STAGE}"

SIGN_IDENTITY=$(security find-identity -v -p codesigning \
    | grep "Developer ID Application" \
    | head -1 | sed -E 's/.*"(.*)"/\1/')
codesign --force --sign "${SIGN_IDENTITY}" --timestamp "${DMG}"

echo "==> DMG Apple'a gönderiliyor"
xcrun notarytool submit "${DMG}" --keychain-profile "${PROFILE}" --wait
xcrun stapler staple "${DMG}"

echo "==> Doğrulanıyor"
xcrun stapler validate "${APP}"
spctl -a -vvv -t install "${APP}" 2>&1 | sed 's/^/    /'
xcrun stapler validate "${DMG}"

SHA=$(shasum -a 256 "${ZIP}" | awk '{print $1}')
SHA_DMG=$(shasum -a 256 "${DMG}" | awk '{print $1}')
echo
echo "==> Hazır"
echo "    zip   : ${ZIP}"
echo "    sha256: ${SHA}"
echo "    dmg   : ${DMG}"
echo "    sha256: ${SHA_DMG}"
