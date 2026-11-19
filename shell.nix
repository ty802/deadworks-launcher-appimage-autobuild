{
  mkShell,
  deadworks,
  rustc,
  cargo,
  bun,
  cargo-tauri,
  nodejs,
  pkg-config,
  gobject-introspection,
  wrapGAppsHook3,
  webkitgtk_4_1,
  gtk3,
  libayatana-appindicator,
  librsvg,
  glib,
  glib-networking,
  gst_all_1,
  openssl,
}:

mkShell {
  name = "deadworks-launcher-dev";

  nativeBuildInputs = [
    rustc
    cargo
    cargo-tauri
    bun
    nodejs
    pkg-config
    gobject-introspection
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

  env = {
    TAURI_SKIP_DEVSERVER_CHECK = "true";
  };

  shellHook = ''
    echo "Deadworks launcher source: ${deadworks}"
    echo "Run: bun install && bun run tauri build -b appimage"
  '';
}
