import { LightningElement, api, track, wire } from 'lwc';
import fetchAllMasterDataMappings from '@salesforce/apex/FEC_NatureOfCaseTreeService.fetchAllMasterDataMappings';
import updateNode from '@salesforce/apex/FEC_NatureOfCaseTreeController.updateNode';
import { showLog } from 'c/fecMDMUtils';
import LABEL_ALIAS from '@salesforce/label/c.FEC_Label_Alias';
import LABEL_NAME_EN from '@salesforce/label/c.FEC_Label_Name_EN';
import LABEL_NAME_VN from '@salesforce/label/c.FEC_Label_Name_VN';
import LABEL_ORDER from '@salesforce/label/c.FEC_Label_Order';
import LABEL_STATUS from '@salesforce/label/c.FEC_Label_Status';
import LABEL_BUTTON_UNDO from '@salesforce/label/c.FEC_Button_Undo';
import LABEL_SPINNER_LOADING_NODE_DETAILS from '@salesforce/label/c.FEC_Spinner_Loading_Node_Details';
import LABEL_ERROR from '@salesforce/label/c.FEC_Label_Error';
import LABEL_PROMPT_SELECT_NODE_DETAIL from '@salesforce/label/c.FEC_Prompt_Select_Node_Detail';
import LABEL_NODE_PRODUCT_LINE from '@salesforce/label/c.FEC_Node_Product_Line';
import LABEL_NODE_SERVICE_TYPE from '@salesforce/label/c.FEC_Node_Service_Type';
import LABEL_NODE_CATEGORY from '@salesforce/label/c.FEC_Node_Category';
import LABEL_NODE_SUB_CATEGORY from '@salesforce/label/c.FEC_Node_Sub_Category';
import LABEL_NODE_ACTION from '@salesforce/label/c.FEC_Node_Action';
import LABEL_CHILD_SERVICE_TYPES from '@salesforce/label/c.FEC_Child_Service_Types';
import LABEL_CHILD_CATEGORIES from '@salesforce/label/c.FEC_Child_Categories';
import LABEL_CHILD_SUB_CATEGORIES from '@salesforce/label/c.FEC_Child_Sub_Categories';
import LABEL_CHILD_ACTIONS from '@salesforce/label/c.FEC_Child_Actions';
import LABEL_RECORD_ID from '@salesforce/label/c.FEC_Label_Record_ID';
import LABEL_NAME_VN_DISPLAY from '@salesforce/label/c.FEC_Label_Name_VN_Display';
import LABEL_TYPE_DISPLAY from '@salesforce/label/c.FEC_Label_Type_Display';
import LABEL_UPDATED_SUCCESS from '@salesforce/label/c.FEC_Updated_Success';
import LABEL_PLEASE_FILL_ALL from '@salesforce/label/c.FEC_Please_Fill_All';
import { VARIANT_SUCCESS, VARIANT_ERROR, ICON_MAP, ICON_FALLBACK, TYPE_TEXT, OBJ_PRODUCT_TYPE, OBJ_BUSINESS_PROCESS, OBJ_CATEGORY, OBJ_SUB_CATEGORY, OBJ_SUB_CODE, PREFIX_PT, PREFIX_BP, PREFIX_CAT, PREFIX_SCAT, PREFIX_SC, OBJECT_MAP } from 'c/fecConstants';

// Node type keys used in data/model
const NODE_PRODUCT_LINE = 'Product_Line';
const NODE_SERVICE_TYPE = 'Service_Type';
const NODE_CATEGORY = 'Category';
const NODE_SUB_CATEGORY = 'Sub_Category';
const NODE_ACTION = 'Action';

/**
 * @description LWC Component chi tiết Node (Tab 1)
 * @date 2025-12-03
 * @author DAT NGO
 */
export default class FecMasterDataItemDetail extends LightningElement {
    // Use accessor for @api item (defined below). Initialize reactive state and helper properties.
    @track editedItem = {};
    @track loading = false;
    @track isDirty = false;          // Reactive: true khi có thay đổi

    // Getter ensures LWC recomputes on every render when isDirty changes
    get isUndoDisabled() {
        console.log('[DEBUG][isUndoDisabled getter] called, isDirty:', this.isDirty, '-> returns:', !this.isDirty);
        return !this.isDirty;
    }
    // Error object (server responses) -- getters at bottom will surface message
    error = null;

    // runtime caches / helpers
    mappingRecords = [];
    wiredMappingsResult = null;
    objectMap = OBJECT_MAP;
    selectedNodePrefix = null;
    _item = null;
    _originalItem = null;

    // expose labels
    labelAlias = LABEL_ALIAS;
    labelNameEN = LABEL_NAME_EN;
    labelNameVN = LABEL_NAME_VN;
    labelOrder = LABEL_ORDER;
    labelStatus = LABEL_STATUS;
    labelUndo = LABEL_BUTTON_UNDO;
    labelSpinnerLoading = LABEL_SPINNER_LOADING_NODE_DETAILS;
    labelError = LABEL_ERROR;
    labelPromptSelectNode = LABEL_PROMPT_SELECT_NODE_DETAIL;

    get nodeId() {
        return this.item?.id;
    }

    get nodeType() {
        return this.item?.type;
    }

    @wire(fetchAllMasterDataMappings)
    wiredMappings(result) {
        this.wiredMappingsResult = result;
        if (result.data) {
            this.processMappingData(result.data);
        } else if (result.error) {
            // Keep error object for UI getters
            this.error = result.error;
            console.error('Error loading mappings:', result.error);
        }
    }

    processMappingData(mappings) {
        if (!this.nodeId || !this.nodeType) {
            this.mappingRecords = [];
            return;
        }

        // Filter mappings related to this node
        const relatedMappings = mappings.filter(mapping => {
            switch (this.nodeType) {
                case NODE_PRODUCT_LINE:
                    return mapping.CS_Product_Line__c === this.nodeId;
                case NODE_SERVICE_TYPE:
                    return mapping.CS_Service_Type__c === this.nodeId;
                case NODE_CATEGORY:
                    return mapping.CS_Category__c === this.nodeId;
                case NODE_SUB_CATEGORY:
                    return mapping.CS_Sub_Category__c === this.nodeId;
                case NODE_ACTION:
                    return mapping.CS_Action__c === this.nodeId;
                default:
                    return false;
            }
        });

        this.mappingRecords = relatedMappings;
    }

    // Computed properties
    get hasNodeDetails() {
        return this.nodeDetails && this.nodeDetails.record;
    }

    get nodeTypeLabel() {
        if (this.item?.type) {
            return this.getNodeTypeLabel(this.item.type);
        }
        return '';
    }

    @api
    set item(value) {
        const incomingId = value?.id;
        const currentId = this._item?.id;

        console.log('[DEBUG][item setter] incomingId:', incomingId, '| currentId:', currentId, '| isDirty:', this.isDirty);

        // Only reset state when a DIFFERENT node is selected
        // If parent reflects back the same node (after nodebufferchange), skip reset
        if (incomingId && incomingId === currentId && this.isDirty) {
            // Same node, user is editing → only update _item reference, do NOT touch editedItem/_originalItem/isDirty
            this._item = value;
            console.log('[DEBUG][item setter] Same node + isDirty → skip reset, keep editedItem and isDirty');
            return;
        }

        // Different node selected → full reset
        this._item = value;
        this.editedItem = value ? JSON.parse(JSON.stringify(value)) : {};
        this._originalItem = value ? JSON.parse(JSON.stringify(value)) : {};
        this.isDirty = false;
        console.log('[DEBUG][item setter] New node → reset. _originalItem:', JSON.stringify(this._originalItem));

        // Precompute selectedNodePrefix from name (pure side-effect in setter)
        const name = this.editedItem?.name || '';
        const parts = name ? name.split('_') : [];
        this.selectedNodePrefix = parts.length > 1 ? parts[0] : null;
    }
    get item() {
        return this._item;
    }

    get targetObjectType() {
        const prefix = this.selectedNodePrefix;
        if (!prefix || !this.objectMap) {
            return this.editedItem?.Code || '';
        }
        const label = this.objectMap[prefix] || '';
        // If the object name is "FEC_MDM_Sub_Code__c", we want to display "Sub Code"
        // Let's create a more readable display name for the header
        let friendlyLabel = label;
        if (prefix === PREFIX_SC) friendlyLabel = OBJ_SUB_CODE;
        else if (prefix === PREFIX_SCAT) friendlyLabel = OBJ_SUB_CATEGORY;
        else if (prefix === PREFIX_CAT) friendlyLabel = OBJ_CATEGORY;
        else if (prefix === PREFIX_BP) friendlyLabel = OBJ_BUSINESS_PROCESS;
        else if (prefix === PREFIX_PT) friendlyLabel = OBJ_PRODUCT_TYPE;

        const code = this.editedItem?.Code || '';
        return (friendlyLabel ? friendlyLabel + ' ID: ' : '') + code;
    }

    validateForm() {
        const allValid = [
            ...this.template.querySelectorAll('lightning-input'),
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity(); // Hiển thị lỗi đỏ nếu input không hợp lệ
            return validSoFar && inputCmp.checkValidity();
        }, true);
        return allValid;
    }

    // Change data
    handleSubmit(event) {
        if (!this.validateForm()) {
            this.showToast(LABEL_PLEASE_FILL_ALL, '', VARIANT_ERROR);
            return;
        }

        const updateData = { ... this.editedItem };
        showLog('handleSubmit updateData', updateData);
        updateNode({ updateData })
            .then(() => {
                this.showToast(LABEL_UPDATED_SUCCESS, '', VARIANT_SUCCESS);
                showLog('handleSubmit SUCCESS', 'Bản ghi đã được lưu thành công');
                this.dispatchEvent(new CustomEvent('save', {
                    bubbles: true,
                    composed: true
                }));
            })
            .catch(error => {
                this.showToast(LABEL_ERROR, error.body?.message || error.message, VARIANT_ERROR);
                showLog('handleSubmit ERROR', error);
            })
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;

        console.log('[DEBUG][handleInputChange] START ------');
        console.log('[DEBUG][handleInputChange] field:', field, '| value:', value, '| type:', typeof value);
        console.log('[DEBUG][handleInputChange] _originalItem:', JSON.stringify(this._originalItem));
        console.log('[DEBUG][handleInputChange] editedItem BEFORE:', JSON.stringify(this.editedItem));
        console.log('[DEBUG][handleInputChange] isDirty BEFORE:', this.isDirty);
        console.log('[DEBUG][handleInputChange] isUndoDisabled BEFORE (getter):', this.isUndoDisabled);

        // Update only the changed field (shallow merge, then deep clone to sever reference)
        this.editedItem = JSON.parse(JSON.stringify({ ...this.editedItem, [field]: value }));

        console.log('[DEBUG][handleInputChange] editedItem AFTER:', JSON.stringify(this.editedItem));

        // Compare each tracked field against the original snapshot
        const orig = this._originalItem;
        const curr = this.editedItem;

        console.log('[DEBUG][handleInputChange] COMPARE Alias    :', curr.Alias,    '!==', orig.Alias,    '->', curr.Alias !== orig.Alias);
        console.log('[DEBUG][handleInputChange] COMPARE NameEN   :', curr.NameEN,   '!==', orig.NameEN,   '->', curr.NameEN !== orig.NameEN);
        console.log('[DEBUG][handleInputChange] COMPARE nameVN   :', curr.nameVN,   '!==', orig.nameVN,   '->', curr.nameVN !== orig.nameVN);
        console.log('[DEBUG][handleInputChange] COMPARE PosOrder :', curr.PosOrder, '!= ', orig.PosOrder, '->', curr.PosOrder != orig.PosOrder);
        console.log('[DEBUG][handleInputChange] COMPARE Status   :', curr.Status,   '!==', orig.Status,   '->', curr.Status !== orig.Status);

        this.isDirty = (
            curr.Alias     !== orig.Alias     ||
            curr.NameEN    !== orig.NameEN    ||
            curr.nameVN    !== orig.nameVN    ||
            curr.PosOrder  != orig.PosOrder   ||
            curr.Status    !== orig.Status
        );

        console.log('[DEBUG][handleInputChange] isDirty AFTER:', this.isDirty);
        console.log('[DEBUG][handleInputChange] isUndoDisabled AFTER (getter):', this.isUndoDisabled);
        console.log('[DEBUG][handleInputChange] END ------');

        this.dispatchEvent(new CustomEvent('nodebufferchange', {
            detail: this.editedItem,
            bubbles: true,
            composed: true
        }));
    }


    get nodeIcon() {
        const nodeType = this.item?.type;
        if (!nodeType) {
            return ICON_FALLBACK;
        }
        return ICON_MAP[nodeType] || ICON_FALLBACK;
    }

    get displayFields() {
        if (!this.hasNodeDetails) return [];

        const record = this.nodeDetails.record;
        const fields = [];

        // ID field
        if (record?.Id) {
            fields.push({
                label: LABEL_RECORD_ID,
                value: record.Id,
                type: TYPE_TEXT,
                isStatus: false
            });
        }

        // Name field
        if (record?.Name) {
            fields.push({
                label: LABEL_NAME_EN,
                value: record.Name,
                type: TYPE_TEXT,
                isStatus: false
            });
        }

        // Vietnamese name field
        if (record?.NameVN__c) {
            fields.push({
                label: LABEL_NAME_VN_DISPLAY,
                value: record.NameVN__c,
                type: TYPE_TEXT,
                isStatus: false
            });
        }

        // Type field
        fields.push({
            label: LABEL_TYPE_DISPLAY,
            value: this.nodeTypeLabel,
            type: TYPE_TEXT,
            isStatus: false
        });

        return fields;
    }

    get hasHierarchyPath() {
        return this.hierarchyPath && this.hierarchyPath.length > 0;
    }

    get hierarchyPath() {
        if (!this.item || !this.mappingRecords.length) return [];

        // Get the first mapping that contains this node to build path
        const mapping = this.mappingRecords[0];
        if (!mapping) return [];

        const path = [];

        // Build path from mapping
        if (mapping.CS_Product_Line__r) {
            path.push({
                type: NODE_PRODUCT_LINE,
                name: mapping.CS_Product_Line__r.Name,
                label: LABEL_NODE_PRODUCT_LINE,
                icon: ICON_MAP[NODE_PRODUCT_LINE] || ICON_FALLBACK,
                isLast: false
            });
        }

        if (mapping.CS_Service_Type__r) {
            path.push({
                type: NODE_SERVICE_TYPE,
                name: mapping.CS_Service_Type__r.Name,
                label: LABEL_NODE_SERVICE_TYPE,
                icon: ICON_MAP[NODE_SERVICE_TYPE] || ICON_FALLBACK,
                isLast: false
            });
        }

        if (mapping.CS_Category__r) {
            path.push({
                type: NODE_CATEGORY,
                name: mapping.CS_Category__r.Name,
                label: LABEL_NODE_CATEGORY,
                icon: ICON_MAP[NODE_CATEGORY] || ICON_FALLBACK,
                isLast: false
            });
        }

        if (mapping.CS_Sub_Category__r) {
            path.push({
                type: NODE_SUB_CATEGORY,
                name: mapping.CS_Sub_Category__r.Name,
                label: LABEL_NODE_SUB_CATEGORY,
                icon: ICON_MAP[NODE_SUB_CATEGORY] || ICON_FALLBACK,
                isLast: false
            });
        }

        if (mapping.CS_Action__r) {
            path.push({
                type: NODE_ACTION,
                name: mapping.CS_Action__r.Name,
                label: LABEL_NODE_ACTION,
                icon: ICON_MAP[NODE_ACTION] || ICON_FALLBACK,
                isLast: false
            });
        }

        // Mark last item
        if (path.length > 0) {
            path[path.length - 1].isLast = true;
        }

        return path;
    }

    get hasMappings() {
        return this.mappingRecords && this.mappingRecords.length > 0;
    }

    get hasChildNodes() {
        return this.childNodes && this.childNodes.length > 0;
    }

    get childNodes() {
        // This will be populated from tree data passed from parent
        return this.item?.items || [];
    }

    get childNodesTitle() {
        const childTypeMap = {
            [NODE_PRODUCT_LINE]: LABEL_CHILD_SERVICE_TYPES,
            [NODE_SERVICE_TYPE]: LABEL_CHILD_CATEGORIES,
            [NODE_CATEGORY]: LABEL_CHILD_SUB_CATEGORIES,
            [NODE_SUB_CATEGORY]: LABEL_CHILD_ACTIONS
        };
        return childTypeMap[this.item?.type] || 'Child Nodes';
    }

    get totalMappings() {
        return this.mappingRecords?.length || 0;
    }

    get directChildren() {
        return this.childNodes?.length || 0;
    }

    get totalDescendants() {
        // Calculate total descendants recursively
        const countDescendants = (nodes) => {
            if (!nodes || !nodes.length) return 0;
            let count = nodes.length;
            nodes.forEach(node => {
                count += countDescendants(node.items);
            });
            return count;
        };
        return countDescendants(this.childNodes);
    }

    // Methods
    getNodeTypeLabel(nodeType) {
        // Map the NODE_* constants to the descriptive Labels
        const labels = {
            [NODE_PRODUCT_LINE]: LABEL_NODE_PRODUCT_LINE,
            [NODE_SERVICE_TYPE]: LABEL_NODE_SERVICE_TYPE,
            [NODE_CATEGORY]: LABEL_NODE_CATEGORY,
            [NODE_SUB_CATEGORY]: LABEL_NODE_SUB_CATEGORY,
            [NODE_ACTION]: LABEL_NODE_ACTION
        };
        // Safety check: if nodeType is not in our internal NODE_* map, check if it matches the object labels
        let label = labels[nodeType];
        if (!label) {
            if (nodeType === OBJ_PRODUCT_TYPE) label = LABEL_NODE_PRODUCT_LINE;
            else if (nodeType === OBJ_BUSINESS_PROCESS) label = LABEL_NODE_SERVICE_TYPE;
            else if (nodeType === OBJ_CATEGORY) label = LABEL_NODE_CATEGORY;
            else if (nodeType === OBJ_SUB_CATEGORY) label = LABEL_NODE_SUB_CATEGORY;
            else if (nodeType === OBJ_SUB_CODE) label = LABEL_NODE_ACTION;
        }

        return label || nodeType;
    }

    handleRefresh() {
        // 1. Restore editedItem from the original snapshot taken when the node was first loaded
        this.editedItem = JSON.parse(JSON.stringify(this._originalItem));

        // 2. Reset dirty/undo state so Undo button becomes disabled again
        this.isDirty = false;

        // 3. Notify parent that local buffer has been reset
        this.dispatchEvent(new CustomEvent('nodebufferreset', {
            detail: { idType: this.item?.idType, id: this.item?.id },
            bubbles: true,
            composed: true
        }));

        showLog('handleRefresh - Restored to original data', this.editedItem);
    }

    // Watch for item changes to reprocess mapping data
    @api
    refreshData() {
        this.handleRefresh();
    }

    // Handle when item changes
    connectedCallback() {
        // Watch for item changes
        if (this.item?.id) {
            // If mappings already loaded, reprocess using cached data
            const mappings = this.wiredMappingsResult?.data || [];
            this.processMappingData(mappings);
        }
    }

    // Error display helpers
    get hasError() {
        return !!(this.error && (this.error.body?.message || this.error.message));
    }

    get errorMessage() {
        return this.error?.body?.message || this.error?.message || 'An error occurred while loading node details.';
    }
}