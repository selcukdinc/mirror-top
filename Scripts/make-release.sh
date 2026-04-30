#!/bin/bash
# MirrorTop — Release packager
#
# Usage:
#   ./Scripts/make-release.sh
#   ./Scripts/make-release.sh --notarize   (kod imzalama + Apple notarizasyon)
#
# Yaptıkları:
#   1. xcodebuild ile Release archive üretir.
#   2. Archive'dan MirrorTop.app'i export eder.
#   3. create-dmg ile MirrorTop-<version>.dmg üretir.
#   4. (opsiyonel) notarytool ile notarize + staple eder.
#   5. dist/ klasörüne yerleştirir.
#
# Sonra elle veya `gh release create` ile GitHub'a yüklersin.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

# === Ayarlar ===
PROJECT="MirrorTop.xcodeproj"
SCHEME="MirrorTop"
APP_NAME="MirrorTop"
DIST_DIR="${ROOT}/dist"
BUILD_DIR="${ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"

NOTARIZE=false
for arg in "$@"; do
    case "$arg" in
        --notarize) NOTARIZE=true ;;
    esac
done

# xcpretty varsa kullan, yoksa cat. (xcpretty isteğe bağlı, kurulu olmayabilir.)
if command -v xcpretty >/dev/null 2>&1; then
    PRETTY="xcpretty"
else
    PRETTY="cat"
fi

# === Versiyonu pbxproj'tan oku ===
VERSION=$(grep -m1 "MARKETING_VERSION = " "${PROJECT}/project.pbxproj" \
    | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | tr -d ' ')
echo "==> Versiyon: ${VERSION}"

# === Temizle ===
rm -rf "${BUILD_DIR}"
mkdir -p "${DIST_DIR}" "${EXPORT_DIR}"

# === 1. Archive ===
echo "==> Archive oluşturuluyor…"
xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    archive | $PRETTY

if [[ ! -d "${ARCHIVE_PATH}" ]]; then
    echo "HATA: Archive oluşmadı."
    exit 1
fi

# === 2. .app'i archive'dan al ===
# Notarize edilmeyecekse exportArchive'a (Developer ID gerektirir) ihtiyacımız yok;
# .app'i archive içinden doğrudan kopyalıyoruz.
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"

if $NOTARIZE; then
    echo "==> .app export ediliyor (developer-id)…"
    EXPORT_PLIST="${BUILD_DIR}/ExportOptions.plist"
    cat > "${EXPORT_PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF
    xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_PATH}" \
        -exportPath "${EXPORT_DIR}" \
        -exportOptionsPlist "${EXPORT_PLIST}" | $PRETTY
else
    echo "==> .app archive içinden kopyalanıyor (Developer ID yok, ad-hoc imza kullanılacak)…"
    ARCHIVE_APP="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
    if [[ ! -d "${ARCHIVE_APP}" ]]; then
        echo "HATA: Archive içinde .app bulunamadı: ${ARCHIVE_APP}"
        exit 1
    fi
    cp -R "${ARCHIVE_APP}" "${APP_PATH}"
fi

if [[ ! -d "${APP_PATH}" ]]; then
    echo "HATA: ${APP_PATH} bulunamadı."
    exit 1
fi

# === 2.5. Ad-hoc imzalama (paid Developer Program üyeliği yoksa fallback) ===
# Eğer notarize edilmeyecekse en azından ad-hoc (`-`) imza ile "zarar verebilir"
# uyarısını "kimliği doğrulanamadı" seviyesine düşürürüz; kullanıcı sağ-tık → Aç ile geçer.
if ! $NOTARIZE; then
    echo "==> Ad-hoc imzalama uygulanıyor (notarize devre dışı)…"
    /usr/bin/codesign --force --deep --sign - "${APP_PATH}"
    echo "    → imza doğrulanıyor:"
    /usr/bin/codesign --verify --verbose=2 "${APP_PATH}" || true
fi

# === 3. (Opsiyonel) Notarize ===
if $NOTARIZE; then
    if [[ -z "${MT_NOTARY_PROFILE:-}" ]]; then
        echo "HATA: --notarize için MT_NOTARY_PROFILE env değişkeni gerekli."
        echo "  xcrun notarytool store-credentials MT_NOTARY ile bir keychain profili oluştur,"
        echo "  ardından: export MT_NOTARY_PROFILE=MT_NOTARY"
        exit 1
    fi
    echo "==> Zip'leniyor (notarize için)…"
    NOTARIZE_ZIP="${BUILD_DIR}/${APP_NAME}.zip"
    /usr/bin/ditto -c -k --keepParent "${APP_PATH}" "${NOTARIZE_ZIP}"
    
    echo "==> notarytool submit…"
    xcrun notarytool submit "${NOTARIZE_ZIP}" \
        --keychain-profile "${MT_NOTARY_PROFILE}" \
        --wait
    
    echo "==> Stapler…"
    xcrun stapler staple "${APP_PATH}"
fi

# === 4. DMG ===
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
rm -f "${DMG_PATH}"

if command -v create-dmg >/dev/null 2>&1; then
    echo "==> create-dmg ile .dmg üretiliyor…"
    create-dmg \
        --volname "${APP_NAME} ${VERSION}" \
        --window-size 540 360 \
        --icon-size 96 \
        --icon "${APP_NAME}.app" 140 170 \
        --app-drop-link 400 170 \
        --no-internet-enable \
        "${DMG_PATH}" \
        "${APP_PATH}" || true
else
    echo "==> create-dmg yok, hdiutil ile basit .dmg üretiliyor…"
    STAGE="${BUILD_DIR}/dmg-stage"
    rm -rf "${STAGE}"
    mkdir -p "${STAGE}"
    cp -R "${APP_PATH}" "${STAGE}/"
    ln -s /Applications "${STAGE}/Applications"
    hdiutil create -volname "${APP_NAME} ${VERSION}" \
        -srcfolder "${STAGE}" \
        -ov -format UDZO \
        "${DMG_PATH}"
fi

if $NOTARIZE; then
    echo "==> DMG'yi de notarize ediyoruz…"
    xcrun notarytool submit "${DMG_PATH}" \
        --keychain-profile "${MT_NOTARY_PROFILE}" \
        --wait
    xcrun stapler staple "${DMG_PATH}"
fi

echo ""
echo "✅ Hazır: ${DMG_PATH}"
echo ""

if ! $NOTARIZE; then
    cat <<EOF
⚠️  Bu build notarize EDİLMEDİ (yalnızca ad-hoc imzalı).
    Kullanıcılar ilk açışta Gatekeeper uyarısı görecek. README'deki
    "Installation (unsigned build)" bölümündeki talimatları release
    notlarına eklemeyi unutma:

      • Sağ tık → Aç → tekrar Aç (tek seferlik onay)
      • Veya:  xattr -dr com.apple.quarantine /Applications/MirrorTop.app

EOF
fi

echo "Sonraki adımlar:"
echo "  1) git tag v${VERSION} && git push origin v${VERSION}"
echo "  2) gh release create v${VERSION} \"${DMG_PATH}\" \\"
echo "       --title \"MirrorTop ${VERSION}\" \\"
echo "       --notes-file CHANGELOG.md"
echo ""
echo "  Önemli: tag adı 'v${VERSION}' VEYA '${VERSION}' olmalı (UpdateChecker ikisini de tanır)."
echo "  'draft' ya da 'pre-release' işaretli release UpdateChecker tarafından yok sayılır."
