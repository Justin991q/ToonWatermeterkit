import QtQuick 2.1
import qb.components 1.0

// today's usage as a bar against the daily average (the middle line), as the Toon's own day tiles
Tile {
	id: watermeterKitTodayTile

	// 0..2: 1 is the average; without an average yet the bar is scaled to 500 litres
	property real ratio: Math.min(2, app.todayLitres / (app.dayAvgLitres > 0 ? app.dayAvgLitres : 250))
	property int fullHeight: backgroundRect.height

	onClicked: stage.openFullscreen(app.screenUrl)

	Text {
		color: dimmableColors.tileTitleColor
		text: "Water vandaag"
		anchors {
			baseline: parent.top
			baselineOffset: Math.round(30 * verticalScaling)
			horizontalCenter: parent.horizontalCenter
		}
		font.pixelSize: qfont.tileTitle
		font.family: qfont.regular.name
	}

	Rectangle {
		id: backgroundRect
		width: Math.round(34 * horizontalScaling)
		height: Math.round(78 * verticalScaling)
		anchors.centerIn: parent
		radius: designElements.radius
		color: dimmableColors.dayTileBackgroundBar
		clip: true

		Rectangle {
			anchors {
				bottom: parent.bottom
				left: parent.left
				right: parent.right
			}
			height: Math.round(fullHeight * watermeterKitTodayTile.ratio / 2)
			radius: designElements.radius
			color: watermeterKitTodayTile.ratio > 1 ? dimmableColors.dayTileUsageBar : dimmableColors.dayTileAverageBar
		}
	}

	Rectangle {
		width: backgroundRect.width
		height: Math.round(2 * verticalScaling)
		anchors.centerIn: backgroundRect
		color: dimmableColors.dayTileMiddleBar
		visible: app.dayAvgLitres > 0
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
		text: app.haveReading ? app.todayLitres + " l" : "-"
	}
}
