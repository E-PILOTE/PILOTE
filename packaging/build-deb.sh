#!/usr/bin/env bash
#
# build-deb.sh — Empaquetage .deb professionnel d'E-PILOTE CONGO (desktop Linux).
#
# Produit un paquet Debian/Ubuntu installable (menu, icône, dépendances gérées,
# désinstallation propre). Reproductible : relançable à chaque release.
#
# Prérequis (hôte de build) :
#   sudo apt-get install -y dpkg-dev imagemagick libsecret-1-dev
#   (dpkg-dev fournit dpkg-shlibdeps ; libsecret-1-dev est requis par le build Flutter)
#
# Usage (depuis la racine du dépôt) :
#   ./packaging/build-deb.sh              # build release + paquet
#   SKIP_FLUTTER_BUILD=1 ./packaging/build-deb.sh   # réutilise un bundle déjà compilé
#
# Le .deb atterrit dans   dist/epilote_<version>_amd64.deb
#
# ⚠️ Les noms de paquets de dépendances sont calculés par dpkg-shlibdeps SUR
#    L'HÔTE DE BUILD. Ubuntu 24.04+ utilise le suffixe « t64 » (libgtk-3-0t64…).
#    Pour cibler une génération plus ancienne (22.04), builder sur cette
#    génération : les dépendances s'ajustent automatiquement.

set -euo pipefail

# ── Résolution des chemins ───────────────────────────────────────────────────
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$REPO_ROOT/epilote"
FLUTTER_BIN="${FLUTTER_BIN:-/home/melack/flutter/bin/flutter}"
APPID="cg.epilote.epilote"
ARCH="amd64"

# Version depuis pubspec.yaml (avant le +build).
VERSION="$(grep -E '^version:' "$APP_DIR/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)"
echo "▶ E-PILOTE — empaquetage .deb v${VERSION}"

BUNDLE="$APP_DIR/build/linux/x64/release/bundle"
ICON_SRC="$APP_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
STAGE="$(mktemp -d)/epilote_${VERSION}_${ARCH}"
DIST="$REPO_ROOT/dist"

# ── 1) Compilation release ───────────────────────────────────────────────────
if [ "${SKIP_FLUTTER_BUILD:-0}" != "1" ]; then
  echo "▶ flutter build linux --release"
  ( cd "$APP_DIR" && "$FLUTTER_BIN" build linux --release )
fi
[ -x "$BUNDLE/epilote" ] || { echo "✗ bundle introuvable : $BUNDLE"; exit 1; }

# ── 2) Arborescence FHS ──────────────────────────────────────────────────────
echo "▶ Construction de l'arborescence"
rm -rf "$STAGE"
mkdir -p "$STAGE/DEBIAN" "$STAGE/opt/epilote" "$STAGE/usr/bin" \
         "$STAGE/usr/share/applications"
cp -a "$BUNDLE"/. "$STAGE/opt/epilote/"

# Lanceur dans le PATH.
cat > "$STAGE/usr/bin/epilote" <<'EOF'
#!/bin/sh
exec /opt/epilote/epilote "$@"
EOF
chmod 755 "$STAGE/usr/bin/epilote"

# Entrée de menu.
cat > "$STAGE/usr/share/applications/${APPID}.desktop" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=E-PILOTE CONGO
GenericName=Gestion scolaire
Comment=Plateforme nationale de gestion scolaire (MEPSA · METP)
Exec=/opt/epilote/epilote %U
Icon=${APPID}
Terminal=false
Categories=Education;
StartupWMClass=${APPID}
Keywords=école;scolaire;gestion;epilote;congo;inscription;
EOF

# Icônes hicolor (depuis le 1024²).
for sz in 512 256 128 64 48 32 16; do
  d="$STAGE/usr/share/icons/hicolor/${sz}x${sz}/apps"
  mkdir -p "$d"
  convert "$ICON_SRC" -resize ${sz}x${sz} "$d/${APPID}.png"
done

# ── 3) Dépendances runtime EXACTES via dpkg-shlibdeps ────────────────────────
echo "▶ Calcul des dépendances (dpkg-shlibdeps)"
SHLIB="$(mktemp -d)"; mkdir -p "$SHLIB/debian"
printf 'Source: epilote\nPackage: epilote\nArchitecture: %s\n' "$ARCH" > "$SHLIB/debian/control"
: > "$SHLIB/debian/substvars"
DEPS="$( cd "$SHLIB" && dpkg-shlibdeps -O --ignore-missing-info \
          -l"$BUNDLE/lib" "$BUNDLE/epilote" "$BUNDLE"/lib/*.so 2>/dev/null \
          | sed 's/^shlibs:Depends=//' )"
[ -n "$DEPS" ] || { echo "✗ dépendances vides — dpkg-dev installé ?"; exit 1; }

# ── 4) Métadonnées + scripts mainteneur ──────────────────────────────────────
ISIZE="$(du -sk --exclude=DEBIAN "$STAGE" | cut -f1)"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: epilote
Version: ${VERSION}
Section: education
Priority: optional
Architecture: ${ARCH}
Depends: ${DEPS}
Maintainer: E-PILOTE CONGO <support@epilote.cg>
Installed-Size: ${ISIZE}
Homepage: https://epilote.cg
Description: Plateforme nationale de gestion scolaire (offline-first)
 E-PILOTE CONGO — solution de gestion scolaire pour la Republique du
 Congo (commande MEPSA + METP). Multi-tenant, offline-first (PowerSync),
 destinee aux etablissements publics et prives : inscriptions, scolarite,
 emploi du temps, evaluation, finance, RH et vie scolaire.
EOF

cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    command -v update-desktop-database >/dev/null 2>&1 && \
        update-desktop-database -q /usr/share/applications || true
    command -v gtk-update-icon-cache >/dev/null 2>&1 && \
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
EOF

cat > "$STAGE/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    command -v update-desktop-database >/dev/null 2>&1 && \
        update-desktop-database -q /usr/share/applications || true
    command -v gtk-update-icon-cache >/dev/null 2>&1 && \
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
exit 0
EOF
chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

# ── 5) Permissions FHS + build root:root ─────────────────────────────────────
find "$STAGE/opt" "$STAGE/usr" -type d -exec chmod 755 {} +
find "$STAGE/opt" "$STAGE/usr" -type f -exec chmod 644 {} +
chmod 755 "$STAGE/opt/epilote/epilote" "$STAGE/usr/bin/epilote"

mkdir -p "$DIST"
DEB="$DIST/epilote_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$DEB"

echo ""
echo "✓ Paquet : $DEB"
dpkg-deb --info "$DEB" | sed -n '/Package:/,/Description:/p'
echo "Installer : sudo apt install $DEB"
