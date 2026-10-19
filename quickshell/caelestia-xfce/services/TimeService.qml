pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Same role as upstream services/Time.qml.
Singleton {
    id: root

    property date now: new Date()

    function format(fmt) {
        return Qt.formatDateTime(root.now, fmt || Config.clockFormat);
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
