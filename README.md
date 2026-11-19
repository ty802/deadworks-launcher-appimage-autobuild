# Deadworks launcher AppImage

A Nix flake that builds the [Deadworks launcher](https://github.com/Deadworks-net/deadworks/tree/main/launcher)
(Tauri 2 + React/Vite) into a single-file, portable **AppImage** instead of a
Nix-installed package.

## Usage

```sh
# Build the AppImage. `result` is the AppImage file itself, not a directory:
nix build
cp result ~/Downloads/Deadworks-0.6.2-x86_64-linux.AppImage   # optional
./result
```

Run it directly without installing:

```sh
nix run .#
```

Other outputs:

```sh
nix build .#deadworks   # the Nix-wrapped app (useful while developing)
nix build .#bunDeps     # just the prefetched frontend dependencies
nix develop             # shell with Rust, Bun, Tauri CLI and GTK/WebKit libs
```

## How it works

1. `bun install --frozen-lockfile` is run once in a fixed-output derivation,
   producing an offline `node_modules` tree (Bun's text lockfile has no native
   Nix fetcher).
2. Rust crates are vendored straight from `src-tauri/Cargo.lock`.
3. `cargo tauri build --no-bundle` compiles the frontend and the Rust backend
   with Nix-provided WebKitGTK/GTK libraries. Tauri's own Linux bundler is
   deliberately skipped: it relies on `linuxdeploy` downloading tools at build
   time and does not work hermetically inside a Nix build.
4. The resulting Nix package is converted into a type-2 AppImage with
   [`nix-appimage`](https://github.com/ralismark/nix-appimage). The AppImage
   contains the whole Nix closure, so it carries its own WebKitGTK and GTK
   libraries rather than depending on the host distribution.

Upstream has no flake of its own. The input URL uses `?dir=launcher` (Nix's
spelling of the `?path=launcher` subdirectory selector) together with
`flake = false`.

## Runtime caveats

The generated AppImage uses a user-namespace + chroot `AppRun`, so it needs
unprivileged user namespaces enabled on the host (the default on most modern
distributions). If FUSE is unavailable you can still extract and run it:

```sh
./result --appimage-extract-and-run
```

As with any Nix-closure-in-an-AppImage bundle, hardware OpenGL acceleration on
non-NixOS hosts may require `nixGL`; software rendering works out of the box.

## Updating

Change the `rev` of the `deadworks` input in `flake.nix` and run `nix flake
update`. If the frontend dependencies change, `nix build .#bunDeps` will report
the new hash to paste into `package.nix`. Rust dependencies come from
`Cargo.lock` and need no manual hash.

## Automated daily releases

`.github/workflows/upstream-release.yml` runs once a day and is also
dispatchable three ways: manually with **Run workflow**, through the REST API
(`repository_dispatch` with event type `upstream-release`), and as a reusable
workflow via `workflow_call`. A `force` input/input payload rebuilds even when
already up to date. It compares the pinned `rev` with the upstream
default-branch HEAD. When they differ — or when the release for that rev is
missing — it:

1. updates the rev, `flake.lock`, the version from upstream
   `launcher/src-tauri/tauri.conf.json`, and the `bunDeps` hash if `bun.lock`
   changed (via `scripts/update-upstream.sh`);
2. builds `nix build .#appimage` on `x86_64-linux`;
3. commits the refreshed pins back to the default branch;
4. publishes a GitHub release tagged `upstream-<short-sha>` with the AppImage
   attached.

The workflow needs `contents: write` (already declared) and must live on the
default branch for the daily schedule to fire. `aarch64-linux` is declared in
the flake but is not built by the workflow, since GitHub-hosted runners are
x86_64 only; use a self-hosted ARM runner to add it.
