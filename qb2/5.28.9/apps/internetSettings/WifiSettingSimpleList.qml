import QtQuick 2.1
import qb.components 1.0

/**
 * Component displaying up to fixed number of items scrollable by up/down buttons. Scrolling is page based and is always scrolled
 * to have the itemsPerPage-th item at the top of the visible items - might be empty lines at the last page when total count is not itemsPerPage multiple.
 * Using two data models. One model for all available items - dataModel, out of which only fixed number (itemsPerPage) of items
 * are displayed using a Repeater and using the second model - repeaterModel.
 * An item can by selected by two ways:
 *   1) by its index within the dataModel - the page is scrolled to the page containing the selected item
 *   2) by its index within the visible items (0 up to (itemsPerPage-1))
 * When the item is added to dataModel, the page is not scrolled and the visible index of the selected item remains the same, unless
 * there are less items in total than itemsPerPage, then a selected item is moved one lower to fill the first page with the new item.
 * When deleting currently selected item, the next item, if existing, is selected, otherwise the previous item is selected.
 * Since the data model is from outside, this component have to be notified upon adding/removing items in data model via corresponding
 * handlers itemAdded() and itemDeleted(dataIndex). The adding and deleting of items can be "discovered" in onCountChange handler, but to be able
 * to handle (update the view) deletion of not-selected items (or items ouf of the visible range), the data index of deleted item has to provided. The itemAdded()
 * handler is added for consistency (not needed).
 * Standard QML
*/

Item {
	id: simpleList

	/// delegate for Repeater displaying only items on one page
	property alias delegate: repeater.delegate
	/// data model for all items (not only the visible ones)
	property ListModel dataModel	/// Number of items per one page - maximum number of items in Repeater.
	property int itemsPerPage: 5
	/// number of items in dataModel
	property int count: dataModel.count
	/// Currently selected item in the Repeater.
	property Item currentItem
	/// Data model index of currently selected item (zero based) within all items (not only the visible ones)
	property int dataIndex: -1
	/// Height of the scroll buttons.
	property int buttonsHeight: height - (itemsPerPage * itemHeight) - 1
	/// Icon used for 'Down' button. Icon for 'Up' is created by rotating down icon rotated 180 degrees.
	property url downIcon
	/// Color of scroll buttons icon in down state.
	property color buttonDownStateColor
	/// Color of background of the buttons in down state.
	property color buttonDownStateBackground
	/// Height of single item in ListView (in px).
	property int itemHeight: 0
	/// Color of the scrollbar.
	property alias scrollbarColor: scrollbar.color
	/// visibility of navigation buttons and separators around buttons
	property bool buttonsVisible: true
	/// scrollbar visibility
	property alias scrollbarVisible: scrollbar.visible

	/// Signal emitted when list item is clicked
	signal itemClicked();

	QtObject {
		id: p

		/// data index fo the first visible item in Repeater
		property int firstVisibleDataIdx: -1

		///private properties for unit tests
		property ThreeStateButton prvButUp: butUp
		property ThreeStateButton prvButDown: butDown
		property Rectangle prvScrollbar: scrollbar

		/// converts index within visible items in Repeater into data index within all items. Derived from firstVisibleDataIdx
		function visibleIdxToDataIdx(visibleIdx) {
			return count > 0 ? (p.firstVisibleDataIdx + visibleIdx) : -1;
		}

		/// converts data index within all items in dataModel into index within visible items in Repeater . Derived from firstVisibleDataIdx
		function dataIdxToVisibleIdx(dataIdx) {
			return count > 0 ? (dataIdx - p.firstVisibleDataIdx) : -1;
		}

		/// calculates the page index (zero based) which contains given data index
		function getPageForDataIdx(dataIdx) {
			return count > 0 ? Math.floor(dataIdx / itemsPerPage) : -1;
		}

		/// calculates the data index of the first item on pageIdx page
		function getFirstVisibleDataIdxOnPage(pageIdx) {
			return count > 0 ? pageIdx * itemsPerPage : -1;
		}

		/// Enables or disables buttons reflecting current position in list.
		function updateButtons() {
			if (count <= 0) {
				butDown.enabled = butUp.enabled = false;
			} else {
				butDown.enabled = p.firstVisibleDataIdx < count - itemsPerPage;
				butUp.enabled = p.firstVisibleDataIdx > 0;
			}

			//had to do manual setting of visible property of buttons here because there is a problem with icon in ThreeStateButton when directly bound
			//to buttonsVisible that the icon is not visible in "up" state (the "disabled" state is fine).
			butDown.visible = butUp.visible = buttonsVisible;
		}

		/// adapt scrollbar height based on page count and set proper position
		function updateScrollbar() {
			if ( count <= itemsPerPage) {
				scrollbar.visible = false;
				return;
			} else {
				scrollbar.visible = true;
			}
			var pageCount = Math.ceil(count / itemsPerPage);
			scrollbar.height = Math.floor(markup.height / pageCount);
			var currentPage = p.getPageForDataIdx(p.firstVisibleDataIdx);

			//when there are more than itemsPerPage items, and a new item is added (the list is not scrolled down), move the bar down for a part of his height
			var offset = p.firstVisibleDataIdx - p.getFirstVisibleDataIdxOnPage(currentPage); //how much items are hidden from the actual page
			offset = offset * Math.floor(scrollbar.height / (itemsPerPage + 1)); //resulting topMargin offset

			//corrections of the bar position to keep visual consistency with the down button state. Adding a new item may result in having currently visible items on two pages
			if ((count - 1) - p.firstVisibleDataIdx < itemsPerPage) {
				//if the last item is visible, set the page to the last page, not to show the bar in the middle but butDown disabled
				currentPage = p.getPageForDataIdx(count - 1);
				offset = 0;
			} else if (currentPage === p.getPageForDataIdx(count - 1)) {
				//if the current first visible item belongs to the last page but there are still some NOT visible items in the end, don't set the page to the last page
				//not to show the bar in the end but the butDonw enabled
				currentPage = currentPage > 0 ? currentPage - 1 : 0;
			}

			var topMargin = (currentPage * scrollbar.height) + offset;
			//crop the topMargin not to overlap with buttons separator
			topMargin = (topMargin + scrollbar.height - 1) >= markup.height ? markup.height - scrollbar.height : topMargin;
			scrollbar.anchors.topMargin = topMargin;
		}

		//recreates visible items in Repeater with firstDataIdx data item as first visible item
		function refreshView(firstDataIdx) {
			repeaterModel.clear();

			if (count <= 0) {
				p.firstVisibleDataIdx = -1;
				return;
			}

			for (var i = firstDataIdx; i < firstDataIdx + itemsPerPage && i < dataModel.count; i++) {
				repeaterModel.append(dataModel.get(i));
			}
			p.firstVisibleDataIdx = firstDataIdx;
		}

		//recreates visible items in Repeater which are on the pageIdx page
		function refreshPage(pageIdx) {
			refreshView(getFirstVisibleDataIdxOnPage(pageIdx));
		}
	}

	/// handler of adding an item into data model. Has to be notified from data model owner - see component description
	function itemAdded() {
		if (count <= itemsPerPage) {
			p.firstVisibleDataIdx = 0;
			p.refreshView(p.firstVisibleDataIdx);
		} else {
			//item added above actual page. Leave actual page as it is, update data index of the first visible item only
			p.firstVisibleDataIdx++;
		}
		dataIndex++;
		selectItem(dataIndex);
	}

	/// set item with data index dataIdx as visible and emit a signal about it. Scroll the page if needed
	function selectItem(dataIdx) {
		dataIndex = dataIdx >= count ? count -1 : dataIdx;
		var selectedIndex = p.dataIdxToVisibleIdx(dataIndex);
		if (selectedIndex < 0 || selectedIndex >= itemsPerPage) {
			//scroll the pages so the actual page is the one containing dataIndex item
			p.refreshPage(p.getPageForDataIdx(dataIndex));
			selectedIndex = p.dataIdxToVisibleIdx(dataIndex);
		}
		currentItem = repeater.itemAt(selectedIndex);
		p.updateButtons();
		p.updateScrollbar();
		return selectedIndex;
	}

	/// helper function to be able to select the current item based on visible index. Used by Repeater delegate
	function selectVisibleItem(visibleIdx) {
		dataIndex = p.visibleIdxToDataIdx(visibleIdx);
		itemClicked(selectItem(dataIndex));
	}

	/// Scroll list to the top and highlight the first item.
	function initialView() {
		p.refreshView(0);
		p.firstVisibleDataIdx = count > 0 ? 0 : -1;
		selectItem(p.firstVisibleDataIdx);
		p.updateButtons();
		p.updateScrollbar();
	}

	function clearModel() {
		repeaterModel.clear();
	}

	/// scrolls the list one page further (if possible) and select the first item
	function goNextPage() {
		var currentPage = p.getPageForDataIdx(p.firstVisibleDataIdx);
		var lastPage = p.getPageForDataIdx(count-1);
		currentPage = currentPage >= lastPage ? lastPage : currentPage + 1;
		p.refreshPage(currentPage);
		selectItem(p.firstVisibleDataIdx);
	}

	/// scrolls the list one page back (if possible) and select the first item
	function goPrevPage() {
		var currentPage = p.getPageForDataIdx(p.firstVisibleDataIdx);
		currentPage = currentPage <= 0 ? 0 : currentPage - 1;
		p.refreshPage(currentPage);
		selectItem(p.firstVisibleDataIdx);
	}

	/// scrolls the list to specified page pageId, zero based, and select the first item
	function goToPage(pageIdx) {
		var currentPage = p.getPageForDataIdx(p.firstVisibleDataIdx);
		if (currentPage !== pageIdx) {
			var lastPage = p.getPageForDataIdx(count - 1);
			if (pageIdx >= 0 && pageIdx <= lastPage) {
				p.refreshPage(pageIdx);
				selectItem(p.firstVisibleDataIdx);
			}
		}
	}

	function itemsDataUpdated() {
		p.refreshView(p.firstVisibleDataIdx);
		selectItem(dataIndex);
	}

	/// Width and height of scrollable list including buttons area.
	width: parent.width
	height: parent.height

	/// Signal handler for count change. Only needed when all items are deleted
	onCountChanged: {
		if (count == 0) {
			initialView();
		}
	}

	/// "visible" model for Repeater - used to display up to itemsPerPage items. This is NOT the data model for all the available items
	ListModel {
		id: repeaterModel
	}

	Rectangle {
		id: markup
		color: colors.canvas
		height: parent.height - (designElements.vMargin10 * 2)
		radius: designElements.radius
		anchors {
			top: parent.top
			topMargin: designElements.vMargin10
			left: parent.left
			leftMargin: designElements.hMargin10
			right: scrollLane.left
			rightMargin: designElements.hMargin6
		}

		///Repeater within Column positioner for displaying the visible items
		Column {
			id: repeaterColumn
			width: markup.width
			height: markup.height
			anchors {
				top: markup.top
				topMargin: designElements.vMargin6
				left: markup.left
				leftMargin: designElements.hMargin6
			}
			spacing: designElements.spacing6

			Repeater {
				id: repeater
				model: repeaterModel
			}
		}
	}

	ThreeStateButton {
		id: butDown
		width: Math.round(44 * horizontalScaling)
		height: simpleList.buttonsHeight
		enabled: false
		backgroundUp: content.color
		backgroundDown: buttonDownStateBackground
		buttonDownColor: buttonDownStateColor
		iconAlign: "bottom"
		iconMargin: designElements.vMargin6
		image: simpleList.downIcon
		anchors {
			bottom: scrollLane.bottom
			right: parent.right
		}

		onClicked: {
			goNextPage();
		}
	}

	ThreeStateButton {
		id: butUp
		width: Math.round(44 * horizontalScaling)
		height: simpleList.buttonsHeight
		enabled: false
		imgRotation: 180
		backgroundUp: content.color
		backgroundDown: buttonDownStateBackground
		buttonDownColor: buttonDownStateColor
		iconAlign: "top"
		iconMargin: designElements.vMargin6
		image: simpleList.downIcon
		anchors {
			top: scrollLane.top
			right: parent.right
		}
		onClicked: {
			goPrevPage();
		}
	}

	Rectangle {
		id: scrollLane
		width: Math.round(6 * horizontalScaling)
		height: markup.height
		radius: width / 2
		color: colors.canvas
		anchors {
			right: butUp.left
			top: markup.top
		}
	}

	Rectangle {
		id: scrollbar
		width: Math.round(6 * horizontalScaling)
		radius: width / 2
		visible: false
		anchors {
			left: scrollLane.left
			top: scrollLane.top
		}
	}
}