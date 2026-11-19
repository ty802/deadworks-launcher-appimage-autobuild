#!/usr/bin/env bash
# Refresh every pin that depends on the upstream Deadworks source.
# Run from the repository root with REV (40-char commit SHA) set; VERSION is
# optional and updates the package version when it differs.
set -euo pipefail

rev="${REV:?REV must be set}"
version="${VERSION:-}"

echo "::group::Pin flake input to ${rev}"
sed -i -E "s#(github:Deadworks-net/deadworks\?dir=launcher&rev=)[0-9a-f]{40}#\1${rev}#" flake.nix
grep -q "rev=${rev}" flake.nix || {
  echo "could not update the deadworks rev in flake.nix" >&2
  exit 1
}
nix flake lock --update-input deadworks
echo "::endgroup::"

if [[ -n "$version" ]]; then
  echo "::group::Set version to ${version}"
  current="$(sed -nE 's/^[[:space:]]*version = "([^"]+)";$/\1/p' package.nix | head -n1)"
  if [[ "$current" != "$version" ]]; then
    sed -i -E "s#^([[:space:]]*)version = \"[^\"]*\";\$#\1version = \"${version}\";#" package.nix
    echo "package.nix: ${current:-<none>} -> ${version}"
  else
    echo "package.nix already at ${version}"
  fi
  echo "::endgroup::"
fi

echo "::group::Refresh Bun dependency hash if needed"
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

for attempt in 1 2 3; do
  set +e
  nix build .#bunDeps --no-link >"$log" 2>&1
  status=$?
  set -e
  cat "$log"

  if [[ $status -eq 0 ]]; then
    echo "bunDeps hash is current"
    break
  fi

  # A changed bun.lock shows up as a fixed-output hash mismatch; Nix prints
  # the correct hash on the "got:" line. Anything else is a real build error.
  new_hash="$(sed -nE 's/.*got:[[:space:]]+(sha256-[A-Za-z0-9+\/=]+).*/\1/p' "$log" | head -n1)"
  if [[ -z "$new_hash" ]]; then
    echo "::error::bunDeps build failed for a reason other than a hash mismatch"
    exit "$status"
  fi

  echo "bunDeps hash mismatch (attempt ${attempt}); setting outputHash=${new_hash}"
  sed -i -E "s#(outputHash = \")sha256-[A-Za-z0-9+/=]+(\";)#\1${new_hash}\2#" package.nix
done
echo "::endgroup::"
