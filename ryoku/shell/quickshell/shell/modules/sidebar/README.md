# Sidebar module

- `Sidebar.qml` owns both screen-edge overlays, screen bounds, input regions,
  and outside-click dismissal.
- `SidebarFrame.qml` draws the shared rounded paper/ink boundary.
- `SidebarChrome.qml` draws the header, section navigation, content viewport,
  and the Customize in Hub entry point.
- Sidebar customization lives in
  `ryoku/hub/quickshell/pages/SidebarsPage.qml`; `SidebarWriter.qml` waits for
  the daemon reply and settings-frame confirmation before accepting a save.
- `SidebarButton.qml`, `SidebarToggle.qml`, and `SidebarSegments.qml` provide
  the sidebar's labelled interaction controls.
- `SidebarCatalog.js` registers the nine built-in sections.
- `SidebarCardHost.qml` loads built-ins and plugins and binds their runtime
  contract. Plugin `compact` and `viewportHeight` properties are optional.
- `SidebarCardShell.qml` is the built-in heading and content-layout scaffold;
  it does not paint an outer plate.
- `ryoku/shell/framebars/Sidebars.js` normalizes the persisted settings through
  the shared `Ryoku.FrameBars.Sidebars` module.
- `SidebarPlugins.qml` discovers installed `sidebarCard` plugins.
- `cards/` contains the built-in section implementations and supporting
  overlays.

To add a built-in section, create one component in `cards/`, place its visible
content in `SidebarCardShell`, declare the host properties and
`requestClose()` signal, and add one registry row to `SidebarCatalog.js`. Add
its id to `ryoku/shell/framebars/Sidebars.js` defaults only when it should ship selected.

Contributor plugins use the `sidebarCard` host documented in
[`docs/plugins.md`](../../../../../../docs/plugins.md#4-sidebar-card---lives-in-a-global-sidebar).
