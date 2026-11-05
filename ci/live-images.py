#!/usr/bin/python3 -I
#
# Print the file names of the images that the Manifold repository at a URL
# lists, as <verity-hash>.raw.zck, one per line. If there is no repository at
# that URL yet, this prints nothing.
#
# Usage: live-images.py REPO_URL
#

import io
import sys
import json
import posixpath
import urllib.error
import urllib.request

import zstandard

USER_AGENT = 'manifold-testrepo-ci'
TIMEOUT_SECONDS = 60
MANIFEST_SUFFIX = '.json.zst'
IMAGE_SUFFIX = '.raw.zck'


def fetch(url: str) -> bytes | None:
    """Download a file, or return None if it is not there."""
    request = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.read()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def read_index(data: bytes) -> dict:
    with zstandard.ZstdDecompressor().stream_reader(io.BytesIO(data)) as reader:
        return json.loads(reader.read())


def live_images(repo_url: str) -> set[str]:
    root_data = fetch(repo_url + '/repo-index.json.zst')
    if root_data is None:
        return set()

    images = set()
    for channel_name, channel in read_index(root_data)['channels'].items():
        for arch in channel['architectures']:
            index_url = '{}/{}/{}/index.json.zst'.format(repo_url, channel_name, arch)
            index_data = fetch(index_url)
            if index_data is None:
                sys.exit('{} is missing, but the root index lists it'.format(index_url))
            for component in read_index(index_data)['components'].values():
                for version in component['versions']:
                    # an image is named like its manifest, which is all the index gives
                    name = posixpath.basename(version['manifest']['location'])
                    if not name.endswith(MANIFEST_SUFFIX):
                        sys.exit('The manifest {} is not named after its image'.format(name))
                    images.add(name.removesuffix(MANIFEST_SUFFIX) + IMAGE_SUFFIX)
    return images


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit('Usage: {} REPO_URL'.format(sys.argv[0]))
    for name in sorted(live_images(sys.argv[1].rstrip('/'))):
        print(name)


if __name__ == '__main__':
    main()
