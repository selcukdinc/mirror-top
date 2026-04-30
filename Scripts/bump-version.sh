#!/bin/bash
# MirrorTop — patch version bumper
#
# Her Xcode build'inde MARKETING_VERSION'un patch (üçüncü) bileşenini bir artırır.
# Örnek: 0.0.1 → 0.0.2 → 0.0.3 ...
#
# Bu script Xcode "Run Script Build Phase" olarak çağrılır ve doğrudan
# project.pbxproj içindeki MARKETING_VERSION değerini günceller.

set -euo pipefail

# SwiftUI Preview / index build durumlarında atla (sürekli artışı önle).
if [[ "${ENABLE_PREVIEWS:-NO}" == "YES" ]] || [[ "${ACTION:-}" == "indexbuild" ]]; then
    echo "MirrorTop: preview/index build, version bump atlandı."
    exit 0
fi

PBXPROJ="${SRCROOT}/MirrorTop.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
    echo "warning: project.pbxproj bulunamadı: $PBXPROJ"
    exit 0
fi

# Tüm MARKETING_VERSION satırlarını topla (Debug + Release).
CURRENT=$(grep -m1 "MARKETING_VERSION = " "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([^;]+);.*/\1/' | tr -d ' ')

if [[ -z "$CURRENT" ]]; then
    echo "warning: MARKETING_VERSION bulunamadı, atlanıyor."
    exit 0
fi

# 0.0.1 formatı bekleniyor; aksi halde dokunma.
if [[ ! "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "warning: MARKETING_VERSION format dışı ($CURRENT), atlanıyor."
    exit 0
fi

MAJOR="${CURRENT%%.*}"
REST="${CURRENT#*.}"
MINOR="${REST%%.*}"
PATCH="${REST#*.}"
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"

# Hem Debug hem Release config'lerini güncelle.
/usr/bin/sed -i '' "s/MARKETING_VERSION = ${CURRENT};/MARKETING_VERSION = ${NEW_VERSION};/g" "$PBXPROJ"

echo "MirrorTop: MARKETING_VERSION ${CURRENT} → ${NEW_VERSION}"
