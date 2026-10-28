//
// WatermeterKit - water usage from a SmartHomeShop WaterMeterKit or WaterP1MeterKit via ESPHome's
// web_server REST API. Modelled on toonWater by Oepi-Loepi.
//
// The kits' sensors (github.com/smarthomeshop/watermeterkit and .../waterp1meterkit, base.yaml):
//                      WaterP1MeterKit          WaterMeterKit (friendly_name "WaterMeterKit" in front)
//   meter reading m3   "Water Meter Total"      "WaterMeterKit Water Meter Total"
//   flow L/min         "Water Current Usage"    "WaterMeterKit Current Usage"
//   leak               "Water Leak Sensor"      -                                  (binary_sensor, V3+)
//

import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0
import FileIO 1.0

App {
	id: watermeterKitApp

	property bool debugOutput: false

	property url tileUrl: "WatermeterKitTile.qml"
	property url nowTileUrl: "WatermeterKitNowTile.qml"
	property url todayTileUrl: "WatermeterKitTodayTile.qml"
	property url thumbnailIcon: "qrc://apps/graph/drawables/waterTapTile-thumb.svg"

	property WatermeterKitScreen watermeterKitScreen
	property url screenUrl: "WatermeterKitScreen.qml"
	property WatermeterKitSettingsScreen watermeterKitSettingsScreen
	property url settingsScreenUrl: "WatermeterKitSettingsScreen.qml"

	// settings
	property string host: ""                 // IP address or name of the kit, optionally with :port
	property int pollSeconds: 10

	// readings
	property real flow: 0                    // L/min
	property int totalLitres: 0              // meter reading in litres
	property int todayLitres: 0
	property int dayAvgLitres: 0             // average of the last days, 0 = not known yet
	property variant lastDays: []            // litres per day, oldest first, at most 7
	property bool leakSensorPresent: false
	property bool leak: false
	property real waterPrice: 0              // EUR per m3 as set in this app, 0 = none
	property real toonWaterTariff: 0         // EUR per m3 from the Toon's billing info (as toonWater sets it), 0 = none
	property real waterTariff: waterPrice > 0 ? waterPrice : toonWaterTariff

	// state
	property bool connected: false
	property string lastError: ""
	property string lastUpdate: ""
	property bool haveReading: false
	property string kitType: ""              // "WaterMeterKit" or "WaterP1MeterKit", from the names it answers to
	property variant entityPaths: ({})       // entity -> the path that answered, e.g. "sensor/Water%20Meter%20Total"

	property string dayDate: ""              // the day dayStartLitres belongs to, yyyy-MM-dd
	property int dayStartLitres: -1

	signal waterUpdated()

	// per entity the names to try, WaterP1MeterKit first; "kit" says which kit a name belongs to
	property variant entities: ({
		total: {domain: "sensor", names: [{name: "Water Meter Total", kit: ""}, {name: "WaterMeterKit Water Meter Total", kit: "WaterMeterKit"}]},
		flow: {domain: "sensor", names: [{name: "Water Current Usage", kit: "WaterP1MeterKit"}, {name: "WaterMeterKit Current Usage", kit: "WaterMeterKit"}, {name: "Current Usage", kit: "WaterMeterKit"}]},
		leak: {domain: "binary_sensor", names: [{name: "Water Leak Sensor", kit: "WaterP1MeterKit"}]}
	})

	FileIO {id: settingsFile; source: "file:///mnt/data/tsc/watermeterKit.userSettings.json"}
	FileIO {id: dayFile; source: "file:///mnt/data/tsc/appData/watermeterKit.days.json"}
	FileIO {id: oldSettingsFile; source: "file:///mnt/data/tsc/esphomeWater.userSettings.json"}   // before the rename
	FileIO {id: oldDayFile; source: "file:///mnt/data/tsc/appData/esphomeWater.days.json"}
	FileIO {id: pwrusageFile; source: "file:///mnt/data/qmf/config/config_happ_pwrusage.xml"}

	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("WatermeterKit"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("tile", nowTileUrl, this, null, {thumbLabel: qsTr("Water nu"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("tile", todayTileUrl, this, null, {thumbLabel: qsTr("Water vandaag"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", screenUrl, this, "watermeterKitScreen");
		registry.registerWidget("screen", settingsScreenUrl, this, "watermeterKitSettingsScreen");
	}

	Component.onCompleted: {
		var settings = readJson(settingsFile) || readJson(oldSettingsFile);
		if (settings) {
			if (settings.host) host = settings.host;
			if (settings.pollSeconds >= 2) pollSeconds = settings.pollSeconds;
			if (settings.entityPaths) entityPaths = settings.entityPaths;
			if (settings.kitType) kitType = settings.kitType;
			if (settings.waterPrice > 0) waterPrice = settings.waterPrice;
		}
		var days = readJson(dayFile) || readJson(oldDayFile);
		if (days) {
			dayDate = days.date;
			dayStartLitres = days.startLitres;
			lastDays = days.lastDays || [];
		}
		calculateAverage();
		getTariff();
		pollTimer.running = true;
		rrdTimer.running = true;
	}

	function readJson(file) {
		try {
			var text = file.read();
			return text ? JSON.parse(text) : null;
		} catch (e) {
			return null;
		}
	}

	function log(text) {
		if (debugOutput) console.log("watermeterKit: " + text);
	}

	function cleanHost(text) {
		return text.replace(/^https?:\/\//, "").replace(/\/+$/, "");
	}

	function saveSettings(newHost, newPrice) {
		if (newPrice !== undefined) waterPrice = newPrice;
		host = cleanHost(newHost);
		entityPaths = {};
		kitType = "";
		writeSettings();
		connected = false;
		haveReading = false;
		lastError = "";
		pollTimer.restart();
	}

	function writeSettings() {
		settingsFile.write(JSON.stringify({host: host, pollSeconds: pollSeconds, entityPaths: entityPaths, kitType: kitType, waterPrice: waterPrice}));
	}

	function getTariff() {
		// the water price as the Toon's own settings have it (Instellingen > Tarieven), as toonWater does
		var xml = "";
		try { xml = pwrusageFile.read(); } catch (e) { return; }
		var parts = xml.split("<billingInfo>");
		for (var i = 1; i < parts.length; i++) {
			var info = parts[i].split("</billingInfo>")[0];
			if (info.indexOf("<type>water</type>") > -1) {
				var m = info.match(/<price>([0-9.]+)<\/price>/);
				if (m) toonWaterTariff = parseFloat(m[1]);
			}
		}
	}

	///////////////////////////////////////////// ESPHome REST API /////////////////////////////////////////////

	// the paths to try for an entity: per name the ESPHome 2025.x URL (by name) and the older one (object id)
	function candidates(key) {
		var e = entities[key];
		var list = [];
		for (var i = 0; i < e.names.length; i++) {
			var n = e.names[i].name;
			list.push({path: e.domain + "/" + encodeURIComponent(n), kit: e.names[i].kit});
			list.push({path: e.domain + "/" + n.toLowerCase().replace(/[^a-z0-9]+/g, "_"), kit: e.names[i].kit});
		}
		return list;
	}

	// GET http://<onHost>/<path>: onDone(json) or onDone(null, error, status)
	function getPath(onHost, path, onDone) {
		var http = new XMLHttpRequest();
		http.open("GET", "http://" + onHost + "/" + path, true);
		http.onreadystatechange = function() {
			if (http.readyState !== XMLHttpRequest.DONE) return;
			if (http.status === 200) {
				try {
					onDone(JSON.parse(http.responseText));
				} catch (e) {
					onDone(null, "onverwacht antwoord", 200);
				}
			} else {
				onDone(null, http.status === 404 ? "niet gevonden (404)" : (http.status ? "HTTP " + http.status : "geen verbinding"), http.status);
			}
		}
		http.send();
	}

	// find the entity among the candidates: onDone(json, candidate) or onDone(null, error); stops at the
	// first answer that is not a 404 (no connection: no use trying the other names)
	function findEntity(onHost, key, onDone, index) {
		var list = candidates(key);
		if (!index) index = 0;
		if (index >= list.length) {
			onDone(null, "niet gevonden (404)");
			return;
		}
		getPath(onHost, list[index].path, function(json, error, status) {
			if (json) onDone(json, list[index]);
			else if (status === 404) findEntity(onHost, key, onDone, index + 1);
			else onDone(null, error);
		});
	}

	// an entity of the configured kit, by the path that answered before
	function getEntity(key, onDone) {
		var known = entityPaths[key];
		if (known) {
			getPath(host, known, function(json, error, status) {
				if (status === 404) {
					forget(key);
					getEntity(key, onDone);     // new firmware: look again
				} else {
					onDone(json, error);
				}
			});
			return;
		}
		findEntity(host, key, function(json, found) {
			if (!json) {
				onDone(null, found);
				return;
			}
			var paths = entityPaths;
			paths[key] = found.path;
			entityPaths = paths;
			if (found.kit) kitType = found.kit;
			log(key + " at " + found.path);
			writeSettings();
			onDone(json);
		});
	}

	function forget(key) {
		var paths = entityPaths;
		delete paths[key];
		entityPaths = paths;
	}

	function numberOf(json) {
		// {"id":"sensor-water_meter_total","value":1234.567,"state":"1234.567 m³"}; no value while unknown
		if (!json) return NaN;
		if (typeof json.value === "number") return json.value;
		return parseFloat(json.state);
	}

	function poll() {
		if (host === "") {
			connected = false;
			lastError = "geen adres ingesteld";
			waterUpdated();
			return;
		}
		getEntity("total", function(json, error) {
			var total = numberOf(json);
			if (isNaN(total)) {
				connected = false;
				lastError = "meterstand: " + (error || "nog geen waarde");
				log(lastError);
				waterUpdated();
				return;
			}
			getEntity("flow", function(json2) {
				var f = numberOf(json2);
				flow = isNaN(f) ? 0 : f;        // the pulse meter has no value until the first pulse
				if (leakSensorPresent || !haveReading) {
					getEntity("leak", function(json3) {
						leakSensorPresent = json3 !== null;
						leak = leakSensorPresent && json3.value === true;
						newReading(total);
					});
				} else {
					newReading(total);
				}
			});
		});
	}

	function newReading(totalM3) {
		var litres = Math.round(totalM3 * 1000);
		var today = Qt.formatDate(new Date(), "yyyy-MM-dd");
		if (dayStartLitres < 0 || litres < dayStartLitres) {
			// first reading, or the meter reading was set lower in the kit's settings
			startDay(today, litres);
		} else if (today !== dayDate) {
			// a new day: what was used since the start of the previous one goes into the history
			var days = lastDays.slice(0);
			days.push(litres - dayStartLitres);
			while (days.length > 7) days.shift();
			lastDays = days;
			calculateAverage();
			startDay(today, litres);
		}
		totalLitres = litres;
		todayLitres = litres - dayStartLitres;
		newHourReading(litres);
		connected = true;
		haveReading = true;
		lastError = "";
		lastUpdate = Qt.formatTime(new Date(), "hh:mm:ss");
		waterUpdated();
	}

	function startDay(date, litres) {
		dayDate = date;
		dayStartLitres = litres;
		dayFile.write(JSON.stringify({date: dayDate, startLitres: dayStartLitres, lastDays: lastDays}));
	}

	function calculateAverage() {
		var sum = 0, count = 0;
		for (var i = 0; i < lastDays.length; i++) {
			if (lastDays[i] > 0) { sum += lastDays[i]; count++; }
		}
		dayAvgLitres = count > 0 ? Math.round(sum / count) : 0;
	}

	///////////////////////////////////////////// Toon logger (hcb_rrd) /////////////////////////////////////////////

	// The Toon's graph app shows hours from water_flow (5min) and days, weeks and months from the meter
	// readings in water_quantity, which has only the archive 10yrhours: a sample at hh:00 is the reading at
	// that moment. The Toon's meter driver keeps the coming hour's sample up to date itself, and without a
	// water meter of its own it writes "no value" there, over ours (toonWater: "the last hour is deleted
	// when the new hour is set"). So the reading taken when an hour starts goes into that hour's sample,
	// which the driver leaves alone, written again every 5 minutes.
	property int rrdLastLitres: -1
	property int hourSlot: 0                 // the hour (epoch s) hourSlotLitres belongs to
	property int hourSlotLitres: -1          // the reading at its start, -1 = not known
	property variant rrdErrors: ({})         // logger/rra -> already logged that the Toon refused it

	function newHourReading(litres) {
		var now = Math.floor(new Date().getTime() / 1000);
		var hour = now - now % 3600;
		if (hour === hourSlot) return;
		hourSlot = hour;
		// later than 10 minutes into the hour (the app or the Toon restarted) the reading is not the one
		// at the start of the hour: leave that hour's sample as it is
		hourSlotLitres = (now - hour <= 600) ? litres : -1;
		writeHourSample();
	}

	function writeHourSample() {
		if (hourSlotLitres >= 0) rrdSet("water_quantity", "10yrhours", hourSlot, hourSlotLitres);
	}

	function writeRrd() {
		// the flow per 5 minutes (as litres per hour), the reading at the start of this hour, and the
		// reading now for the coming hour (the Toon's own meters do that too), for the graphs while it lasts
		if (!haveReading) return;
		var now = new Date();
		if (rrdLastLitres >= 0) {
			var perHour = (totalLitres - rrdLastLitres) * 12;
			rrdSet("water_flow", "5min", Math.floor(now.getTime() / 1000), perHour);
		}
		rrdLastLitres = totalLitres;
		writeHourSample();
		rrdSet("water_quantity", "10yrhours", hourSlot + 3600, totalLitres);
	}

	function rrdSet(logger, rra, epoch, value) {
		var samples = encodeURIComponent("{\"" + epoch + "\":" + Math.round(value) + "}");
		var http = new XMLHttpRequest();
		http.open("GET", "http://localhost/hcb_rrd?action=setRrdData&loggerName=" + logger + "&rra=" + rra + "&samples=" + samples, true);
		http.onreadystatechange = function() {
			if (http.readyState !== XMLHttpRequest.DONE) return;
			// log once per archive when the Toon refuses a sample, with its answer
			var key = logger + "/" + rra;
			var refused = http.status !== 200 || http.responseText.indexOf("error") > -1;
			if (refused && !rrdErrors[key]) console.log("watermeterKit: hcb_rrd refused " + key + ": " + http.status + " " + http.responseText);
			var errors = rrdErrors;
			errors[key] = refused;
			rrdErrors = errors;
		}
		http.send();
	}

	Timer {
		id: pollTimer
		interval: pollSeconds * 1000
		repeat: true
		running: false
		triggeredOnStart: true
		onTriggered: poll()
	}

	Timer {
		id: rrdTimer
		interval: 300000
		repeat: true
		running: false
		onTriggered: writeRrd()
	}
}
