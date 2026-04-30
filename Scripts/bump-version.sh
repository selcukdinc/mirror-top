#!/bin/bash
# MirrorTop — patch version bumper
#
# Her Xcode build'inde MARKETING_VERSION'un patch (üçüncü) bileşenini bir artırır.
# Örnek: 0.0.1 → 0.0.2 → 0.0.3 ...
#
# Bu script Xcode "Run Script Build Phase" olarak çağrılır ve doğrudan
# project.pbxproj içindeki MARKETING_VERSION değerini günceller.

set -euo pipefail

# SwiftUI Preview / index build durumlarında atla.
if [[ "${ENABLE_PREVIEWS:-NO}" == "YES" ]] || [[ "${ACTION:-}" == "indexbuild" ]]; then
    echo "MirrorTop: preview/index build, version bump atlandı."
    exit 0
fi

# Sadece Release config'inde versiyon artır.
# Debug build'lerde pbxproj'u her seferinde değiştirmek Xcode'un "project changed during build"
# uyarısıyla build'i iptal etmesine yol açar.
if [[ "${CONFIGURATION:-}" != "Release" ]]; then
    echo "MirrorTop: ${CONFIGURATION:-?} config — version bump yalnızca Release'de çalışır, atlandı."
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

# X.Y.Z formatı bekleniyor; X.Y geldiyse otomatik X.Y.0 olarak normalize et.
if [[ "$CURRENT" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "MirrorTop: MARKETING_VERSION ($CURRENT) iki bileşenli, ${CURRENT}.0 olarak normalize ediliyor."
    CURRENT="${CURRENT}.0"
elif [[ ! "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
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
