#!/bin/bash
#
# Install what building Manifold and manifold-builder needs, what builds run,
# and what manifold-mrepo needs, on Debian. Runs as root, when the image of the
# CI container is built.
#
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

packages=(
    build-essential
    meson
    ninja-build
    pkgconf
    cmake
    git
    ca-certificates
    python3
    gettext
    # Manifold
    systemd
    systemd-dev
    libsystemd-dev
    libglib2.0-dev
    libcurl4-openssl-dev
    libappstream-dev
    libblake3-dev
    libzip-dev
    libzck-dev
    libzstd-dev
    libcryptsetup-dev
    libelf-dev
    gobject-introspection
    libgirepository1.0-dev
    # manifold-builder
    libappstream-compose-dev
    libglaze-dev
    quill-dev
    libcatch2-dev
    # what builds run
    attr
    bubblewrap
    curl
    debootstrap
    debuerreotype
    erofs-utils
    erofsfuse
    fuse3
    openssh-client
    patch
    systemd-repart
    tar
    uidmap
    unzip
    util-linux
    # manifold-mrepo
    python3-gi
    gir1.2-glib-2.0
    gir1.2-appstream-1.0
    gir1.2-appstreamcompose-1.0
    python3-blake3
    python3-click
    python3-sqlalchemy
    python3-zstandard
)

apt-get update -q
apt-get install -yq --no-install-recommends "${packages[@]}"
rm -rf /var/lib/apt/lists/*

# debootstrap gives up on a package as soon as wget fails to fetch it once, and
# snapshot.debian.org turns requests away for a while when it is busy. wget
# retries network errors on its own (20 times, waiting up to 10 seconds in
# between), but not error responses or refused connections, unless told to.
cat >> /etc/wgetrc <<'EOF'

# added for the CI of the Manifold test repository
retry_on_http_error = 429,500,502,503,504
retry_connrefused = on
EOF

# A copy of debuerreotype that takes the current Debian archive wherever it
# would take a snapshot, for building cores while snapshot.debian.org is unwell.
# build-recipes.sh uses it with CORE_ARCHIVE=current. Its scripts read the
# version from next to their directory, so we copy all of it.
current=/usr/local/share/manifold-ci/debuerreotype-current
mkdir -p "$(dirname "$current")"
cp -a /usr/share/debuerreotype "$current"
cat > "$current/scripts/.snapshot-url.sh" <<'EOF'
#!/usr/bin/env bash
# Stands in for the script of debuerreotype that names the snapshot of an
# archive at a time: we name the archive as it is now, whatever the time.
set -Eeuo pipefail
echo "http://deb.debian.org/${2:-debian}"
EOF
