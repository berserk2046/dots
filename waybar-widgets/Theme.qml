pragma Singleton
import QtQuick
import Quickshell

// Colors, fonts and glyphs shared by the panels. Colors match sway-dock's menus.
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
    // Solid colors, as in the lock screen's Notification Center (System Settings uses them too)
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
    // System Settings
    readonly property string iWifi: String.fromCodePoint(0xF05A9)
    readonly property string iNetwork: String.fromCodePoint(0xF06F3)
    readonly property string iBell: String.fromCodePoint(0xF009A)
    readonly property string iMoon: String.fromCodePoint(0xF0594)
    readonly property string iFocus: String.fromCodePoint(0xF0F65)
    readonly property string iCog: String.fromCodePoint(0xF0493)
    readonly property string iPalette: String.fromCodePoint(0xF03D8)
    readonly property string iToggles: String.fromCodePoint(0xF0521)
    readonly property string iDock: String.fromCodePoint(0xF10A9)
    readonly property string iImage: String.fromCodePoint(0xF02E9)
    readonly property string iBattery: String.fromCodePoint(0xF0079)
    readonly property string iUsers: String.fromCodePoint(0xF0849)
    readonly property string iAccount: String.fromCodePoint(0xF0009)
    readonly property string iKeyboard: String.fromCodePoint(0xF030C)
    readonly property string iMouse: String.fromCodePoint(0xF037D)
    readonly property string iSearch: String.fromCodePoint(0xF0349)
    readonly property string iAbout: String.fromCodePoint(0xF02FC)
    readonly property string iDisk: String.fromCodePoint(0xF02CA)
    readonly property string iClock: String.fromCodePoint(0xF0150)
    readonly property string iList: String.fromCodePoint(0xF0279)
    readonly property string iPlus: String.fromCodePoint(0xF0415)
    readonly property string iMinus: String.fromCodePoint(0xF0374)
    readonly property string iDelete: String.fromCodePoint(0xF01B4)
    readonly property string iFolder: String.fromCodePoint(0xF024B)
    readonly property string iSun: String.fromCodePoint(0xF0599)
    readonly property string iBrightness: String.fromCodePoint(0xF00DF)
    readonly property string iCursor: String.fromCodePoint(0xF01BF)
    readonly property string iWeb: String.fromCodePoint(0xF059F)
    readonly property string iConsole: String.fromCodePoint(0xF018D)
    readonly property string iEmail: String.fromCodePoint(0xF01EE)
    readonly property string iPencil: String.fromCodePoint(0xF03EB)
    readonly property string iDesktop: String.fromCodePoint(0xF01C4)
    readonly property string iCorner: String.fromCodePoint(0xF0A9C)
    readonly property string iApps: String.fromCodePoint(0xF003B)
    readonly property string iClose: String.fromCodePoint(0xF0156)
    readonly property string iChevronUp: String.fromCodePoint(0xF0143)
    readonly property string iEarth: String.fromCodePoint(0xF01E7)
    readonly property string iArch: String.fromCodePoint(0xF303) // Arch Linux logo
}
