{
  lib,
  stdenv,
  rustPlatform,
  cargo-tauri,
  bun,
  nodejs,
  pkg-config,
  perl,
  python3,
  gobject-introspection,
  wrapGAppsHook3,
  copyDesktopItems,
  makeDesktopItem,
  webkitgtk_4_1,
  gtk3,
  libayatana-appindicator,
  librsvg,
  glib,
  glib-networking,
  gst_all_1,
  openssl,
  deadworks,
}:

let
  pname = "deadworks-launcher";
  version = "0.6.2";

  # Bun's lockfile is text based and has no Nix fetcher, so install the
  # frontend dependencies once in a fixed-output derivation and reuse the
  # resulting node_modules in the real build.
  bunDeps = stdenv.mkDerivation {
    name = "${pname}-bun-deps-${version}";
    src = deadworks;

    nativeBuildInputs = [ bun ];

    outputHashMode = "recursive";
    outputHash = "sha256-ba2OInpnXZsaRmDa/VaisYqNKxNCnKQqha4D7PIMqr8=";

    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      bun install --frozen-lockfile
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      cp -a node_modules "$out/node_modules"
      runHook postInstall
    '';
  };

  desktopItem = makeDesktopItem {
    name = "deadworks";
    desktopName = "Deadworks";
    genericName = "Deadworks Launcher";
    comment = "Launcher for the Deadworks game server";
    exec = "deadworks";
    icon = "deadworks";
    categories = [
      "Game"
      "Utility"
    ];
    startupWMClass = "Deadworks";
    terminal = false;
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  inherit pname version;

  src = deadworks;

  # The Rust crate lives in src-tauri/, so point the vendoring machinery at
  # its lockfile explicitly.
  cargoRoot = "src-tauri";
  cargoLock.lockFile = "${deadworks}/src-tauri/Cargo.lock";

  nativeBuildInputs = [
    cargo-tauri.hook
    bun
    nodejs
    pkg-config
    perl
    python3
    gobject-introspection
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    webkitgtk_4_1
    gtk3
    libayatana-appindicator
    librsvg
    openssl
    glib
    glib-networking
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
  ];

  # Tauri's `beforeBuildCommand` still runs in the frontend root (it walks up
  # to find package.json), while cargo builds from src-tauri/.
  buildAndTestSubdir = "src-tauri";

  # We make the AppImage ourselves; skip Tauri's (broken on Nix) linuxdeploy
  # bundler, including its .deb/.AppImage/updater artifact steps.
  tauriBuildFlags = [
    "--no-bundle"
    # The pinned CLI/NPM/Rust versions are all Tauri 2 but can differ in patch
    # version; that check is aimed at local dev, not hermetic builds.
    "--ignore-version-mismatches"
  ];

  env = {
    TAURI_SKIP_DEVSERVER_CHECK = "true";
  };

  doCheck = false;

  postPatch = ''
    cp -a ${bunDeps}/node_modules ./node_modules
    # The .bin shims use `#!/usr/bin/env node`, which does not exist in the
    # Nix sandbox. Rewrite them to the store paths of our interpreters.
    patchShebangs node_modules
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      # appindicator is loaded with dlopen(), so it needs an explicit path.
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator glib-networking ]}"
      --set-default WEBKIT_DISABLE_COMPOSITING_MODE 1
    )
  '';

  desktopItems = [ desktopItem ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cp "target/${stdenv.hostPlatform.rust.cargoShortTarget}/release/deadworks-launcher" \
      "$out/bin/deadworks"

    for spec in 32x32:32x32 128x128:128x128 128x128@2x:256x256; do
      src="''${spec%%:*}"
      target="''${spec##*:}"
      mkdir -p "$out/share/icons/hicolor/$target/apps"
      cp "src-tauri/icons/''${src}.png" "$out/share/icons/hicolor/$target/apps/deadworks.png"
    done

    runHook postInstall
  '';

  passthru = {
    inherit bunDeps;
  };

  meta = {
    description = "Deadworks game server launcher (Tauri)";
    homepage = "https://github.com/Deadworks-net/deadworks";
    license = lib.licenses.gpl3Only;
    mainProgram = "deadworks";
    platforms = lib.platforms.linux;
  };
})
