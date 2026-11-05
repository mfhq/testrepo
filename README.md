# testrepo

A [Manifold](https://github.com/mfhq/manifold) repository with some test data.

The repository is built from the recipes in `recipes/`, and published at
https://mfhq.github.io/testrepo. Its images are too large for GitHub Pages, so they are
assets of the [`artifacts`](https://github.com/mfhq/testrepo/releases/tag/artifacts)
release instead, and the repository points clients there.


## Recipes

`recipes/` has a directory for each kind of recipe. They are built in this order, each
kind on the ones before:

* `recipes/cores/`: cores
* `recipes/platforms/`: platforms, built on the cores
* `recipes/apps/`: applications, built on the cores and platforms

To add a recipe, put it into the directory of its kind. The
[README of manifold-builder](https://github.com/mfhq/manifold-builder) explains how to
write one.


## How it is built

The workflow in `.github/workflows/deploy-repo.yml` builds Manifold, manifold-builder and
manifold-mrepo from their `main` branches. It then builds all recipes with them, and
makes the bundles of each kind available as artifacts: `bundles-cores`,
`bundles-platforms` and `bundles-apps`.

The revisions of the images are the number of commits of this repository, and builds take
the time of the commit as `SOURCE_DATE_EPOCH`. Building a commit again gives the same
images, as long as the packages and sources they are built from did not change.

On `main`, the bundles are signed, and manifold-mrepo makes a new repository from them on
every run. The images that the release does not have yet are uploaded to it, and the
indexes and catalogs are deployed to Pages. Images that neither the new index nor the one
before it lists are then removed from the release.

Pull requests only build the recipes. The root index expires after a week, so it is
signed and published again every day. Nothing is built for that, we publish the bundles of
the last build again, for as long as their artifacts are kept (30 days). Run the workflow
by hand to build everything again, or to publish without building.

To reproduce what the workflow does, build the image it runs everything in:

```console
$ sudo podman build -t manifold-tools -f ci/Containerfile ci
```

The scripts in `ci/` then run in it with `ci/in-container.sh`.


## Setting it up

The workflow needs two keys, one that signs the bundles and one that signs the repository:

```console
$ ssh-keygen -t ed25519 -N '' -C 'testrepo bundles' -f bundle-key
$ ssh-keygen -t ed25519 -N '' -C 'testrepo repository' -f repo-key
$ gh secret set MANIFOLD_SIGNING_KEY < bundle-key
$ gh secret set MREPO_SIGNING_KEY < repo-key
$ cp bundle-key.pub trusted-keys/ci.pub
```

The repository only imports bundles that a key in `trusted-keys/` signed. Its own public
key is published next to the root index, as `testrepo_key.pub`.

GitHub Pages has to be set to deploy from GitHub Actions.
