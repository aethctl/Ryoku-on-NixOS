pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The placement bar's deep drawer: every visualiser knob that is not worth a
// slot on the bar itself, one square scrollable sheet you tune while the look
// plays behind it. It exists so aiming a look and dialling it in happen in the
// same place, on the desktop, instead of half here and half in a Hub window.
//
// The bar keeps what you steer by eye (look, colour, bands, edges, size); this
// keeps the rest. Reads come off the active instance (Config.instance, already
// normalised) except the three globals (enabled, fps, adaptive); writes go
// through Config so the active-vs-extra routing stays single-sourced. Rows that
// only mean something for one look family dim rather than vanish, so the sheet
// never reflows as the catalogue is walked. The host (EditBar) positions and
// scales this the way it does the tray and the picker.
Rectangle {
    id: popup

    property bool open: false
    // Asks the host to open its colour picker on an aura triad stop: the picker
    // lives in EditBar, so reusing it keeps one colour surface for the whole bar.
    signal editColor(string target)

    // The active look, for the dim gates. The when-sets are copied verbatim from
    // the Hub's Desktop schema so the two surfaces gate identically.
    readonly property string sid: Config.styleId
    readonly property bool aura: Config.isAura
    readonly property bool shapeSet: ["bars", "split", "dots", "segments", "frame", "radial", "spiral"].indexOf(popup.sid) >= 0
    readonly property bool growSet: ["bars", "split", "dots", "segments", "wave", "ribbon", "curtain", "line"].indexOf(popup.sid) >= 0
    readonly property bool polarSet: ["radial", "orb", "spiral"].indexOf(popup.sid) >= 0
    readonly property bool bloomSet: ["bars", "split", "dots", "segments", "wave", "ribbon", "curtain", "line", "frame", "radial", "orb", "spiral"].indexOf(popup.sid) >= 0
    readonly property bool segSet: popup.sid === "segments"
    readonly property bool reflSet: popup.growSet && Config.instance.grow === "up"

    width: 360
    height: 420
    radius: Tokens.radius
    color: Qt.alpha(Tokens.paper, 0.94)
    border.width: Tokens.border
    border.color: Tokens.line
    visible: opacity > 0.01
    opacity: popup.open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }

    // a shield: a click that misses a control must not start a placement drag on
    // the surface behind the sheet.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.margins: Tokens.s4
        clip: true
        contentWidth: width
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds

        WheelScroll {}

        Column {
            id: content
            width: flick.width
            spacing: Tokens.s2

            Text {
                text: I18n.tr("Everything the bar doesn't show.")
                color: Tokens.inkFaint
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall
                bottomPadding: Tokens.s2
            }

            // ── PLAYBACK ──────────────────────────────────────────────────
            Head { text: I18n.tr("PLAYBACK") }
            SwRow {
                label: "Enabled"
                val: Config.enabled
                write: (v) => Config.setEnabled(v)
            }
            SwRow {
                label: "Idle wave"
                val: Config.instance.idleWave
                write: (v) => Config.poke("idleWave", v)
            }
            Stack {
                label: "Frame rate"
                Seg {
                    options: ["30", "45", "60"]
                    current: "" + Config.fps
                    onChose: (k) => Config.setFps(parseInt(k))
                }
                Value {
                    visible: Config.activeGovTier > 0
                    text: I18n.tr("capped") + " " + (Config.activeGovTier === 1 ? 30 : 24)
                    color: Tokens.inkFaint
                    font.pixelSize: Tokens.fTiny
                }
            }
            SwRow {
                label: "Adaptive quality"
                val: Config.adaptive
                write: (v) => Config.setAdaptive(v)
            }

            // ── SHAPE ─────────────────────────────────────────────────────
            Head { text: I18n.tr("SHAPE") }
            SegStack {
                label: "Shape"
                dim: !popup.shapeSet
                opts: ["rounded", "flat"]
                val: Config.instance.shape
                write: (k) => Config.poke("shape", k)
            }
            StepRow {
                label: "Segments"
                dim: !popup.segSet
                lo: 3
                hi: 24
                val: Config.instance.segments
                write: (v) => Config.poke("segments", v)
            }
            SlidRow {
                label: "Bar width"
                dim: !popup.shapeSet
                lo: 0.2
                hi: 1
                val: Config.instance.thickness
                write: (v) => Config.poke("thickness", v)
            }
            SegStack {
                label: "Grows"
                dim: !popup.growSet
                opts: ["up", "down", "center", "left", "right"]
                val: Config.instance.grow
                write: (k) => Config.poke("grow", k)
            }
            SlidRow {
                label: "Rotation"
                dim: !popup.polarSet
                fmt: "int"
                lo: 0
                hi: 30
                val: Config.instance.spin
                write: (v) => Config.poke("spin", v)
            }
            SlidRow {
                label: "Reflection"
                dim: !popup.reflSet
                lo: 0
                hi: 0.3
                val: Config.instance.reflection
                write: (v) => Config.poke("reflection", v)
            }
            SlidRow {
                label: "Bloom"
                dim: !popup.bloomSet
                lo: 0
                hi: 1
                val: Config.instance.bloom
                write: (v) => Config.poke("bloom", v)
            }

            // ── FIELD (the edge field / aura look) ────────────────────────
            Head { text: I18n.tr("FIELD") }
            SegStack {
                label: "Movement"
                dim: !popup.aura
                opts: ["flow", "ribbon", "cells", "filament"]
                val: Config.instance.auraShape
                write: (k) => Config.poke("auraShape", k)
            }
            SegStack {
                label: "Effect"
                dim: !popup.aura
                opts: ["clean", "shimmer", "echo", "prism", "bloom", "caustic", "afterglow"]
                val: Config.instance.auraEffect
                write: (k) => Config.poke("auraEffect", k)
            }
            SlidRow {
                label: "Effect strength"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraEffectStrength
                write: (v) => Config.poke("auraEffectStrength", v)
            }
            SegStack {
                label: "Colour mode"
                dim: !popup.aura
                opts: ["flow", "spectrum", "pulse", "static"]
                val: Config.instance.auraColorMode
                write: (k) => Config.poke("auraColorMode", k)
            }
            SlidRow {
                label: "Colour drift"
                dim: !popup.aura
                fmt: "num"
                lo: 0
                hi: 1
                val: Config.instance.auraColorSpeed
                write: (v) => Config.poke("auraColorSpeed", v)
            }
            SegStack {
                label: "Corners"
                dim: !popup.aura
                opts: ["auto", "separate"]
                val: Config.instance.auraJoin
                write: (k) => Config.poke("auraJoin", k)
            }
            SegStack {
                label: "Flow"
                dim: !popup.aura
                opts: ["clockwise", "counterclockwise"]
                val: Config.instance.auraFlow
                write: (k) => Config.poke("auraFlow", k)
            }
            SlidRow {
                label: "Span"
                dim: !popup.aura
                lo: 0.2
                hi: 1
                val: Config.instance.auraSpan
                write: (v) => Config.poke("auraSpan", v)
            }
            SlidRow {
                label: "Taper"
                dim: !popup.aura
                lo: 0
                hi: 0.5
                val: Config.instance.auraTaper
                write: (v) => Config.poke("auraTaper", v)
            }
            StepRow {
                label: "Corner radius"
                dim: !popup.aura
                unit: "px"
                lo: 0
                hi: 64
                val: Config.instance.auraCornerRadius
                write: (v) => Config.poke("auraCornerRadius", v)
            }
            SlidRow {
                label: "Corner blend"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraCornerBlend
                write: (v) => Config.poke("auraCornerBlend", v)
            }
            SegStack {
                label: "Frequency profile"
                dim: !popup.aura
                opts: ["flat", "bass", "warm", "vocal", "treble", "smile"]
                val: Config.instance.auraProfile
                write: (k) => Config.poke("auraProfile", k)
            }
            SlidRow {
                label: "Profile accent"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraAccent
                write: (v) => Config.poke("auraAccent", v)
            }
            // The triad's second and third stops open the bar's own picker, so
            // one colour surface serves the whole editor.
            Row2 {
                label: "Field colours 2 / 3"
                dim: !popup.aura
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: Tokens.radius
                    color: Config.instance.auraColor2
                    border.width: Tokens.border
                    border.color: Tokens.lineStrong
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: popup.editColor("aura2") }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: Tokens.radius
                    color: Config.instance.auraColor3
                    border.width: Tokens.border
                    border.color: Tokens.lineStrong
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: popup.editColor("aura3") }
                }
            }
            SlidRow {
                label: "Field opacity"
                dim: !popup.aura
                lo: 0.2
                hi: 1
                val: Config.instance.auraOpacity
                write: (v) => Config.poke("auraOpacity", v)
            }
            SlidRow {
                label: "Body opacity"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraBodyOpacity
                write: (v) => Config.poke("auraBodyOpacity", v)
            }
            SlidRow {
                label: "Crest strength"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraCrestStrength
                write: (v) => Config.poke("auraCrestStrength", v)
            }
            SlidRow {
                label: "Glow"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraGlow
                write: (v) => Config.poke("auraGlow", v)
            }
            SlidRow {
                label: "Glow spread"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraGlowSpread
                write: (v) => Config.poke("auraGlowSpread", v)
            }
            SlidRow {
                label: "Audio range"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraAudioRange
                write: (v) => Config.poke("auraAudioRange", v)
            }
            SlidRow {
                label: "Body width"
                dim: !popup.aura
                lo: 0.05
                hi: 0.6
                val: Config.instance.auraThickness
                write: (v) => Config.poke("auraThickness", v)
            }
            SlidRow {
                label: "Detail"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraDetail
                write: (v) => Config.poke("auraDetail", v)
            }
            SlidRow {
                label: "Bass drive"
                dim: !popup.aura
                lo: 0
                hi: 1.5
                val: Config.instance.auraBassDrive
                write: (v) => Config.poke("auraBassDrive", v)
            }
            SlidRow {
                label: "Treble drive"
                dim: !popup.aura
                lo: 0
                hi: 1.5
                val: Config.instance.auraTrebleDrive
                write: (v) => Config.poke("auraTrebleDrive", v)
            }
            SlidRow {
                label: "Transient kick"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraTransient
                write: (v) => Config.poke("auraTransient", v)
            }
            SlidRow {
                label: "Beat glow"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraBeatGlow
                write: (v) => Config.poke("auraBeatGlow", v)
            }
            SlidRow {
                label: "Compression"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraCompression
                write: (v) => Config.poke("auraCompression", v)
            }
            SlidRow {
                label: "Field sensitivity"
                dim: !popup.aura
                lo: 0
                hi: 2
                val: Config.instance.auraSensitivity
                write: (v) => Config.poke("auraSensitivity", v)
            }
            SlidRow {
                label: "Motion speed"
                dim: !popup.aura
                fmt: "num"
                lo: 0
                hi: 3
                val: Config.instance.auraMotionSpeed
                write: (v) => Config.poke("auraMotionSpeed", v)
            }
            SlidRow {
                label: "Idle drift"
                dim: !popup.aura
                lo: 0
                hi: 1
                val: Config.instance.auraIdleMotion
                write: (v) => Config.poke("auraIdleMotion", v)
            }
            // Attack and release are one idea (how fast the field rises and falls),
            // so they share a row the way the bar's LEAN pairs its two tilts.
            Row2 {
                label: "Attack / Release"
                dim: !popup.aura
                Slid {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    value: Config.instance.auraAttack
                    from: 0.2
                    to: 3
                    onModified: (v) => Config.poke("auraAttack", v)
                }
                Slid {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    value: Config.instance.auraRelease
                    from: 0.2
                    to: 3
                    onModified: (v) => Config.poke("auraRelease", v)
                }
                Value {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 60
                    horizontalAlignment: Text.AlignRight
                    text: Config.instance.auraAttack.toFixed(1) + " " + Config.instance.auraRelease.toFixed(1)
                }
            }
        }
    }

    // ── building blocks ───────────────────────────────────────────────────
    // A section eyebrow in the bar's mono-label idiom.
    component Head: Text {
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: Tokens.fTiny
        font.letterSpacing: Tokens.trackMark
        font.weight: Font.Medium
        topPadding: Tokens.s3
    }
    // A mono readout, matching the bar's Value.
    component Value: Text {
        color: Tokens.ink
        font.family: Tokens.mono
        font.pixelSize: Tokens.fRow
    }
    // One settings line: the name on the left, its control(s) on the right. Its
    // children land in a right-anchored Row, so a control centres itself there
    // (a Row centres vertically; only a Column would forbid it).
    component Row2: Item {
        id: r2
        property string label: ""
        property bool dim: false
        default property alias content: holder.data
        width: parent ? parent.width : 0
        height: 34
        opacity: dim ? 0.3 : 1
        enabled: !dim
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
        Text {
            anchors { left: parent.left; right: holder.left; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
            text: I18n.tr(r2.label)
            elide: Text.ElideRight
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fRow
        }
        Row {
            id: holder
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Tokens.s2
        }
    }
    // A stacked line: the name above a full-width control, so a segmented picker
    // can wrap instead of being clipped. Children stack under the label.
    component Stack: Column {
        id: st
        property string label: ""
        property bool dim: false
        width: parent ? parent.width : 0
        spacing: 6
        opacity: dim ? 0.3 : 1
        enabled: !dim
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
        Text {
            text: I18n.tr(st.label)
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fTiny
            font.letterSpacing: Tokens.trackMark
            font.weight: Font.Medium
        }
    }
    // A switch row.
    component SwRow: Row2 {
        id: swr
        property bool val: false
        property var write: null
        Sw {
            anchors.verticalCenter: parent.verticalCenter
            on: swr.val
            onToggled: (v) => { if (swr.write) swr.write(v); }
        }
    }
    // A slider row with a numeric readout: percent by default, else a plain
    // number or a rounded integer with an optional unit.
    component SlidRow: Row2 {
        id: sr
        property real val: 0
        property real lo: 0
        property real hi: 1
        property string fmt: "pct"
        property string unit: ""
        property var write: null
        Slid {
            anchors.verticalCenter: parent.verticalCenter
            width: 110
            value: sr.val
            from: sr.lo
            to: sr.hi
            onModified: (v) => { if (sr.write) sr.write(v); }
        }
        Value {
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            horizontalAlignment: Text.AlignRight
            text: sr.fmt === "pct" ? Math.round(sr.val * 100) + "%"
                : (sr.fmt === "int" ? Math.round(sr.val) + sr.unit
                   : sr.val.toFixed(2) + sr.unit)
        }
    }
    // A stepper row with a numeric readout.
    component StepRow: Row2 {
        id: str
        property int val: 0
        property int lo: 0
        property int hi: 100
        property string unit: ""
        property var write: null
        Step {
            anchors.verticalCenter: parent.verticalCenter
            value: str.val
            from: str.lo
            to: str.hi
            onModified: (v) => { if (str.write) str.write(v); }
        }
        Value {
            anchors.verticalCenter: parent.verticalCenter
            width: 48
            horizontalAlignment: Text.AlignRight
            text: str.val + str.unit
        }
    }
    // A segmented-picker row, stacked so the group can wrap full-width.
    component SegStack: Stack {
        id: ss
        property var opts: []
        property string val: ""
        property var write: null
        Seg {
            options: ss.opts
            current: ss.val
            onChose: (k) => { if (ss.write) ss.write(k); }
        }
    }
}
