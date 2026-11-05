#!/usr/bin/python3 -I
#
# Print a setting of the repository from manifold-repo.toml, for the scripts
# that need one without running manifold-mrepo:
#
#   url          where the repository is published
#   release-tag  the tag of the release whose assets are the images, taken from
#                the image URL prefix of the main channel
#
# Usage: repo-config.py SETTING
#

import re
import sys
import tomllib

CONFIG_FILE = 'manifold-repo.toml'
# the image URL prefix of a channel whose images are release assets of a GitHub project
RELEASE_IMAGE_URL_PREFIX_RE = re.compile(r'^https://github\.com/[^/]+/[^/]+/releases/download/(?P<tag>[^/]+)/?$')


def release_tag(config: dict) -> str:
    prefix = config.get('channels', {}).get('main', {}).get('image-url-prefix', '')
    match = RELEASE_IMAGE_URL_PREFIX_RE.match(prefix)
    if match is None:
        sys.exit('The image URL prefix of the main channel is not the URL of a GitHub release: {}'.format(prefix))
    return match['tag']


def main() -> None:
    settings = {
        'url': lambda config: config['repository']['url'].rstrip('/'),
        'release-tag': release_tag,
    }
    if len(sys.argv) != 2 or sys.argv[1] not in settings:
        sys.exit('Usage: {} {}'.format(sys.argv[0], '|'.join(settings)))
    with open(CONFIG_FILE, 'rb') as f:
        config = tomllib.load(f)
    print(settings[sys.argv[1]](config))


if __name__ == '__main__':
    main()
