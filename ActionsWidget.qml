import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Opens a terminal menu for backup now, list, restore, and the timer.
// status.sh in the other plugin is the badge. This button does not poll.
BarWidget {
  id: root
  moduleName: "calledtoconstruct.backup-actions"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function scriptPath() {
    var url = Qt.resolvedUrl("menu.sh").toString()
    if (url.indexOf("file://") === 0)
      url = decodeURIComponent(url.substring(7))
    return url
  }

  function openMenu() {
    if (menuProc.running)
      return
    menuProc.command = ["omarchy-launch-terminal", scriptPath()]
    menuProc.running = true
  }

  function open() { openMenu() }
  function close() {}
  function toggle() { openMenu() }

  Process {
    id: menuProc
  }

  WidgetButton {
    id: button
    bar: root.bar
    text: "job"
    tooltipText: "Back up now, list archives, restore a file, or install the schedule"
    onPressed: root.openMenu()
  }
}
