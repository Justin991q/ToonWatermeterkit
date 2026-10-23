import QtQuick 2.1
import qb.components 1.0

Screen {
	id: watermeterKitScreen
	screenTitle: "WatermeterKit"

	property int labelWidth: isNxt ? 600 : 480

	onShown: addCustomTopRightButton("Instellingen")
	onCustomButtonClicked: stage.openFullscreen(app.settingsScreenUrl)

	function euro(litres) {
		return "€ " + i18n.number(litres / 1000 * app.waterTariff, 2)
	}

	function daysText() {
		var days = app.lastDays;
		if (days.length === 0) return "nog geen";
		var parts = [];
		for (var i = days.length - 1; i >= 0; i--) parts.push(days[i]);
		return parts.join("  ") + " l";
	}

	Column {
		anchors {
			top: parent.top
			topMargin: isNxt ? 30 : 24
			horizontalCenter: parent.horizontalCenter
		}
		spacing: designElements.vMargin6

		SingleLabel {
			width: labelWidth
			leftText: "Status"
			rightText: app.leak ? "LEKKAGE gedetecteerd!" : (app.connected ? "verbonden, " + app.lastUpdate : (app.lastError || "verbinden..."))
			rightTextColor: app.leak ? "red" : colors.singleLabelRightText
		}
		SingleLabel {
			width: labelWidth
			leftText: "Verbruik nu"
			rightText: i18n.number(app.flow, 1) + " l/min"
		}
		SingleLabel {
			width: labelWidth
			leftText: "Vandaag"
			rightText: app.todayLitres + " l" + (app.waterTariff > 0 ? "   (" + euro(app.todayLitres) + ")" : "")
		}
		SingleLabel {
			width: labelWidth
			leftText: "Gemiddeld per dag"
			rightText: app.dayAvgLitres > 0 ? app.dayAvgLitres + " l" : "nog niet bekend"
		}
		SingleLabel {
			width: labelWidth
			leftText: "Vorige dagen (nieuwste eerst)"
			rightText: daysText()
		}
		SingleLabel {
			width: labelWidth
			leftText: "Meterstand"
			rightText: i18n.number(app.totalLitres / 1000, 3) + " m³"
		}
		SingleLabel {
			width: labelWidth
			leftText: "Lekkagesensor"
			rightText: app.leakSensorPresent ? (app.leak ? "nat" : "droog") : "niet aanwezig"
		}
		SingleLabel {
			width: labelWidth
			leftText: "Apparaat"
			rightText: app.host ? (app.kitType ? app.kitType + " op " : "") + app.host : "niet ingesteld"
		}
	}
}
