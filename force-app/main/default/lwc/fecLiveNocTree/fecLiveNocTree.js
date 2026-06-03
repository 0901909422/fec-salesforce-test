import { LightningElement, wire, track, api } from 'lwc';
import getLiveNocTreeData from '@salesforce/apex/FEC_LiveNatureOfCaseTreeController.getNatureOfCaseTreeData';
import deleteNodeApex from '@salesforce/apex/FEC_LiveNatureOfCaseTreeController.deleteNodeApex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import FECNatureOfCaseModal from 'c/fecNatureOfCaseModal';
import LABEL_TREE_TITLE from '@salesforce/label/c.FEC_Tree_Title';
import LABEL_PLACEHOLDER_SEARCH_TREE from '@salesforce/label/c.FEC_Placeholder_Search_Tree';
import LABEL_SHOW_FIELD from '@salesforce/label/c.FEC_Label_Show_Field';
import LABEL_ADD_ROOT from '@salesforce/label/c.FEC_Button_Add_Root';
import LABEL_ADD_NODE from '@salesforce/label/c.FEC_Button_Add_Node';
import LABEL_MESSAGE_NO_ITEMS from '@salesforce/label/c.FEC_Message_No_Items';
import LABEL_MESSAGE_LOADING_TREE from '@salesforce/label/c.FEC_Message_Loading_Tree';
import LABEL_ARIA_TREE from '@salesforce/label/c.FEC_Aria_Tree_Label';
import LABEL_ARIA_ADD_NODE from '@salesforce/label/c.FEC_Aria_Add_Node';
import LABEL_DISPLAY_CODE from '@salesforce/label/c.FEC_Label_Display_Code';
import LABEL_DISPLAY_ALIAS from '@salesforce/label/c.FEC_Label_Display_Alias';
import LABEL_DISPLAY_NAME_VN from '@salesforce/label/c.FEC_Label_Display_Name_VN';
import LABEL_DISPLAY_NAME_EN from '@salesforce/label/c.FEC_Label_Display_Name_EN';
import LABEL_STATUS_ALL from '@salesforce/label/c.FEC_Label_Status_ALL';
import LABEL_STATUS_ACTIVE from '@salesforce/label/c.FEC_Label_Status_ACTIVE';
import LABEL_STATUS_INACTIVE from '@salesforce/label/c.FEC_Label_Status_INACTIVE';
import LABEL_ERROR_ADD_SUB_CODE from '@salesforce/label/c.LABEL_ERROR_ADD_SUB_CODE';
import LABEL_ERROR_DELETE_RECORD from '@salesforce/label/c.LABEL_ERROR_DELETE_RECORD';
import LABEL_TOAST_ERROR from '@salesforce/label/c.FEC_Toast_Error';
import LABEL_TOAST_SUCCESS from '@salesforce/label/c.FEC_Toast_Success';
import LABEL_TOAST_WARNING from '@salesforce/label/c.FEC_Toast_Warning';
import LABEL_SUCCESS_DELETE from '@salesforce/label/c.LABEL_SUCCESS_DELETE';
import LABEL_WARNING_DELETE_NODE from '@salesforce/label/c.LABEL_WARNING_DELETE_NODE';
import LABEL_WARNING_SELECT_NODE from '@salesforce/label/c.FEC_Warning_Select_Node';
import {
    OBJ_PRODUCT_TYPE, OBJ_BUSINESS_PROCESS, OBJ_CATEGORY, OBJ_SUB_CATEGORY, OBJ_SUB_CODE,
    PREFIX_PT, PREFIX_BP, PREFIX_CAT, PREFIX_SCAT, PREFIX_SC,
    DISPLAY_FIELD_CODE, DISPLAY_FIELD_ALIAS, DISPLAY_FIELD_NAME_VN, DISPLAY_FIELD_NAME_EN,
    STATUS_ALL, STATUS_ACTIVE, STATUS_INACTIVE,
    TITLE_CLASS_BASE, TITLE_CLASS_SELECTED_SUFFIX
} from 'c/fecConstants';

export default class FecLiveNocTree extends LightningElement {
    // Labels
    labelTreeTitle = LABEL_TREE_TITLE;
    placeholderSearchTree = LABEL_PLACEHOLDER_SEARCH_TREE;
    labelShowField = LABEL_SHOW_FIELD;
    labelAddRoot = LABEL_ADD_ROOT;
    labelAddNode = LABEL_ADD_NODE;
    messageNoItems = LABEL_MESSAGE_NO_ITEMS;
    messageLoading = LABEL_MESSAGE_LOADING_TREE;
    ariaTreeLabel = LABEL_ARIA_TREE;
    ariaAddNode = LABEL_ARIA_ADD_NODE;

    @track treeItems;
    wiredTreeDataResult;
    @track selectedNodeId = null;
    @track selectedNodeCustomerType = null;
    @track selectedNodeLabel;
    @track selectedNodePrefix;
    @track selectedNodeName = '';
    @track isTitleSelected = true;
    @track treeKey = 1;
    @track searchTerm = '';
    @track expandedNodeNames = new Set();
    @track isLoading = true;
    fecRawData = [];

    lastSelectedNodeId = null;
    selectNodeTimeout = null;

    objectMap = {
        [PREFIX_PT]: OBJ_BUSINESS_PROCESS,
        [PREFIX_BP]: OBJ_CATEGORY,
        [PREFIX_CAT]: OBJ_SUB_CATEGORY,
        [PREFIX_SCAT]: OBJ_SUB_CODE
    };
    objectMapRoot = {
        [PREFIX_PT]: OBJ_PRODUCT_TYPE,
        [PREFIX_BP]: OBJ_BUSINESS_PROCESS,
        [PREFIX_CAT]: OBJ_CATEGORY,
        [PREFIX_SCAT]: OBJ_SUB_CATEGORY,
        [PREFIX_SC]: OBJ_SUB_CODE
    };

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

    get addNodeButtonLabel() {
        if (this.isTitleSelected && !this.selectedNodeId) {
            return this.labelAddRoot;
        }
        return this.labelAddNode;
    }

    get isAddNodeDisabled() {
        if (this.isTitleSelected) return false;
        if (!this.selectedNodeId) return true;
        if (this.selectedNodePrefix === PREFIX_SC) return true;
        return false;
    }

    // --- Event Handlers ---
    handleTitleClick() {
        this.selectedNodeId = null;
        this.selectedNodeCustomerType = null;
        this.selectedNodeLabel = null;
        this.selectedNodePrefix = null;
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

        if (this.lastSelectedNodeId === selectedId && this.selectNodeTimeout) return;
        if (this.selectNodeTimeout) clearTimeout(this.selectNodeTimeout);
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
        const parts = selectedName.split('_');
        if (parts.length > 1) {
            this.selectedNodeId = selectedItem.idType;
            this.selectedNodeCustomerType = selectedItem.FEC_Customer_Type;
            this.selectedNodePrefix = parts[0];
            this.selectedNodeLabel = selectedItem.nameVN;
        } else {
            this.selectedNodeId = null;
            this.selectedNodeCustomerType = null;
            this.selectedNodePrefix = null;
            this.selectedNodeLabel = null;
        }

        this.dispatchEvent(new CustomEvent('itemselect', { detail: selectedItem }));
    }

    handleNodeToggle(event) {
        const nodeName = String(event.detail.name);
        const isExpanded = event.detail.isExpanded;
        if (isExpanded) this.expandedNodeNames.add(nodeName);
        else this.expandedNodeNames.delete(nodeName);
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

    // --- CRUD: Add Node ---
    handleAddNodeAction() {
        if (this.isTitleSelected) {
            this.handleAddNewRoot();
        } else if (this.selectedNodeId) {
            this.handleAddNewChild();
        }
    }

    async openAddNodeModal(parentId, objectType, parentLabel, parentCustomerType) {
        const result = await FECNatureOfCaseModal.open({
            size: 'small',
            description: `Form adding ${objectType}`,
            parentId: parentId,
            objectType: objectType,
            parentLabel: parentLabel,
            parentCustomerType: parentCustomerType,
            dataMode: 'LIVE'
        });
        if (result != null) {
            await this.handleSaveSuccess();
            if (result.action === 'refreshAndReopen') {
                this.openAddNodeModal(parentId, objectType, parentLabel, parentCustomerType);
            }
        }
    }

    handleAddNewRoot() {
        this.openAddNodeModal(null, OBJ_PRODUCT_TYPE, this.labelAddRoot || 'Root', '');
    }

    handleAddNewChild(fullItem) {
        const nodeId = fullItem ? fullItem.idType : this.selectedNodeId;
        const prefix = fullItem ? fullItem.name?.split('_')[0] : this.selectedNodePrefix;
        const targetObjectType = this.objectMap[prefix];

        if (!targetObjectType) {
            this.showErrorToast(LABEL_ERROR_ADD_SUB_CODE);
            return;
        }
        const label = fullItem ? fullItem.nameVN : this.selectedNodeLabel;
        const customerType = fullItem ? fullItem.FEC_Customer_Type : this.selectedNodeCustomerType;
        this.openAddNodeModal(nodeId, targetObjectType, label, customerType);
    }

    handleNodeAdd(event) {
        event.stopPropagation();
        const { type, fullItem, parentId } = event.detail;
        const selectedName = event.detail.name || fullItem.name;
        this.isTitleSelected = false;
        this.selectedNodeName = selectedName;

        if (type === 'same') {
            this.handleOpenModalForSameLevel(fullItem, parentId);
        } else {
            if (fullItem) {
                const parts = selectedName.split('_');
                if (parts.length > 1) {
                    this.selectedNodeId = fullItem.idType;
                    this.selectedNodeCustomerType = fullItem.FEC_Customer_Type;
                    this.selectedNodePrefix = parts[0];
                    this.selectedNodeLabel = fullItem.nameVN;
                }
            }
            this.handleAddNewChild(fullItem);
        }
    }

    async handleOpenModalForSameLevel(fullItem, parentId) {
        const currentPrefix = fullItem.name.split('_')[0];
        const targetObjectType = this.objectMapRoot[currentPrefix];
        this.openAddNodeModal(parentId, targetObjectType, 'Same Level', this.selectedNodeCustomerType);
    }

    // --- CRUD: Delete Node ---
    async handleNodeDelete(event) {
        const { fullItem } = event.detail;
        const idType = fullItem.idType;
        const type = fullItem.type;
        const code = fullItem.Code;

        if (!idType || !type) {
            this.showErrorToast(LABEL_ERROR_DELETE_RECORD);
            return;
        }
        const msg = LABEL_WARNING_DELETE_NODE.replace('{0}', code).replace('{1}', type);
        // eslint-disable-next-line no-alert
        const confirmed = confirm(msg);
        if (!confirmed) return;

        try {
            this.isLoading = true;
            await deleteNodeApex({ typeRecordId: idType, typeName: type });
            this.dispatchEvent(new ShowToastEvent({
                title: LABEL_TOAST_SUCCESS,
                message: LABEL_SUCCESS_DELETE,
                variant: 'success'
            }));
            await this.refreshTreeData();
        } catch (error) {
            this.showErrorToast(error.body?.message || LABEL_ERROR_DELETE_RECORD);
        } finally {
            this.isLoading = false;
        }
    }

    // --- Save Success Handler ---
    async handleSaveSuccess() {
        try {
            await refreshApex(this.wiredTreeDataResult);
            const freshData = this.wiredTreeDataResult.data;
            if (freshData) {
                this.treeKey = false;
                this.fecRawData = [...freshData].map(item => ({ ...item }));
                if (this.selectedNodeName) {
                    this.expandedNodeNames.add(String(this.selectedNodeName));
                }
                const processedItems = this.applyFilterAndExpand(this.fecRawData, this.searchTerm);
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    this.treeItems = processedItems;
                    this.treeKey = true;
                }, 0);
            }
        } catch (error) {
            console.error('Error refreshing tree:', error);
        }
    }

    // --- Filter Helper ---
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
        this.dispatchEvent(new ShowToastEvent({
            title: LABEL_TOAST_ERROR,
            message: message,
            variant: 'error'
        }));
    }
}