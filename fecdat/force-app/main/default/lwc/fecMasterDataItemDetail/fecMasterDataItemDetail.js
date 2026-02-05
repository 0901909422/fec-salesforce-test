import { LightningElement, api, track } from 'lwc';
import getMasterDataMappings from '@salesforce/apex/FEC_NatureOfCaseTreeController.getMasterDataMappings';
import updateNode from '@salesforce/apex/FEC_NatureOfCaseTreeController.updateNode';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { showLog } from 'c/fecUtils'; // Import hàm chung
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
import { VARIANT_SUCCESS, VARIANT_ERROR, ICON_MAP, ICON_FALLBACK, TYPE_TEXT } from 'c/fecConstants/fecConstants';

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
    @api item; // item from parent
    @track editedItem = {};
    @track loading = false;
    @track hasError = false;
    @track errorMessage = '';

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

    // Wire the node details - only when item.id exists
    wiredNodeDetailsResult;
    wiredMappingsResult;

    get nodeId() {
        return this.item?.id;
    }

    get nodeType() {
        return this.item?.type;
    }

    @wire(getMasterDataMappings)
    wiredMappings(result) {
        this.wiredMappingsResult = result;
        if (result.data) {
            this.processMappingData(result.data);
        } else if (result.error) {
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
        // Tạo bản sao sâu (deep clone)
        this._item = value;
        this.editedItem = value ? JSON.parse(JSON.stringify(value)) : {};
        this._originalItem = value ? JSON.parse(JSON.stringify(value)) : {};
        showLog('set editedItem', this.editedItem);
    }
    get item() {
        return this._item;
    }

    get targetObjectType() {
        const name = this.editedItem.name;
        console.log('name :', name);
        const parts = name.split('_');
        console.log('parts :', parts);
        if (parts.length > 1) {
            this.selectedNodePrefix = parts[0]; // 👈 LƯU PREFIX VÀO BIẾN @track
        } else {
            this.selectedNodePrefix = null;
        }
        const prefix = this.selectedNodePrefix;
        return this.objectMap[prefix] + ' ID: ' + this.editedItem.Code;

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
        this.editedItem = { ...this.editedItem, [field]: value };
        showLog('handleInputChange', this.editedItem);
        this.dispatchEvent(new CustomEvent('nodebufferchange', {
            detail: this.editedItem,
            bubbles: true,
            composed: true
        }));
    }


    get nodeIcon() {
        return ICON_MAP[this.item?.type] || ICON_FALLBACK;
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
        const iconMap = ICON_MAP;

        // Build path from mapping
        if (mapping.CS_Product_Line__r) {
            path.push({
                type: NODE_PRODUCT_LINE,
                name: mapping.CS_Product_Line__r.Name,
                label: LABEL_NODE_PRODUCT_LINE,
                icon: iconMap[NODE_PRODUCT_LINE],
                isLast: false
            });
        }

        if (mapping.CS_Service_Type__r) {
            path.push({
                type: NODE_SERVICE_TYPE,
                name: mapping.CS_Service_Type__r.Name,
                label: LABEL_NODE_SERVICE_TYPE,
                icon: iconMap[NODE_SERVICE_TYPE],
                isLast: false
            });
        }

        if (mapping.CS_Category__r) {
            path.push({
                type: NODE_CATEGORY,
                name: mapping.CS_Category__r.Name,
                label: LABEL_NODE_CATEGORY,
                icon: iconMap[NODE_CATEGORY],
                isLast: false
            });
        }

        if (mapping.CS_Sub_Category__r) {
            path.push({
                type: NODE_SUB_CATEGORY,
                name: mapping.CS_Sub_Category__r.Name,
                label: LABEL_NODE_SUB_CATEGORY,
                icon: iconMap[NODE_SUB_CATEGORY],
                isLast: false
            });
        }

        if (mapping.CS_Action__r) {
            path.push({
                type: NODE_ACTION,
                name: mapping.CS_Action__r.Name,
                label: LABEL_NODE_ACTION,
                icon: iconMap[NODE_ACTION],
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

    get isUndoDisabled() {
        return !this.isDirty; // Nếu không bẩn (dirty) thì disable nút Undo
    }

    // Methods
    getNodeTypeLabel(nodeType) {
        const labels = {
            [NODE_PRODUCT_LINE]: LABEL_NODE_PRODUCT_LINE,
            [NODE_SERVICE_TYPE]: LABEL_NODE_SERVICE_TYPE,
            [NODE_CATEGORY]: LABEL_NODE_CATEGORY,
            [NODE_SUB_CATEGORY]: LABEL_NODE_SUB_CATEGORY,
            [NODE_ACTION]: LABEL_NODE_ACTION
        };
        return labels[nodeType] || nodeType;
    }

    handleRefresh() {
        // 1. Khôi phục ngay lập tức về dữ liệu cũ trong bộ nhớ (để UI đổi ngay)
        this.dispatchEvent(new CustomEvent('nodebufferreset', {
            detail: { idType: this.item.idType, id: this.item.id },
            bubbles: true,
            composed: true
        }));

        // 2. Logic refresh local của bạn (ví dụ gán lại editedItem = item)
        this.editedItem = { ...this.item };
        this.showLog('handleRefresh - Restored to original data');
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
            this.processMappingData(this.mappingRecords);
        }
    }

    // Error display helpers
    get hasError() {
        return this.error && this.error.body?.message;
    }

    get errorMessage() {
        return this.error?.body?.message || 'An error occurred while loading node details.';
    }
}