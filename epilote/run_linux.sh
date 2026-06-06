#!/usr/bin/env bash
# Lancement E-PILOTE sur Linux desktop.
#
# Cette machine a une NVIDIA GeForce GTX 675MX (Kepler) pilotée par nouveau.
# nouveau ne reclocke pas le GPU → le rendu d'une grande frame OpenGL (plein
# écran 2560px) dépasse le délai de l'embedder Flutter et coupe l'app
# ("Timed out waiting for OpenGL frame ... Lost connection to device").
#
# On force donc le rendu logiciel (llvmpipe). LIBGL_ALWAYS_SOFTWARE seul ne
# suffit PAS : il faut aussi GALLIUM_DRIVER=llvmpipe pour basculer le renderer.
export LIBGL_ALWAYS_SOFTWARE=true
export GALLIUM_DRIVER=llvmpipe

cd "$(dirname "$0")" || exit 1
exec flutter run -d linux "$@"
