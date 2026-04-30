#!/bin/bash
# MirrorTop — One-shot release publisher
#
# Yaptıkları:
#   1. (Gerekirse) make-release.sh çalıştırır → dist/MirrorTop-<version>.dmg üretir.
#   2. project.pbxproj'taki versiyon değişikliğini commit'ler.
#   3. Tag atar (vX.Y.Z) ve push eder.
#   4. gh CLI ile GitHub Release oluşturur, DMG'yi asset olarak yükler.
#
# Usage:
#   ./Scripts/publish-release.sh                         # ad-hoc imzalı build + release
#   ./Scripts/publish-release.sh --notarize              # notarize edilmiş build + release
#   ./Scripts/publish-release.sh --skip-build            # mevcut DMG'yi kullan, sadece release at
#   ./Scripts/publish-release.sh --notes "Custom notes"  # release notları override
#   ./Scripts/publish-release.sh --dry-run               # ne yapacağını yaz, gerçekten yapma
#
# Gereksinimler:
#   - gh CLI: brew install gh && gh auth login
#   - Temiz git working tree (uncommitted değişiklikler reddedilir, MARKETING_VERSION hariç).

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

PROJECT="MirrorTop.xcodeproj"
APP_NAME="MirrorTop"

# === Argümanlar ===
NOTARIZE=false
SKIP_BUILD=false
DRY_RUN=false
CUSTOM_NOTES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --notarize)   NOTARIZE=true; shift ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        --dry-run)    DRY_RUN=true; shift ;;
        --notes)      CUSTOM_NOTES="$2"; shift 2 ;;
        *) echo "Bilinmeyen argüman: $1"; exit 1 ;;
    esac
done

run() {
    if $DRY_RUN; then
        echo "  [dry-run] $*"
    else
        eval "$@"
    fi
}

# === Ön kontroller ===

if ! command -v gh >/dev/null 2>&1; then
    echo "HATA: 'gh' (GitHub CLI) bulunamadı. Yükleyin: brew install gh && gh auth login"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "HATA: gh CLI'a giriş yapılmamış. Çalıştırın: gh auth login"
    exit 1
fi

# Git working tree temiz mi? Sadece pbxproj kirliyse OK; başka dosya kirliyse uyarı.
DIRTY_FILES=$(git status --porcelain | grep -v "MirrorTop.xcodeproj/project.pbxproj" || true)
if [[ -n "$DIRTY_FILES" ]]; then
    echo "⚠️  Git working tree'de pbxproj dışında commitlenmemiş değişiklikler var:"
    echo "$DIRTY_FILES"
    read -p "Yine de devam edilsin mi? [y/N] " yn
    if [[ ! "$yn" =~ ^[Yy]$ ]]; then
        echo "İptal edildi."
        exit 1
    fi
fi

# === 1. Build (gerekirse) ===

if ! $SKIP_BUILD; then
    BUILD_ARGS=""
    if $NOTARIZE; then BUILD_ARGS="--notarize"; fi
    echo "==> make-release.sh çağrılıyor…"
    if ! $DRY_RUN; then
        ./Scripts/make-release.sh $BUILD_ARGS
    else
        echo "  [dry-run] ./Scripts/make-release.sh $BUILD_ARGS"
    fi
fi

# === 2. Versiyonu pbxproj'tan oku (build sonrası, çünkü patch artmış olabilir) ===

VERSION=$(grep -m1 "MARKETING_VERSION = " "${PROJECT}/project.pbxproj" \
    | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | tr -d ' ')
TAG="v${VERSION}"
DMG_PATH="${ROOT}/dist/${APP_NAME}-${VERSION}.dmg"

echo "==> Yayınlanacak versiyon: ${VERSION} (tag: ${TAG})"

if [[ ! -f "$DMG_PATH" ]]; then
    echo "HATA: DMG bulunamadı: $DMG_PATH"
    echo "  Önce ./Scripts/make-release.sh çalıştırın veya --skip-build kullanmayın."
    exit 1
fi

# Aynı tag zaten remote'ta var mı?
if git ls-remote --tags origin "refs/tags/${TAG}" | grep -q "${TAG}"; then
    echo "HATA: Tag ${TAG} zaten origin'de mevcut. Yeni bir versiyon için MARKETING_VERSION'u arttırın."
    exit 1
fi

# Aynı GitHub release zaten var mı?
if gh release view "${TAG}" >/dev/null 2>&1; then
    echo "HATA: GitHub Release ${TAG} zaten var. Önce silin: gh release delete ${TAG}"
    exit 1
fi

# === 3. Commit + tag + push ===

if ! git diff --quiet -- "${PROJECT}/project.pbxproj"; then
    echo "==> project.pbxproj commitleniyor…"
    run "git add \"${PROJECT}/project.pbxproj\""
    run "git commit -m \"chore: release ${VERSION}\""
fi

echo "==> Tag atılıyor: ${TAG}"
run "git tag \"${TAG}\""

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "==> Push ediliyor (${CURRENT_BRANCH} + ${TAG})…"
run "git push origin \"${CURRENT_BRANCH}\" \"${TAG}\""

# === 4. Release notları ===

if [[ -n "$CUSTOM_NOTES" ]]; then
    NOTES="$CUSTOM_NOTES"
elif [[ -f "CHANGELOG.md" ]]; then
    NOTES_FILE_ARG="--notes-file CHANGELOG.md"
    NOTES=""
else
    # Varsayılan template — unsigned/ad-hoc build'ler için.
    if $NOTARIZE; then
        INSTALL_BLOCK=""
    else
        INSTALL_BLOCK="

## Installation
This build is **not notarized** by Apple. After dragging \`MirrorTop.app\` to \`/Applications\`:

- Right-click \`MirrorTop.app\` → **Open** → **Open** again, **or**
- Run: \`xattr -dr com.apple.quarantine /Applications/MirrorTop.app\`"
    fi
    
    NOTES="## MirrorTop ${VERSION}

See [CHANGELOG.md](CHANGELOG.md) or commit history for changes.${INSTALL_BLOCK}"
fi

# === 5. GitHub Release ===

echo "==> GitHub Release oluşturuluyor…"
if [[ -n "${NOTES_FILE_ARG:-}" ]]; then
    run "gh release create \"${TAG}\" \"${DMG_PATH}\" \
        --title \"${APP_NAME} ${VERSION}\" \
        ${NOTES_FILE_ARG}"
else
    # heredoc ile notları geç
    if $DRY_RUN; then
        echo "  [dry-run] gh release create ${TAG} ${DMG_PATH} --title \"${APP_NAME} ${VERSION}\" --notes \"<see below>\""
        echo "----- NOTES -----"
        echo "$NOTES"
        echo "-----------------"
    else
        gh release create "${TAG}" "${DMG_PATH}" \
            --title "${APP_NAME} ${VERSION}" \
            --notes "${NOTES}"
    fi
fi

echo ""
echo "✅ ${TAG} yayınlandı."
echo "   $(gh release view "${TAG}" --json url -q .url 2>/dev/null || echo "https://github.com/.../releases/tag/${TAG}")"
