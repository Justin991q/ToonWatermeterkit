import QtQuick 2.1
import qb.components 1.0

// flow, today and the meter reading, as toonWater's text tile
Tile {
	id: watermeterKitTile

	onClicked: stage.openFullscreen(app.screenUrl)

	Text {
		id: tileTitle
		anchors {
			baseline: parent.top
			baselineOffset: Math.round(30 * verticalScaling)
			horizontalCenter: parent.horizontalCenter
		}
		font {
			family: qfont.regular.name
			pixelSize: qfont.tileTitle
		}
		color: dimmableColors.tileTitleColor
		text: "Water"
	}

	Column {
		anchors {
			top: tileTitle.bottom
			topMargin: isNxt ? 8 : 6
			horizontalCenter: parent.horizontalCenter
		}
		spacing: 1
		visible: app.haveReading

		Text {
			anchors.horizontalCenter: parent.horizontalCenter
			text: "Nu: " + i18n.number(app.flow, 1) + " l/min"
			color: dimmableColors.tileTextColor
			font.pixelSize: isNxt ? 22 : 18
			font.family: qfont.bold.name
		}
		Text {
			anchors.horizontalCenter: parent.horizontalCenter
			text: "Vandaag: " + app.todayLitres + " l"
			color: dimmableColors.tileTextColor
			font.pixelSize: isNxt ? 22 : 18
			font.family: qfont.bold.name
		}
		Text {
			anchors.horizontalCenter: parent.horizontalCenter
			text: "Stand: " + i18n.number(app.totalLitres / 1000, 3) + " m³"
			color: dimmableColors.tileTextColor
			font.pixelSize: isNxt ? 22 : 18
			font.family: qfont.bold.name
		}
	}

	Text {
		id: statusText
		anchors {
			horizontalCenter: parent.horizontalCenter
			baseline: parent.bottom
			baselineOffset: designElements.vMarginNeg16
		}
		width: parent.width - 16
		horizontalAlignment: Text.AlignHCenter
		elide: Text.ElideRight
		font.pixelSize: isNxt ? 18 : 14
		font.family: qfont.bold.name
		color: app.leak ? "red" : dimmableColors.tileTextColor
		text: app.leak ? "LEKKAGE!" : (app.connected ? "" : (app.host === "" ? "Tik om in te stellen" : "Geen verbinding"))
	}
}
