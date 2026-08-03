#!/usr/bin/env bash
#
# render-icons.sh — Régénère le jeu d'icônes desktop depuis le logo vectoriel
# officiel (epilote/assets/icons/logo.svg) vers packaging/icons/.
#
# Le logo contient du TEXTE VIVANT en « Arial Black »/« Impact » (polices
# absentes sous Linux). ImageMagick le rend mal (clipping). On privilégie donc,
# dans l'ordre : rsvg-convert (librsvg) → Google Chrome headless → ImageMagick.
# Chrome donne le rendu le plus fidèle (mise en page du texte, dégradés).
#
# À relancer uniquement quand le logo change ; les PNG produits sont VERSIONNÉS
# (packaging/icons/) et consommés tels quels par build-deb.sh.
#
# Usage :  ./packaging/render-icons.sh

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$REPO_ROOT/epilote/assets/icons/logo.svg"
OUT="$REPO_ROOT/packaging/icons"
APPID="cg.epilote.epilote"
SIZES="1024 512 256 128 64 48 32 16"
[ -f "$SVG" ] || { echo "✗ logo introuvable : $SVG"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
MASTER="$TMP/master.png"    # rendu haute résolution 1024²

echo "▶ Rendu du master 1024² depuis $SVG"
if command -v rsvg-convert >/dev/null 2>&1; then
  echo "  moteur : rsvg-convert"
  rsvg-convert -w 1024 -h 1024 "$SVG" -o "$MASTER"
elif command -v google-chrome >/dev/null 2>&1 || command -v chromium >/dev/null 2>&1; then
  BROWSER="$(command -v google-chrome || command -v chromium)"
  echo "  moteur : $BROWSER (headless)"
  cp "$SVG" "$TMP/logo.svg"
  cat > "$TMP/wrap.html" <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;padding:0;background:transparent}
img{width:1024px;height:1024px;display:block}
</style></head><body><img src="logo.svg"></body></html>
HTML
  ( cd "$TMP" && "$BROWSER" --headless --disable-gpu --no-sandbox --hide-scrollbars \
      --default-background-color=00000000 --window-size=1024,1024 \
      --screenshot="$MASTER" "file://$TMP/wrap.html" >/dev/null 2>&1 )
else
  echo "  moteur : ImageMagick (repli — qualité de texte moindre)"
  convert -background none -density 512 "$SVG" -resize 1024x1024 "$MASTER"
fi
[ -s "$MASTER" ] || { echo "✗ rendu master vide"; exit 1; }

echo "▶ Déclinaison des tailles hicolor (downscale Lanczos)"
rm -rf "$OUT"
mkdir -p "$OUT/hicolor/scalable/apps"
cp "$SVG" "$OUT/hicolor/scalable/apps/${APPID}.svg"
for sz in $SIZES; do
  d="$OUT/hicolor/${sz}x${sz}/apps"; mkdir -p "$d"
  convert "$MASTER" -filter Lanczos -resize "${sz}x${sz}" -strip "$d/${APPID}.png"
done

echo "▶ Icône Windows (.ico multi-résolution)"
# Windows pioche la définition qui lui convient SELON LE CONTEXTE : 16 px dans
# la barre des tâches, 32 px sur le bureau, 256 px dans l'explorateur en grandes
# vignettes. Un .ico ne portant qu'une seule taille est rééchantillonné à la
# volée par le système, et le logo ressort baveux là où l'agent le voit le plus.
# Le 24 px n'a pas d'équivalent hicolor : on le dérive du master comme les autres.
ICO="$REPO_ROOT/epilote/windows/runner/resources/app_icon.ico"
ICO_SIZES="256 128 64 48 32 24 16"
if [ -d "$(dirname "$ICO")" ]; then
  layers=""
  for sz in $ICO_SIZES; do
    convert "$MASTER" -filter Lanczos -resize "${sz}x${sz}" -strip "$TMP/ico_${sz}.png"
    layers="$layers $TMP/ico_${sz}.png"
  done
  convert $layers "$ICO"
  echo "  ✓ $ICO ($(echo $ICO_SIZES | tr ' ' ','))"
else
  echo "  ⚠ dossier Windows absent — .ico non régénérée"
fi

echo "✓ Icônes régénérées dans $OUT"
find "$OUT" -type f | sort | sed "s#$OUT/#  #"
