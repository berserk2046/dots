pragma Singleton
import QtQuick
import Quickshell

// Colors, fonts and glyphs, same as waybar-widgets/Theme.qml plus a few lock screen glyphs.
Singleton {
    readonly property color panel: "#000000"
    readonly property color border: "#26ffffff"
    readonly property color separator: "#1fffffff"
    readonly property color hover: "#1affffff"
    readonly property color pressed: "#2bffffff"
    readonly property color text: "#ffffff"
    readonly property color textSecondary: "#99ffffff"
    readonly property color textTertiary: "#59ffffff"
    readonly property color accent: "#0a84ff"
    readonly property color circle: "#33ffffff"
    readonly property color track: "#2effffff"
    readonly property color fill: "#ebffffff"
    readonly property color danger: "#ff6961"
    readonly property color success: "#30d158"
    readonly property color field: "#14ffffff"
    // Solid colors for the Notification Center and banners (no transparency)
    readonly property color solidCard: "#1c1c1e"
    readonly property color solidCardHover: "#2c2c2e"
    readonly property color solidBorder: "#2c2c2e"
    readonly property color solidCircle: "#3a3a3c"

    readonly property string font: "SF Pro"
    readonly property string iconFont: "FiraCode Nerd Font"

    readonly property int panelWidth: 320
    readonly property int radius: 14
    readonly property int rowHeight: 38

    // Material Design glyphs from the Nerd Font.
    readonly property string iVolumeHigh: String.fromCodePoint(0xF057E)
    readonly property string iVolumeMedium: String.fromCodePoint(0xF0580)
    readonly property string iVolumeLow: String.fromCodePoint(0xF057F)
    readonly property string iVolumeMute: String.fromCodePoint(0xF075F)
    readonly property string iSpeaker: String.fromCodePoint(0xF04C3)
    readonly property string iSpeakerBluetooth: String.fromCodePoint(0xF09A2)
    readonly property string iHeadphones: String.fromCodePoint(0xF02CB)
    readonly property string iHeadset: String.fromCodePoint(0xF02CE)
    readonly property string iMic: String.fromCodePoint(0xF036C)
    readonly property string iMicOff: String.fromCodePoint(0xF036D)
    readonly property string iMonitor: String.fromCodePoint(0xF0379)
    readonly property string iBluetooth: String.fromCodePoint(0xF00AF)
    readonly property string iEthernet: String.fromCodePoint(0xF0200)
    readonly property string iLanOff: String.fromCodePoint(0xF0319)
    readonly property string iLock: String.fromCodePoint(0xF033E)
    readonly property string iPlay: String.fromCodePoint(0xF040A)
    readonly property string iPause: String.fromCodePoint(0xF03E4)
    readonly property string iNext: String.fromCodePoint(0xF04AD)
    readonly property string iPrevious: String.fromCodePoint(0xF04AE)
    readonly property string iCheck: String.fromCodePoint(0xF012C)
    readonly property string iChevronLeft: String.fromCodePoint(0xF0141)
    readonly property string iChevronRight: String.fromCodePoint(0xF0142)
    readonly property string iChevronDown: String.fromCodePoint(0xF0140)
    readonly property string iRefresh: String.fromCodePoint(0xF0450)
    readonly property string iEye: String.fromCodePoint(0xF0208)
    readonly property string iEyeOff: String.fromCodePoint(0xF0209)
    readonly property string iInfo: String.fromCodePoint(0xF02FD)
    readonly property string iMusic: String.fromCodePoint(0xF0387)
    readonly property string iApp: String.fromCodePoint(0xF08C6)
    readonly property string iWifiOff: String.fromCodePoint(0xF05AA)
    readonly property string iSleep: String.fromCodePoint(0xF0904)
    readonly property string iRestart: String.fromCodePoint(0xF0709)
    readonly property string iPower: String.fromCodePoint(0xF0425)
    readonly property string iLogout: String.fromCodePoint(0xF0343)
    readonly property string iCapsLock: String.fromCodePoint(0xF0632)
    readonly property string iArrowRight: String.fromCodePoint(0xF0054)
    readonly property string iCalendar: String.fromCodePoint(0xF00ED)
    readonly property string iClose: String.fromCodePoint(0xF0156)
    readonly property string iBell: String.fromCodePoint(0xF009A)
    readonly property string iMoon: String.fromCodePoint(0xF0594)
}
