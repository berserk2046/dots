import QtQuick
import qs.shared

// Pop-up menus for Dropdown, drawn over the whole window. A click outside or Esc closes it.
Item {
    id: menuLayer

    property Item anchor: null
    property var options: []
    property int current: -1
    property var picked: null

    anchors.fill: parent
    visible: anchor !== null
    z: 1000

    function show(anchorItem, items, currentIndex, callback) {
        options = items;
        current = currentIndex;
        picked = callback;
        anchor = anchorItem;
        const p = anchorItem.mapToItem(menuLayer, 0, 0);
        menu.width = Math.max(anchorItem.width, 180);
        const height = Math.min(items.length * 24 + 10, 340);
        menu.height = height;
        menu.x = Math.max(8, Math.min(menuLayer.width - menu.width - 8, p.x));
        // Below the button, or above it when there's no room.
        menu.y = p.y + anchorItem.height + height + 8 < menuLayer.height ? p.y + anchorItem.height + 4
                                                                       : Math.max(8, p.y - height - 4);
        list.positionViewAtIndex(Math.max(0, currentIndex), ListView.Center);
        forceActiveFocus();
    }

    function close() {
        anchor = null;
    }

    Keys.onEscapePressed: close()

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: menuLayer.close()
    }

    Rectangle {
        id: menu

        radius: 8
        color: Theme.solidCard
        border.width: 1
        border.color: Theme.border

        MouseArea {
            anchors.fill: parent
        }

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: 5
            clip: true
            model: menuLayer.options
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: entry

                required property var modelData
                required property int index

                width: ListView.view.width
                height: 24
                radius: 5
                color: entryMouse.containsMouse ? Theme.accent : "transparent"

                Glyph {
                    x: 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entry.index === menuLayer.current
                    text: Theme.iCheck
                    size: 12
                }

                Text {
                    x: 22
                    width: parent.width - 28
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: Ui.labelOf(entry.modelData)
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                MouseArea {
                    id: entryMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        const callback = menuLayer.picked;
                        const value = Ui.valueOf(entry.modelData);
                        menuLayer.close();
                        callback?.(value);
                    }
                }
            }
        }
    }
}
