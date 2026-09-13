// js/tabs.js — Реэкспорт из js/tabs/tabs.js для обратной совместимости
.import "tabs/tabs.js" as TabsImpl

function stripExt(name) { return TabsImpl.stripExt(name) }
function findTabIndex(root, fileUrl) { return TabsImpl.findTabIndex(root, fileUrl) }
function findOtherTabIndex(root, excludeIdx) { return TabsImpl.findOtherTabIndex(root, excludeIdx) }
function getFileContent(root, fileUrl) { return TabsImpl.getFileContent(root, fileUrl) }
function replaceBlockInString(text, headingNorm, newContent) { return TabsImpl.replaceBlockInString(text, headingNorm, newContent) }
function syncCurrentPaneText(root) { return TabsImpl.syncCurrentPaneText(root) }
function syncEditorsFromModel(root) { return TabsImpl.syncEditorsFromModel(root) }
function setActivePane(root, paneIndex) { return TabsImpl.setActivePane(root, paneIndex) }
function switchToTab(root, index) { return TabsImpl.switchToTab(root, index) }
function openFileInTab(root, fileUrl, fileName, isShift) { return TabsImpl.openFileInTab(root, fileUrl, fileName, isShift) }
function createNewTab(root) { return TabsImpl.createNewTab(root) }
function closeTab(root, index) { return TabsImpl.closeTab(root, index) }
function renameTab(root, index, newTitle) { return TabsImpl.renameTab(root, index, newTitle) }
function closeSplit(root) { return TabsImpl.closeSplit(root) }
function toggleSplit(root) { return TabsImpl.toggleSplit(root) }
function swapPanes(root) { return TabsImpl.swapPanes(root) }
function handlePrimaryTextChanged(root, text) { return TabsImpl.handlePrimaryTextChanged(root, text) }
function handleSecondaryTextChanged(root, text) { return TabsImpl.handleSecondaryTextChanged(root, text) }
function detachTab(root, tabIndex) { return TabsImpl.detachTab(root, tabIndex) }
function openFileFromFolder(root, fileUrl, fileName, isShift) { return TabsImpl.openFileFromFolder(root, fileUrl, fileName, isShift) }
