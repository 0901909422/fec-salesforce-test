import { LightningElement, wire, track, api } from 'lwc';
import getLiveNocTreeData from '@salesforce/apex/FEC_LiveDataViewController.getLiveNocTreeData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LABEL_TREE_TITLE from '@salesforce/label/c.FEC_Tree_Title';
import LABEL_PLACEHOLDER_SEARCH_TREE from '@salesforce/label/c.FEC_Placeholder_Search_Tree';
import LABEL_SHOW_FIELD from '@salesforce/label/c.FEC_Label_Show_Field';
import LABEL_MESSAGE_NO_ITEMS from '@salesforce/label/c.FEC_Message_No_Items';
import LABEL_MESSAGE_LOADING_TREE from '@salesforce/label/c.FEC_Message_Loading_Tree';
import LABEL_ARIA_TREE from '@salesforce/label/c.FEC_Aria_Tree_Label';
import LABEL_DISPLAY_CODE from '@salesforce/label/c.FEC_Label_Display_Code';
import LABEL_DISPLAY_ALIAS from '@salesforce/label/c.FEC_Label_Display_Alias';
import LABEL_DISPLAY_NAME_VN from '@salesforce/label/c.FEC_Label_Display_Name_VN';
import LABEL_DISPLAY_NAME_EN from '@salesforce/label/c.FEC_Label_Display_Name_EN';
import LABEL_STATUS_ALL from '@salesforce/label/c.FEC_Label_Status_ALL';
import LABEL_STATUS_ACTIVE from '@salesforce/label/c.FEC_Label_Status_ACTIVE';
import LABEL_STATUS_INACTIVE from '@salesforce/label/c.FEC_Label_Status_INACTIVE';
import LABEL_TOAST_ERROR from '@salesforce/label/c.FEC_Toast_Error';
import {
    DISPLAY_FIELD_CODE, DISPLAY_FIELD_ALIAS, DISPLAY_FIELD_NAME_VN, DISPLAY_FIELD_NAME_EN,
    STATUS_ALL, STATUS_ACTIVE, STATUS_INACTIVE,
    TITLE_CLASS_BASE, TITLE_CLASS_SELECTED_SUFFIX
} from 'c/fecConstants';

export default class FecLiveNocTree extends LightningElement {
    // Labels
    labelTreeTitle = LABEL_TREE_TITLE;
    placeholderSearchTree = LABEL_PLACEHOLDER_SEARCH_TREE;
    labelShowField = LABEL_SHOW_FIELD;
    messageNoItems = LABEL_MESSAGE_NO_ITEMS;
    messageLoading = LABEL_MESSAGE_LOADING_TREE;
    ariaTreeLabel = LABEL_ARIA_TREE;

    @track treeItems;
    wiredTreeDataResult;
    @track selectedNodeName = '';
    @track isTitleSelected = true;
    @track treeKey = 1;
    @track searchTerm = '';
    @track expandedNodeNames = new Set();
    @track isLoading = true;
    fecRawData = [];

    // Debounce variables
    lastSelectedNodeId = null;
    selectNodeTimeout = null;

    // Display field options
    @track selectedDisplayField = DISPLAY_FIELD_CODE;
    displayFieldOptions = [
        { label: LABEL_DISPLAY_CODE, value: DISPLAY_FIELD_CODE },
        { label: LABEL_DISPLAY_ALIAS, value: DISPLAY_FIELD_ALIAS },
        { label: LABEL_DISPLAY_NAME_VN, value: DISPLAY_FIELD_NAME_VN },
        { label: LABEL_DISPLAY_NAME_EN, value: DISPLAY_FIELD_NAME_EN }
    ];

    // Status filter options
    @track selectedStatusFilter = STATUS_ALL;
    statusOptions = [
        { label: LABEL_STATUS_ALL, value: STATUS_ALL },
        { label: LABEL_STATUS_ACTIVE, value: STATUS_ACTIVE },
        { label: LABEL_STATUS_INACTIVE, value: STATUS_INACTIVE }
    ];

    @wire(getLiveNocTreeData)
    wiredTreeData(result) {
        this.wiredTreeDataResult = result;
        const { error, data } = result;
        this.isLoading = false;
        if (data) {
            if (this.expandedNodeNames.size === 0) {
                this.treeItems = data;
            }
            this.fecRawData = data;
        } else if (error) {
            this.treeItems = [];
            this.fecRawData = [];
            this.showErrorToast(error.body?.message || error.message || 'Unknown error');
        }
    }

    @api
    async refreshTreeData() {
        this.isLoading = true;
        await refreshApex(this.wiredTreeDataResult);
        const freshData = this.wiredTreeDataResult.data;
        if (freshData) {
            this.treeKey = false;
            this.fecRawData = [...freshData].map(item => ({ ...item }));
            if (this.selectedNodeName) {
                this.expandedNodeNames.add(String(this.selectedNodeName));
            }
            const processedItems = this.applyFilterAndExpand(this.fecRawData, this.searchTerm, this.selectedNodeName);
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.treeItems = processedItems;
                this.treeKey = true;
            }, 0);
        }
        this.isLoading = false;
    }

    // --- Getters ---

    get isTreeEmpty() {
        return Array.isArray(this.treeItems) && this.treeItems.length === 0;
    }

    get titleClass() {
        return TITLE_CLASS_BASE + (this.isTitleSelected ? TITLE_CLASS_SELECTED_SUFFIX : '');
    }

    // --- Event Handlers ---

    handleTitleClick() {
        this.isTitleSelected = true;
        this.selectedNodeName = '';
        this.lastSelectedNodeId = null;

        const currentItems = [...this.treeItems];
        this.treeItems = [];
        Promise.resolve().then(() => {
            this.treeItems = currentItems;
        });

        this.dispatchEvent(new CustomEvent('itemselect', { detail: {} }));
    }

    handleNodeSelect(event) {
        const selectedId = event.detail.fullItem?.idType;
        const selectedName = event.detail.name;

        if (this.lastSelectedNodeId === selectedId && this.selectNodeTimeout) {
            return;
        }
        if (this.selectNodeTimeout) {
            clearTimeout(this.selectNodeTimeout);
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.selectNodeTimeout = setTimeout(() => {
            this.selectNodeTimeout = null;
            this.lastSelectedNodeId = null;
        }, 200);
        this.lastSelectedNodeId = selectedId;

        const selectedItem = event.detail.fullItem;
        if (!selectedItem) return;

        this.isTitleSelected = false;
        this.selectedNodeName = selectedName;

        this.dispatchEvent(new CustomEvent('itemselect', { detail: selectedItem }));
    }

    handleNodeToggle(event) {
        const nodeName = String(event.detail.name);
        const isExpanded = event.detail.isExpanded;
        if (isExpanded) {
            this.expandedNodeNames.add(nodeName);
        } else {
            this.expandedNodeNames.delete(nodeName);
        }
    }

    handleFecSearch(event) {
        this.searchTerm = event.target.value;
        this.treeItems = this.applyFilterAndExpand(this.fecRawData, this.searchTerm);
    }

    handleDisplayFieldChange(event) {
        this.selectedDisplayField = event.detail.value;
    }

    handleStatusChange(event) {
        this.selectedStatusFilter = event.detail.value;
        this.treeItems = this.applyFilterAndExpand(this.fecRawData, this.searchTerm, this.selectedNodeName);
    }

    // --- Helper Methods ---

    applyFilterAndExpand(data, searchTerm, forceExpandId) {
        const searchKey = searchTerm ? searchTerm.toLowerCase().trim() : '';
        const targetId = forceExpandId ? String(forceExpandId) : null;

        const filterAndExpand = (items) => {
            return items.map(item => {
                const newItem = { ...item };
                const currentName = String(newItem.name);

                let isAnyChildExpanded = false;
                if (newItem.items && newItem.items.length > 0) {
                    newItem.items = filterAndExpand(newItem.items);
                    isAnyChildExpanded = newItem.items.some(child => child.isExpanded);
                }

                const isManuallyExpanded = this.expandedNodeNames.has(currentName);
                const isTargetParent = targetId && currentName === targetId;

                // Status filter
                let statusMatches = true;
                if (this.selectedStatusFilter && this.selectedStatusFilter !== 'ALL' &&
                    newItem.Status !== undefined && newItem.Status !== null) {
                    statusMatches = (this.selectedStatusFilter === 'ACTIVE')
                        ? Boolean(newItem.Status) === true
                        : Boolean(newItem.Status) === false;
                }

                if (searchKey) {
                    const fieldToSearch = (this.selectedDisplayField && newItem[this.selectedDisplayField] != null)
                        ? String(newItem[this.selectedDisplayField]).toLowerCase()
                        : String(newItem.label).toLowerCase();
                    const matchesSearch = fieldToSearch.includes(searchKey);
                    newItem.isExpanded = (matchesSearch && statusMatches) || isAnyChildExpanded;
                    return ((matchesSearch && statusMatches) || isAnyChildExpanded) ? newItem : null;
                }

                // No search term: respect status filter and manual/child expansion
                if (!statusMatches && !(newItem.items && newItem.items.length > 0)) {
                    return null;
                }
                newItem.isExpanded = (isManuallyExpanded || isTargetParent) && statusMatches;
                return newItem;
            }).filter(item => item !== null);
        };

        return filterAndExpand(data || []);
    }

    showErrorToast(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: LABEL_TOAST_ERROR,
                message: message,
                variant: 'error'
            })
        );
    }
}