// NEXUS Metro KSplash — Plasma splash screen.
// The desktop-side echo of the IGNITION boot animation: the relay ring
// breathes around the NEXUS logo while the session loads.
import QtQuick 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#070B18"

    Image {
        anchors.fill: parent
        source: "images/nexus-logo.png"
        fillMode: Image.PreserveAspectFit
        opacity: 0.0
        SequentialAnimation on opacity {
            loops: 1
            NumberAnimation { from: 0.0; to: 1.0; duration: 900 }
        }
    }

    // relay ring — two counter-rotating arcs
    Item {
        id: relay
        anchors.centerIn: parent
        width: 560; height: 560
        Rectangle {
            id: arcA
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: "#35E0FF"
            border.width: 4
            SequentialAnimation on rotation {
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 360; duration: 4200 }
            }
            // arc gap: a mask rectangle bites into the ring
            Rectangle { anchors.fill: parent; color: "transparent" }
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.62; height: parent.height * 0.62
            radius: width / 2
            color: "transparent"
            border.color: "#1A6078"
            border.width: 3
            SequentialAnimation on rotation {
                loops: Animation.Infinite
                NumberAnimation { from: 360; to: 0; duration: 6400 }
            }
        }
    }

    // breathing glow behind the logo
    Rectangle {
        anchors.centerIn: parent
        width: 260; height: 260
        radius: width / 2
        color: "transparent"
        border.color: "#35E0FF"
        border.width: 2
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { from: 0.15; to: 0.65; duration: 1400 }
            NumberAnimation { from: 0.65; to: 0.15; duration: 1400 }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: relay.bottom
        anchors.topMargin: 36
        text: "ONE CONSOLE. EVERY OS."
        color: "#35E0FF"
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 6
        font.pixelSize: 20
        opacity: 0.9
    }
}
