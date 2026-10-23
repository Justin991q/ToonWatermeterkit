import QtQuick 2.1
import qb.components 1.0

// the running tap of the Toon's own water tile, its stream following the flow
Tile {
	id: watermeterKitNowTile

	property int waterLevel: {
		var f = app.flow;
		if (f <= 0) return 0;
		if (f < 3.5) return 1;
		if (f < 7) return 2;
		if (f < 10.5) return 3;
		if (f < 15) return 4;
		return 5;
	}
	property int currentFrame: 0
	property int numFrames: waterLevel === 2 ? 5 : 6

	onWaterLevelChanged: {
		currentFrame = 0;
		animationTimer.running = waterLevel > 0;
	}

	onClicked: stage.openFullscreen(app.screenUrl)

	Text {
		color: dimmableColors.tileTitleColor
		text: "Water nu"
		anchors {
			baseline: parent.top
			baselineOffset: Math.round(30 * verticalScaling)
			horizontalCenter: parent.horizontalCenter
		}
		font.pixelSize: qfont.tileTitle
		font.family: qfont.regular.name
	}

	Image {
		anchors.centerIn: parent
		source: "image://scaled/apps/graph/drawables/waterTapTile-l" + waterLevel + "-f" + (currentFrame + 1) + (dimState ? "-dim" : "") + ".svg"
	}

	Text {
		color: dimmableColors.tileTextColor
		anchors {
			horizontalCenter: parent.horizontalCenter
			baseline: parent.bottom
			baselineOffset: designElements.vMarginNeg16
		}
		font.pixelSize: qfont.tileText
		font.family: qfont.regular.name
		text: app.connected ? i18n.number(app.flow, 1, i18n.omit_trail_zeros) + " " + qsTr("liter(s)/min.", "", app.flow) : "-"
	}

	Timer {
		id: animationTimer
		interval: 200
		repeat: true
		running: false
		onTriggered: currentFrame = (currentFrame + 1) % numFrames
	}
}
