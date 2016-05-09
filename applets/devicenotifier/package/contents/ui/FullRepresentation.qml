/*
 *   Copyright 2011 Viranch Mehta <viranch.mehta@gmail.com>
 *   Copyright 2012 Jacopo De Simoi <wilderkde@gmail.com>
 *   Copyright 2014 David Edmundson <davidedmundson@kde.org>
 *   Copyright 2014 Marco Martin <mart@kde.org>
 *
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU Library General Public License as
 *   published by the Free Software Foundation; either version 2 or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details
 *
 *   You should have received a copy of the GNU Library General Public
 *   License along with this program; if not, write to the
 *   Free Software Foundation, Inc.,
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

import QtQuick 2.2
import QtQuick.Layouts 1.1

import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

Item {
    Layout.minimumWidth: units.gridUnit * 18
    Layout.minimumHeight: units.gridUnit * 22

    PlasmaExtras.Heading {
        width: parent.width
        level: 3
        opacity: 0.6
        text: i18n("No Devices Available")
        visible: notifierDialog.count === 0 && !devicenotifier.pendingDelegateRemoval
    }

    // this item is reparented to a delegate that is showing a message to draw focus to it
    PlasmaComponents.Highlight {
        id: messageHighlight
        visible: false

        OpacityAnimator {
            id: messageHighlightAnimator
            target: messageHighlight
            from: 1
            to: 0
            duration: 3000
            easing.type: Easing.InOutQuad
        }

        Connections {
            target: statusSource
            onLastChanged: {
                if (!statusSource.last) {
                    messageHighlightAnimator.stop()
                    messageHighlight.visible = false
                }
            }
        }

        function highlight(item) {
            parent = item
            width = Qt.binding(function() { return item.width })
            height = Qt.binding(function() { return item.height })
            opacity = 1 // Animator is threaded so the old opacity might be visible for a frame or two
            visible = true
            messageHighlightAnimator.start()
        }
    }

    Connections {
        target: plasmoid
        onExpandedChanged: {
            if (!plasmoid.expanded) {
                statusSource.clearMessage()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent

        PlasmaExtras.ScrollArea {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: notifierDialog
                focus: true
                boundsBehavior: Flickable.StopAtBounds

                model: filterModel

                delegate: deviceItem
                highlight: PlasmaComponents.Highlight { }
                highlightMoveDuration: 0
                highlightResizeDuration: 0
                spacing: units.smallSpacing

                currentIndex: devicenotifier.currentIndex

                //this is needed to make SectionScroller actually work
                //acceptable since one doesn't have a billion of devices
                cacheBuffer: 1000

                onCountChanged: {
                    if (count == 0) {
                        passiveTimer.restart()
                    } else {
                        passiveTimer.stop()
                        plasmoid.status = PlasmaCore.Types.ActiveStatus
                    }
                }

                section {
                    property: "Type Description"
                    delegate: Item {
                        height: childrenRect.height
                        width: notifierDialog.width
                        PlasmaExtras.Heading {
                            level: 3
                            opacity: 0.6
                            text: section
                        }
                    }
                }
            }
        }
    }

    Component {
        id: deviceItem

        DeviceItem {
            width: notifierDialog.width
            udi: DataEngineSource
            icon: sdSource.data[udi].Icon
            deviceName: sdSource.data[udi].Description
            emblemIcon: Emblems[0]
            state: sdSource.data[udi].State

            percentUsage: {
                if (!sdSource.data[udi]) {
                    return 0
                }
                var freeSpace = new Number(sdSource.data[udi]["Free Space"]);
                var size = new Number(sdSource.data[udi]["Size"]);
                var used = size-freeSpace;
                return used*100/size;
            }
            freeSpaceText: sdSource.data[udi] && sdSource.data[udi]["Free Space Text"] ? sdSource.data[udi]["Free Space Text"] : ""

            actionIcon: mounted ? "media-eject" : "media-mount"
            actionVisible: model["Device Types"].indexOf("Portable Media Player") == -1
            actionToolTip: {
                if (!mounted) {
                    return i18n("Click to access this device from other applications.")
                } else if (model["Device Types"].indexOf("OpticalDisc") != -1) {
                    return i18n("Click to eject this disc.")
                } else {
                    return i18n("Click to safely remove this device.")
                }
            }
            mounted: devicenotifier.isMounted(udi)

            onActionTriggered: {
                var operationName = mounted ? "unmount" : "mount";
                var service = sdSource.serviceForSource(udi);
                var operation = service.operationDescription(operationName);
                service.startOperationCall(operation);
            }
            property int operationResult: (model["Operation result"])

            onOperationResultChanged: {
                if (operationResult == 1) {
                    devicenotifier.popupIcon = "dialog-ok"
                    popupIconTimer.restart()
                } else if (operationResult == 2) {
                    devicenotifier.popupIcon = "dialog-error"
                    popupIconTimer.restart()
                }
            }
            Behavior on height { NumberAnimation { duration: units.shortDuration * 3 } }
        }
    }
}
