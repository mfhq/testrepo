#!/bin/bash
#
# Build Manifold and manifold-builder from a branch or tag of their repositories,
# and install them to /usr/local together with manifold-mrepo. Runs as root, when
# the image of the CI container is built.
#
# Usage: install-tools.sh [MANIFOLD_REF [BUILDER_REF [MREPO_REF]]]
#
set -euo pipefail

manifold_ref=${1:-main}
builder_ref=${2:-main}
mrepo_ref=${3:-main}

src=/usr/local/src
# which commit of each project we got, for the logs of the builds
versions=/usr/local/share/manifold-ci/versions
jobs=$(nproc)
jobs=$((jobs < 12 ? jobs : 12))

mkdir -p "$src" "$(dirname "$versions")"
: > "$versions"

fetch()
{
    local name=$1
    local ref=$2

    git clone --quiet --depth 1 --branch "$ref" --recurse-submodules --shallow-submodules \
        "https://github.com/mfhq/$name.git" "$src/$name"
    echo "$name $ref $(git -C "$src/$name" rev-parse HEAD)" >> "$versions"
}

# Manifold, with the introspection data manifold-mrepo uses it through. Only
# libglnx comes from a subproject, so we never end up with a second AppStream.
fetch manifold "$manifold_ref"
meson setup "$src/manifold/build" "$src/manifold" \
    --buildtype=debugoptimized \
    --wrap-mode=nofallback \
    -Dforce_fallback_for=libglnx \
    -Ddocs=false \
    -Dgir=enabled
meson compile -C "$src/manifold/build" -j "$jobs"
meson install -C "$src/manifold/build" --skip-subprojects
ldconfig

# manifold-builder, which has to build on the Manifold we just installed, and
# not on the one of its subproject
fetch manifold-builder "$builder_ref"
meson setup "$src/manifold-builder/build" "$src/manifold-builder" \
    --buildtype=debugoptimized \
    --wrap-mode=nofallback
meson compile -C "$src/manifold-builder/build" -j "$jobs"
meson install -C "$src/manifold-builder/build" --skip-subprojects

# manifold-mrepo runs from its source tree, its dependencies are Debian's
fetch manifold-minirepo "$mrepo_ref"
cat > /usr/local/bin/manifold-mrepo << EOF
#!/bin/sh
export PYTHONPATH="$src/manifold-minirepo\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 -m manifold_mrepo "\$@"
EOF
chmod 0755 /usr/local/bin/manifold-mrepo

rm -rf "$src/manifold" "$src/manifold-builder"

# check that everything runs, and that mrepo finds libmanifold
manifold-builder --version
manifold-mrepo --version
PYTHONPATH="$src/manifold-minirepo" python3 -c 'import manifold_mrepo.bindings'
cat "$versions"
