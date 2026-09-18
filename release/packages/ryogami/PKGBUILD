# Maintainer: Ryoku <releases@ryoku.dev>
#
# Ryogami: the Ryoku wallpaper daemon (Go). One process owns the wallpaper
# catalog (thumbnails, colours, favourites), applies through the in-shell
# surface topic, the matugen palette, and the depth surface, behind ryoku's
# line pub/sub on $XDG_RUNTIME_DIR/ryogami.sock. The vendored skwd-wall picker
# (wall-ui) is its front end.
#
# built from the in-repo Go module at ryoku/shell/ryogami/daemon, no tarball
# fetched. publish CI runs makepkg inside this dir against a full checkout, so
# the repo root is three levels up; go builds into $srcdir so the source tree
# stays untouched.
pkgname=ryogami
pkgver=${RYOKU_PKGVER:-0.2.0}
pkgrel=1
pkgdesc="Ryogami: the Ryoku wallpaper daemon (catalog, thumbnails, applies, depth)"
arch=('x86_64')
url="https://ryoku.dev"
license=('MIT')
# runtime tools the daemon shells out to: imagemagick + ffmpeg (thumbnails,
# colour extraction, the livewall transcode), matugen (palette on apply),
# quickshell (the wall-ui). Video wallpapers play through the bundled
# ryogami-live, built here from ryoku/shell/livewall. The wall-ui source
# browser fetches remote wallpapers (Wallhaven, MoeWalls, MotionBGs, GitHub,
# Steam) with curl, so it is a hard runtime need too. The wall-ui's wallpaper
# folder watcher execs inotifywait (inotify-tools); without it a wallpaper that
# lands while the picker is open (a store install, a download) never shows
# until the picker is reopened.
depends=('imagemagick' 'ffmpeg' 'quickshell' 'curl' 'inotify-tools')
makedepends=('go' 'wayland' 'wayland-protocols')
source=()

_repo="$startdir/../../.."

build() {
  cd "$_repo/ryoku/shell/ryogami/daemon"
  # -mod=vendor keeps the build off proxy.golang.org so it is reproducible and
  # works in the offline publish container (the module is stdlib-only, so there
  # is no vendor/ tree to carry). Matches every other [ryoku] Go package.
  CGO_ENABLED=0 go build -trimpath -mod=vendor -o "$srcdir/ryogami" .
  "$_repo/ryoku/shell/livewall/build.sh" "$srcdir/ryogami-live"
}

package() {
  install -Dm755 "$srcdir/ryogami" "$pkgdir/usr/bin/ryogami"
  install -Dm755 "$srcdir/ryogami-live" "$pkgdir/usr/bin/ryogami-live"
  # user unit: systemd finds it under /usr/lib/systemd/user without materialize,
  # exactly where ExecStart already points (/usr/bin/ryogami).
  install -Dm644 "$_repo/ryoku/shell/systemd/user/ryogami.service" \
    "$pkgdir/usr/lib/systemd/user/ryogami.service"
  # the wall-ui picker (vendored skwd-wall, MIT): the quickshell config the
  # daemon spawns; /usr/share/ryogami/shell.qml is the resolver's packaged
  # default, so no env override is needed on an installed box.
  install -d "$pkgdir/usr/share/ryogami"
  cp -a "$_repo/ryoku/shell/ryogami/wall-ui/." "$pkgdir/usr/share/ryogami/"
  install -Dm644 "$_repo/ryoku/shell/ryogami/wall-ui/data/ryogami-wall.desktop" \
    "$pkgdir/usr/share/applications/ryogami-wall.desktop"
  install -Dm644 "$_repo/ryoku/shell/ryogami/wall-ui/LICENSE" \
    "$pkgdir/usr/share/licenses/ryogami/LICENSE"
}
