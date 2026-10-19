import QtQuick
import Quickshell
import qs.services

// A Caelestia "drawer" on X11.
//
// Upstream draws *every* drawer + the bar into one full-screen
// wlr-layer-shell surface with an input mask (modules/drawers). X11 has
// no layer shell, so each drawer gets its own dock-type PanelWindow
// (_NET_WM_WINDOW_TYPE_DOCK, no strut) floating just right of the bar.
// Consequences vs Wayland, by design:
//   * no click-outside-to-dismiss grab -> toggle key / Esc / bar button
//   * keyboard focus is requested, but xfwm4 decides; if the launcher
//     search field does not get focus on your setup, see README
//     ("Focus follows" troubleshooting — xdotool fallback wrapper).
PanelWindow {
    id: root

    required property string drawerName
    property int drawerWidth: 400
    default property alias content: card.data

    readonly property bool drawerOpen: ShellState.openDrawer === drawerName

    visible: drawerOpen
    color: "transparent"
    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1

    anchors.left: true
    anchors.top: true
    anchors.bottom: true
    margins.left: Config.barWidth + Config.drawerMargin
    margins.top: Config.drawerMargin
    margins.bottom: Config.drawerMargin
    implicitWidth: drawerWidth

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Config.rounding
        color: Colours.drawerBg
        border.width: 1
        border.color: Qt.alpha(Colours.outlineVariant, 0.6)

        // Fade in (the window itself pops, content animates).
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        Connections {
            target: root
            function onDrawerOpenChanged() {
                if (root.drawerOpen)
                    card.opacity = 1;
            }
        }

        Keys.onEscapePressed: ShellState.closeDrawers()
    }

    onVisibleChanged: {
        if (visible)
            card.forceActiveFocus();
    }
}
