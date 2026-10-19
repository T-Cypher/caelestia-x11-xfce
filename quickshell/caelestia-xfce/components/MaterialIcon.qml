import QtQuick
import qs.services

// Material Symbols ligature icon (e.g. text: "volume_up"), same approach
// as upstream's MaterialIcon. Needs a Material Symbols font installed
// (ttf-material-symbols-variable on Arch/AUR).
Text {
    property real fillGrade: 0

    font.family: Config.iconFontFamily
    font.pixelSize: 22
    // NOTE: opsz is a constant — referencing font.pixelSize here makes
    // the grouped `font` property depend on itself (binding loop).
    font.variableAxes: ({
            "FILL": fillGrade,
            "wght": 450,
            "GRAD": 0,
            "opsz": 24
        })
    color: Colours.m3onSurfaceVariant
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
