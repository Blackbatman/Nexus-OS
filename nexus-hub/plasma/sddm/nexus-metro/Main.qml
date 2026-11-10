// NEXUS Metro SDDM greeter — Mass Effect x Cyberpunk hybrid lock-in.
// Deep-space wallpaper, relay logo, cyan glass login card, cyber-yellow
// focus ticks. Plain QtQuick + SddmComponents; no third-party deps.
import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1024
    height: 768
    color: "#070B18"

    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
    }

    // dim vignette so the card reads over the ring
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.25
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 360
        height: 320
        radius: 6
        color: "#0D1424"
        border.color: "#35E0FF"
        border.width: 1
        opacity: 0.94

        Column {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            Image {
                source: "logo.png"
                anchors.horizontalCenter: parent.horizontalCenter
                width: 150; height: 150
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "NEXUS"
                color: "#D7E6F2"
                font.letterSpacing: 8
                font.pixelSize: 22
                font.bold: true
            }

            TextBox {
                id: userName
                width: parent.width
                height: 34
                text: ""
                font.pixelSize: 14
                borderColor: "#1A6078"
                textColor: "#D7E6F2"
                focus: true
                KeyNavigation.tab: password
            }

            TextBox {
                id: password
                width: parent.width
                height: 34
                text: ""
                font.pixelSize: 14
                echoMode: TextInput.Password
                borderColor: "#1A6078"
                textColor: "#D7E6F2"
                KeyNavigation.backtab: userName
                Keys.onReturnPressed: sddm.login(userName.text, password.text, session.index)
                Keys.onEnterPressed: sddm.login(userName.text, password.text, session.index)
            }

            Row {
                spacing: 10
                anchors.horizontalCenter: parent.horizontalCenter

                Button {
                    id: loginBtn
                    text: textConstants.login
                    width: 150; height: 34
                    onClicked: sddm.login(userName.text, password.text, session.index)
                }

                Button {
                    id: session
                    text: sddm.sessionName
                    width: 150; height: 34
                    onClicked: sddm.toggleSessionButton()
                }
            }
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        text: "ONE CONSOLE. EVERY OS."
        color: "#35E0FF"
        font.letterSpacing: 5
        font.pixelSize: 14
        opacity: 0.85
    }

    Component.onCompleted: userName.forceActiveFocus()
}
