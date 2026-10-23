import QtQuick 2.1
import qb.components 1.0

Screen {
	id: watermeterKitSettingsScreen

	isSaveCancelDialog: true
	screenTitle: "WatermeterKit instellingen"

	property bool firstShown: true   // closing the keyboard shows the screen again: keep what was typed
	property string testResult: ""

	onShown: {
		if (firstShown) {
			hostLabel.rightText = app.host;
			priceLabel.rightText = app.waterPrice > 0 ? i18n.number(app.waterPrice, 4, i18n.omit_trail_zeros) : "";
			firstShown = false;
		}
	}

	onSaved: {
		app.saveSettings(hostLabel.rightText, parsePrice(priceLabel.rightText));
		firstShown = true;
	}

	// "1,05" or "1.05" EUR per m3; empty or not a number: no price of its own
	function parsePrice(text) {
		var value = parseFloat(text.replace(",", ".").replace(/[^0-9.]/g, ""));
		return (isNaN(value) || value < 0) ? 0 : value;
	}

	function savePrice(text) {
		var value = parsePrice(text);
		priceLabel.rightText = value > 0 ? i18n.number(value, 4, i18n.omit_trail_zeros) : "";
	}

	onCanceled: firstShown = true

	function saveHost(text) {
		if (text) hostLabel.rightText = text;
	}

	function test() {
		// the meter reading, then the flow sensor, whose name tells which kit it is
		testResult = "testen...";
		var testHost = app.cleanHost(hostLabel.rightText);
		app.findEntity(testHost, "total", function(json, error) {
			if (!json) {
				testResult = (error === "niet gevonden (404)") ? "Bereikbaar, maar geen meterstand-sensor van een WaterMeterKit gevonden" : "Geen verbinding (" + error + ")";
				return;
			}
			var state = json.state;
			app.findEntity(testHost, "flow", function(json2, found) {
				testResult = "OK: " + (json2 && found.kit ? found.kit : "kit") + ", meterstand " + state;
			});
		});
	}

	Text {
		id: introText
		width: isNxt ? 800 : 650
		wrapMode: Text.WordWrap
		anchors {
			top: parent.top
			topMargin: isNxt ? 30 : 24
			horizontalCenter: parent.horizontalCenter
		}
		font.family: qfont.regular.name
		font.pixelSize: isNxt ? 18 : 14
		color: colors.singleLabelLeftText
		text: "Het IP-adres (of de naam) van je WaterMeterKit of WaterP1MeterKit. De web server van ESPHome moet aan staan (poort 80, standaard in de firmware van SmartHomeShop). Een andere poort: 192.168.1.50:8080"
	}

	SingleLabel {
		id: hostLabel
		width: isNxt ? 700 : 560
		leftText: "Adres"
		anchors {
			top: introText.bottom
			topMargin: isNxt ? 20 : 16
			left: introText.left
		}
	}

	IconButton {
		id: editButton
		width: 45
		height: hostLabel.height
		iconSource: "qrc:/images/edit.svg"
		anchors {
			top: hostLabel.top
			left: hostLabel.right
			leftMargin: 10
		}
		onClicked: qkeyboard.open("Adres van de WaterMeterKit", hostLabel.rightText, saveHost)
	}

	StandardButton {
		id: testButton
		text: "Test verbinding"
		height: 40
		anchors {
			top: hostLabel.bottom
			topMargin: isNxt ? 20 : 16
			left: introText.left
		}
		onClicked: test()
	}

	Text {
		anchors {
			verticalCenter: testButton.verticalCenter
			left: testButton.right
			leftMargin: 16
			right: introText.right
		}
		elide: Text.ElideRight
		font.family: qfont.regular.name
		font.pixelSize: isNxt ? 18 : 14
		color: colors.singleLabelLeftText
		text: testResult
	}

	SingleLabel {
		id: priceLabel
		width: hostLabel.width
		leftText: "Waterprijs (€ per m³)"
		anchors {
			top: testButton.bottom
			topMargin: isNxt ? 30 : 24
			left: introText.left
		}
	}

	IconButton {
		width: 45
		height: priceLabel.height
		iconSource: "qrc:/images/edit.svg"
		anchors {
			top: priceLabel.top
			left: priceLabel.right
			leftMargin: 10
		}
		onClicked: qkeyboard.open("Waterprijs in euro per m³ (bijvoorbeeld 1,05)", priceLabel.rightText, savePrice)
	}

	Text {
		anchors {
			top: priceLabel.bottom
			topMargin: 8
			left: introText.left
			right: introText.right
		}
		wrapMode: Text.WordWrap
		font.family: qfont.regular.name
		font.pixelSize: isNxt ? 16 : 13
		color: colors.singleLabelLeftText
		text: "Voor het bedrag van vandaag. Leeg laten: de waterprijs van de Toon" + (app.toonWaterTariff > 0 ? " (€ " + i18n.number(app.toonWaterTariff, 4, i18n.omit_trail_zeros) + ")" : ", als die er is (bijvoorbeeld ingesteld met toonWater)") + "."
	}
}
