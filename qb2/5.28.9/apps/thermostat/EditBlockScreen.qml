import QtQuick 2.1
import qb.components 1.0
import BasicUIControls 1.0;

/// Edit day screen for thermostat program. Shows blocks of the programs for selected day. Allows to add / remove program block;

Screen {
	id: editBlockScreen

	screenTitle: qsTr("%1 block %2").arg(p.blockAction).arg(i18n.daysFull[p.daySelected])
	isSaveCancelDialog: true

	property int selectedState: 0

	QtObject {
		id: p;
		property int daySelected: 0
		property int blockToEditIdx
		property int editedBlockEndHour: 0
		property int editedBlockEndMin: 0
		property int minTime
		property int minHour
		property int minMinute
		property int maxTime
		property int maxHour
		property int maxMinute
		property bool initInProgress : false
		property string warningTextTemplate : qsTr("There must be at least 30 minutes of difference with the %1 period. With this setting, the period from %2:%3 (%4) is shifted to %5.")
		property string warningText
		property string blockAction : qsTr('Add')

		/**
		 * 'Shortcut' to access block from the day program.
		 * dayDelta: change againt p.daySelected
		 * blockDelta: change against p.blockToEditIdx
		 */
		function getBlock(dayDelta, blockDelta) {
			return app.thermostatProgramEdited[p.daySelected + dayDelta][p.blockToEditIdx + blockDelta];
		}

		function twoDigitsNumber(toConvert) {
			return (toConvert > 9) ? toConvert : "0" + toConvert;
		}

		/**
		 *  Calculates new start time for previous shifted block.
		 *  returns: new start time of shifted block in string format
		 */
		function shiftPrevProgramTime() {
			var shiftedTime = nsHour.value * 60 + nsMinute.value - 30;
			return Math.floor(shiftedTime / 60) + ":" + twoDigitsNumber(shiftedTime % 60);
		}

		/**
		 *  Calculates new start time for next shifted block.
		 *  returns: new start time of shifted block in string format
		 */
		function shiftNextProgramTime() {
			var shiftedTime = nsHour.value * 60 + nsMinute.value + 30;
			editedBlockEndHour = Math.floor(shiftedTime / 60);
			editedBlockEndMin = shiftedTime % 60;
			return editedBlockEndHour + ":" + twoDigitsNumber(editedBlockEndMin);
		}

		/**
		 *  Function executed if time is changed with spinners. Check if previous or following block needs to be shifted after current block edit. If shift
		 *  needs to be done display warning.
		 *
		 *  TODO: Because of problems with number spinners few dirty hacks are implemented.
		 *        # If time set by spinners doesn't match constraints for minimum/maximum time (this can happen while pressing and holding +/- buttons),
		 *          time is changed to fit the constraints.
		 *        # Flag initInProgress is true only during initial setup. This will enable to set initial time to the spinner. Minimum/maximum is not
		 *          checked during init.
		 *
		 */

		function timeChanged() {
			var actTimeSet = nsHour.value * 60 + nsMinute.value;
			if(!initInProgress) {
				if (actTimeSet < minTime) {
					actTimeSet = minTime;
					nsHour.value = minHour;
					nsMinute.value = minMinute;
				}
				if (actTimeSet > maxTime) {
					actTimeSet = maxTime;
					nsHour.value = maxHour;
					nsMinute.value = maxMinute;
				}
			}
			nsHour.enabledDownButton = true;
			nsHour.enabledUpButton = true;
			warning.visible = false;
			infoMessage.visible = true;
			// check if previous blocks need to be shifted
			if ((actTimeSet < (getBlock(0, -1).startHour * 60) + getBlock(0, -1).startMin + 30) && (p.blockToEditIdx > 1))  {
				warningText = warningTextTemplate.arg(qsTr('preceding')).arg(getBlock(0, -1).startHour).arg(twoDigitsNumber(getBlock(0, -1).startMin)).
				arg(app.thermStateName[getBlock(0,-1).targetState]).arg(shiftPrevProgramTime());
				infoMessage.visible = false;
				warning.visible = true;
			}
			// check if next blocks need to be shifted
			var maxEndTime;

			var block = getBlock(0,1);
			if (!(block === null || block === undefined)) {
				// maximum time when no shifting of following blocks is needed
				maxEndTime = (getBlock(0, 1).startHour * 60) + getBlock(0, 1).startMin - 30
			}
			if(actTimeSet > maxEndTime)  {
				if (!(block === null || block === undefined)) {
					warningText = warningTextTemplate.arg(qsTr('following')).arg(getBlock(0, 1).startHour).arg(twoDigitsNumber(getBlock(0, 1).startMin)).
					arg(app.thermStateName[getBlock(0,1).targetState]).arg(shiftNextProgramTime());
					warning.visible = true;
				}
			}
			else {
				var nextBlock = getBlock(0,1);
				if (nextBlock === null || nextBlock === undefined) {
					editedBlockEndHour = 24;
					editedBlockEndMin = 0;
				} else {
					editedBlockEndHour = nextBlock.startHour;
					editedBlockEndMin = nextBlock.startMin;
				}
			}
			if (actTimeSet - 60 < p.minTime) nsHour.enabledDownButton = false;
			if (actTimeSet + 60 > p.maxTime) nsHour.enabledUpButton = false;

			// Set the upper-limit of the minute spinner to the maximum minute value
			// for the highest possible hour of the current block
			if (nsHour.value === p.maxHour) {
				nsMinute.wrapAtMaximum = false;
				nsMinute.disableButtonAtMaximum = true;
				nsMinute.rangeMax = p.maxMinute;
			} else {
				nsMinute.wrapAtMaximum = true;
				nsMinute.disableButtonAtMaximum = false;
				nsMinute.rangeMax = 50;
			}

			// Set the lower-limit of the minute spinner to the minimum minute value
			// for the lowest possible hour of the current block
			if (nsHour.value === p.minHour) {
				nsMinute.wrapAtMinimum = false;
				nsMinute.disableButtonAtMinimum = true;
				nsMinute.rangeMin = p.minMinute;
			} else {
				nsMinute.wrapAtMinimum = true;
				nsMinute.disableButtonAtMinimum = false;
				nsMinute.rangeMin = 0;
			}
		}

		/**
		 * Change value of hour spinner on minute spinner wrap only if change will not brake min/max constraints.
		 */
		function nsHourChangeValue(delta) {
			var actTimeSet = nsHour.value * 60 + nsMinute.value;
			if (delta > 0 && actTimeSet + 10 <= p.maxTime) {
				nsHour.incrementValue();
			}
			else if (delta < 0 && actTimeSet - 10 >= p.minTime) {
				nsHour.decrementValue();
			}

		}
	}

	/**
	 *  Initial setup of the screen when new block should be edited. Sets current spinners value, minimum and maximum time of the block allowed.
	 */
	function editBlockInit(day, blockToEditIdx, blockAction) {
		p.initInProgress = true;
		p.daySelected = day;
		p.blockToEditIdx = blockToEditIdx;
		p.blockAction = blockAction;
		if (app.thermostatProgramEdited[day].length === blockToEditIdx + 1) {
			p.editedBlockEndHour = 24;
			p.editedBlockEndMin = 0;
		}
		else {
			p.editedBlockEndHour = p.getBlock(0,1).startHour;
			p.editedBlockEndMin = p.getBlock(0,1).startMin;
		}
		selectedState = p.getBlock(0,0).targetState;
		tempTileAway.state = tempTileComfort.state = tempTileHome.state = tempTileSleep.state = 'unselected';


		switch (selectedState) {
		case 0: tempTileComfort.state = 'selected'; break;
		case 1: tempTileHome.state = 'selected'; break;
		case 2: tempTileSleep.state = 'selected'; break;
		case 3: tempTileAway.state = 'selected'; break;
		}
		nsHour.value = p.getBlock(0,0).startHour;
		nsMinute.value = p.getBlock(0,0).startMin;
		p.minTime = (p.blockToEditIdx - 1) * 30;
		p.minHour = Math.floor(p.minTime / 60);
		p.minMinute = Math.floor(p.minTime % 60);
		p.maxTime = 24 * 60 - ((app.thermostatProgramEdited[p.daySelected].length - p.blockToEditIdx) * 30);
		p.maxHour = Math.floor(p.maxTime / 60);
		p.maxMinute = Math.floor(p.maxTime % 60);
		nsHour.rangeMin = p.minHour;
		nsHour.rangeMax = p.maxHour;
		p.timeChanged();
		p.initInProgress = false;
	}

	onShown: {
		screenStateController.screenColorDimmedIsReachable = false;
		if (args && args.day >= 0 && args.blockIdx >= 0 && args.blockAction)
			editBlockInit(args.day, args.blockIdx, args.blockAction);
	}

	onHidden: {
		screenStateController.screenColorDimmedIsReachable = true;
	}

	onSaved: {
		app.editDayScreen.blockEdited(nsHour.value, nsMinute.value, p.editedBlockEndHour, p.editedBlockEndMin, selectedState);
	}

	onCanceled: {
		app.editDayScreen.blockEditCancel();
	}

	Text {
		id: txtFrom
		text: qsTr("Put at")
		anchors {
			baseline: parent.top;
			baselineOffset: 104
			left: parent.left
			leftMargin: Math.round(84 * horizontalScaling)
		}
		color: colors.tpInfoLabel
		font {
			family: qfont.semiBold.name
			pixelSize: qfont.navigationTitle
		}
	}

	NumberSpinner {
		id: nsHour
		anchors {
			left: parent.left
			leftMargin: Math.round(84 * horizontalScaling)
			top: parent.top
			topMargin: Math.round(112 * verticalScaling)
		}
		rangeMin: 0
		rangeMax: 23
		increment: 1
		value: 0

		property string kpiPrefix: "qml/apps/thermostat/EditBlockScreen.hour."

		function valueToText(value) { return value < 10 ? "0" + value : value; }

		onValueChanged: p.timeChanged();
	}

	NumberSpinner {
		id: nsMinute
		anchors {
			left: nsHour.right
			leftMargin: Math.round(34 * horizontalScaling)
			top: parent.top
			topMargin: Math.round(112 * verticalScaling)
		}
		rangeMin: 0
		rangeMax: 50
		increment: 10
		value: 0
		wrapAtMaximum: true
		wrapAtMinimum: true

		property string kpiPrefix: "qml/apps/thermostat/EditBlockScreen.minute."

		function valueToText(value) { return value < 10 ? "0" + value : value; }

		onMinimumWrapped: p.nsHourChangeValue(-1);
		onMaximumWrapped: p.nsHourChangeValue(1);
		onValueChanged: p.timeChanged();
	}

	Text {
		id: colon
		anchors {
			left: nsHour.right
			right: nsMinute.left
			verticalCenter: nsHour.verticalCenter
		}
		horizontalAlignment: Text.AlignHCenter
		text: ":"

		font.family: qfont.regular.name
		font.pixelSize: qfont.spinnerText
		color: colors.numberSpinnerNumber
	}

	ControlGroup {
		id: thermStateGroup
		exclusive: true
	}

	Text {
		id: txtThermostatState
		text: qsTr("The thermostat to")
		anchors {
			baseline: parent.top;
			baselineOffset: 104
			left: nsMinute.right
			leftMargin: Math.round(63 * horizontalScaling)
		}
		color: colors.tpInfoLabel
		font {
			family: qfont.semiBold.name
			pixelSize: qfont.navigationTitle
		}
	}

	TemperatureRectangle {
		id: tempTileAway
		anchors {
			top: nsMinute.top
			left: txtThermostatState.left
		}

		topLeftRadiusRatio: 1

		subLabelText: app.thermStateName[app.thermStateAway]
		temperature: app.thermStates.thermStateAway.temperature
		stateId: app.thermStates.thermStateAway.index
		controlGroup: thermStateGroup
		onPressed: {
			tempTileAway.state = 'unselected';
			tempTileComfort.state = 'unselected';
			tempTileSleep.state = 'unselected';
			tempTileHome.state = 'unselected';
			selectedState = 3;
			state='selected' }
	}

	TemperatureRectangle {
		id: tempTileHome
		anchors.top: tempTileAway.top
		anchors.left: tempTileAway.right
		anchors.leftMargin: Math.round(4 * horizontalScaling)

		topRightRadiusRatio: 1

		subLabelText: app.thermStateName[app.thermStateActive]
		temperature: app.thermStates.thermStateActive.temperature
		stateId: app.thermStates.thermStateActive.index
		controlGroup: thermStateGroup

		onPressed: {
			tempTileAway.state = 'unselected';
			tempTileComfort.state = 'unselected';
			tempTileSleep.state = 'unselected';
			tempTileHome.state = 'unselected';
			selectedState = 1;
			state='selected' }

	}

	TemperatureRectangle {
		id: tempTileSleep
		anchors.top: tempTileAway.bottom
		anchors.topMargin: Math.round(4 * verticalScaling)
		anchors.left: txtThermostatState.left

		bottomLeftRadiusRatio: 1

		subLabelText: app.thermStateName[app.thermStateSleep]
		temperature: app.thermStates.thermStateSleep.temperature
		stateId: app.thermStates.thermStateSleep.index
		controlGroup: thermStateGroup
		onPressed: {
			tempTileAway.state = 'unselected';
			tempTileComfort.state = 'unselected';
			tempTileSleep.state = 'unselected';
			tempTileHome.state = 'unselected';
			selectedState = 2;
			state='selected' }

	}

	TemperatureRectangle {
		id: tempTileComfort
		anchors.top: tempTileHome.bottom
		anchors.topMargin: Math.round(4 * verticalScaling)
		anchors.left: tempTileSleep.right
		anchors.leftMargin: Math.round(4 * horizontalScaling)

		bottomRightRadiusRatio: 1

		subLabelText: app.thermStateName[app.thermStateRelax]
		temperature: app.thermStates.thermStateRelax.temperature
		stateId: app.thermStates.thermStateRelax.index
		controlGroup: thermStateGroup
		onPressed: {
			tempTileAway.state = 'unselected';
			tempTileComfort.state = 'unselected';
			tempTileSleep.state = 'unselected';
			tempTileHome.state = 'unselected';
			selectedState = 0;
			state='selected' }

	}

	Rectangle {
		id: infoMessage
		height: Math.round(65 * verticalScaling)
		radius: designElements.radius
		color: colors.contentBackground

		anchors {
			top: tempTileComfort.bottom
			topMargin: Math.round(37 * verticalScaling)
			left: nsHour.left
			right: tempTileComfort.right
		}

		IconButton {
			id: infoButton
			anchors {
				right: parent.right
				rightMargin: Math.round(20 * horizontalScaling)
				verticalCenter: parent.verticalCenter
			}
			iconSource: "qrc:/images/info.svg"
			onClicked: {
				ProgramTips.show(true);
			}
		}

		Text {
			id: infoText
			anchors {
				left: parent.left
				right: infoButton.left
				rightMargin: Math.round(8 * horizontalScaling)
				leftMargin: Math.round(20 * horizontalScaling)
				verticalCenter: infoButton.verticalCenter
			}
			font {
				pixelSize: qfont.bodyText
				family: qfont.italic.name
			}
			color: colors.foreground
			wrapMode: Text.WordWrap
			text: qsTr("$(display) will start heating in advance, so your house will be at the right temperature at the set time. Press i for more information and tips.")
		}
	}

	WarningBox {
		id: warning
		height: Math.round(80 * verticalScaling)
		visible: false;
		warningText: p.warningText
		anchors {
			top: tempTileComfort.bottom
			topMargin: Math.round(20 * verticalScaling)
			left: nsHour.left
			right: tempTileComfort.right
		}
	}
}
