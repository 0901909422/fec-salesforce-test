import { LightningElement, api, track, wire } from 'lwc';
import fetchAllMasterDataMappings from '@salesforce/apex/FEC_NatureOfCaseTreeService.fetchAllMasterDataMappings';
import updateNode from '@salesforce/apex/FEC_NatureOfCaseTreeController.updateNode';
import getNocDetail from '@salesforce/apex/FEC_NatureOfCaseTreeController.getNocDetail';
import updateNocFields from '@salesforce/apex/FEC_NatureOfCaseTreeController.updateNocFields';
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
// NOC section labels
import LABEL_SECTION_NODE_INFO from '@salesforce/label/c.FEC_Section_Node_Info';
import LABEL_SECTION_NOC from '@salesforce/label/c.FEC_Section_Nature_Of_Case';
import LABEL_NOC_CODE from '@salesforce/label/c.FEC_Label_NOC_Code';
import LABEL_CUSTOMER_TYPE from '@salesforce/label/c.FEC_Label_Customer_Type';
import LABEL_USER_GROUP from '@salesforce/label/c.FEC_Label_User_Group';
import LABEL_NOC_ACTIVE from '@salesforce/label/c.FEC_Label_NOC_Active';
import LABEL_ERROR_LOAD_NOC from '@salesforce/label/c.FEC_Error_Load_NOC';
import LABEL_BUTTON_SAVE_NODE_DETAILS from '@salesforce/label/c.FEC_Button_Save_Node_Details';
import LABEL_TOAST_SUCCESS from '@salesforce/label/c.FEC_Toast_Success';
import LABEL_SUB_PROCESSES from '@salesforce/label/c.FEC_Label_Sub_Processes';
import LABEL_DO_NOT_BOTHER from '@salesforce/label/c.FEC_Label_Do_Not_Bother';
import LABEL_TRANSFER_CALL from '@salesforce/label/c.FEC_Label_Transfer_Call';
import LABEL_REMOVE_PHONE from '@salesforce/label/c.FEC_Label_Remove_Phone';
import LABEL_NOTHING_TO_SAVE from '@salesforce/label/c.FEC_Toast_Nothing_To_Save';
import { VARIANT_SUCCESS, VARIANT_ERROR, VARIANT_INFO, ICON_MAP, ICON_FALLBACK, TYPE_TEXT, OBJ_PRODUCT_TYPE, OBJ_BUSINESS_PROCESS, OBJ_CATEGORY, OBJ_SUB_CATEGORY, OBJ_SUB_CODE, PREFIX_PT, PREFIX_BP, PREFIX_CAT, PREFIX_SCAT, PREFIX_SC, OBJECT_MAP } from 'c/fecConstants';

const NODE_PRODUCT_LINE = 'Product_Line';
const NODE_SERVICE_TYPE = 'Service_Type';
const NODE_CATEGORY = 'Category';
const NODE_SUB_CATEGORY = 'Sub_Category';
const NODE_ACTION = 'Action';

const CUSTOMER_TYPE_OPTIONS = [
    { label: 'All', value: 'All' },
    { label: 'Existing', value: 'Existing' },
    { label: 'Non-existing', value: 'Non-existing' }
];

// User Group options matching Global Value Set "User_Group" (same as Live object)
const USER_GROUP_OPTIONS = [
    { label: 'CA', value: 'CA' },
    { label: 'CC', value: 'CC' },
    { label: 'CL', value: 'CL' },
    { label: 'CO', value: 'CO' },
    { label: 'CP', value: 'CP' },
    { label: 'CX', value: 'CX' },
    { label: 'DS', value: 'DS' },
    { label: 'EC', value: 'EC' },
    { label: 'F2F', value: 'F2F' },
    { label: 'IA', value: 'IA' },
    { label: 'IB', value: 'IB' },
    { label: 'IT', value: 'IT' },
    { label: 'OB', value: 'OB' },
    { label: 'OM', value: 'OM' },
    { label: 'PM', value: 'PM' },
    { label: 'QC', value: 'QC' },
    { label: 'SP', value: 'SP' },
    { label: 'TS', value: 'TS' }
];

export default class FecMasterDataItemDetail extends LightningElement {
    @track editedItem = {};
    @track loading = false;
    @track isDirty = false;

    // ── NOC Section State ──────────────────────────────────────
    @track nocData = {};
    @track nocOriginal = {};
    @track nocLoading = false;
    nocError = null;
    customerTypeOptions = CUSTOMER_TYPE_OPTIONS;
    userGroupOptions = USER_GROUP_OPTIONS;
    // Tab default

    // NOC labels
    labelSectionNodeInfo = LABEL_SECTION_NODE_INFO;
    labelSectionNoc = LABEL_SECTION_NOC;
    labelNocCode = LABEL_NOC_CODE;
    labelCustomerType = LABEL_CUSTOMER_TYPE;
    labelUserGroup = LABEL_USER_GROUP;
    labelNocActive = LABEL_NOC_ACTIVE;
    labelSaveNodeDetails = LABEL_BUTTON_SAVE_NODE_DETAILS;
    labelSubProcesses = LABEL_SUB_PROCESSES;
    labelDoNotBother = LABEL_DO_NOT_BOTHER;
    labelTransferCall = LABEL_TRANSFER_CALL;
    labelRemovePhone = LABEL_REMOVE_PHONE;

    // ==========================================================
    // HISTORY (inline collapsible per tab)
    // ==========================================================

    // Tính toán động Object API Name để truyền xuống History Component
    get historyObjectApiName() {
        const nodeType = this.item?.type;
        if (nodeType === 'Product Type' || nodeType === 'Product_Line') return 'FEC_MDM_Product_Type__c';
        if (nodeType === 'Business Process' || nodeType === 'Service_Type') return 'FEC_MDM_Business_Process__c';
        if (nodeType === 'Category') return 'FEC_MDM_Category__c';
        if (nodeType === 'Sub Category' || nodeType === 'Sub_Category') return 'FEC_MDM_Sub_Category__c';
        if (nodeType === 'Sub Code' || nodeType === 'Action') return 'FEC_MDM_Sub_Code__c';

        const prefix = this.selectedNodePrefix;
        if (prefix === 'SC' || prefix === PREFIX_SC) return 'FEC_MDM_Sub_Code__c';
        if (prefix === 'SCAT' || prefix === PREFIX_SCAT) return 'FEC_MDM_Sub_Category__c';
        if (prefix === 'CAT' || prefix === PREFIX_CAT) return 'FEC_MDM_Category__c';
        if (prefix === 'BP' || prefix === PREFIX_BP) return 'FEC_MDM_Business_Process__c';
        if (prefix === 'PT' || prefix === PREFIX_PT) return 'FEC_MDM_Product_Type__c';

        return '';
    }

    get nocHistoryObjectApiName() {
        return 'FEC_MDM_Nature_Of_Case__c';
    }

    get nocRecordId() {
        return this.item?.id || '';
    }

    get hasNocData() {
        return this.nocData && this.nocData.id;
    }

    get isNocDirty() {
        if (!this.nocData || !this.nocOriginal) return false;
        return this.nocData.customerType !== this.nocOriginal.customerType
            || this.nocData.userGroup !== this.nocOriginal.userGroup
            || String(this.nocData.active) !== String(this.nocOriginal.active)
            || String(this.nocData.doNotBother) !== String(this.nocOriginal.doNotBother)
            || String(this.nocData.transferCallToCollection) !== String(this.nocOriginal.transferCallToCollection)
            || String(this.nocData.removePhone) !== String(this.nocOriginal.removePhone);
    }

    // Convert semicolon-separated userGroup string to array for dual-listbox
    get selectedUserGroups() {
        const ug = this.nocData?.userGroup;
        if (!ug) return [];
        return ug.split(';').map(v => v.trim()).filter(v => v);
    }

    refreshHistoryPanel() {
        const historyComp = this.template.querySelector('[data-id="historyComponent"]');
        if (historyComp && historyComp.refreshData) {
            historyComp.refreshData();
        }
        const nocHistoryComp = this.template.querySelector('[data-id="nocHistoryComponent"]');
        if (nocHistoryComp && nocHistoryComp.refreshData) {
            nocHistoryComp.refreshData();
        }
    }

    // THÊM MỚI: Expose hàm này ra để Component Cha (Container) có thể gọi được
    @api
    refreshHistory() {
        this.refreshHistoryPanel();
    }
    // ==========================================================

    get isUndoDisabled() {
        return !this.isDirty && !this.isNocDirty;
    }

    /**
     * Save button enabled only when there is something to save on this tab
     */
    get isSaveDisabled() {
        return !this.isDirty && !this.isNocDirty;
    }
    error = null;

    mappingRecords = [];
    wiredMappingsResult = null;
    objectMap = OBJECT_MAP;
    selectedNodePrefix = null;
    _item = null;
    _originalItem = null;

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
        return this.item?.idType;
    }

    get nodeType() {
        return this.item?.type;
    }

    /** Customer Type chỉ cho sửa khi node là Product Type (root) */
    get isCustomerTypeDisabled() {
        const t = this.nodeType;
        return t !== NODE_PRODUCT_LINE && t !== OBJ_PRODUCT_TYPE && t !== 'Product Type';
    }

    @wire(fetchAllMasterDataMappings)
    wiredMappings(result) {
        this.wiredMappingsResult = result;
        if (result.data) {
            this.processMappingData(result.data);
        } else if (result.error) {
            this.error = result.error;
            console.error('Error loading mappings:', result.error);
        }
    }

    processMappingData(mappings) {
        if (!this.nodeId || !this.nodeType) {
            this.mappingRecords = [];
            return;
        }

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

        // Lấy các trường có thể chỉnh sửa để so sánh
        const getEditableFields = (obj) => {
            if (!obj) return {};
            return {
                Alias: obj.Alias,
                NameEN: obj.NameEN,
                nameVN: obj.nameVN,
                PosOrder: obj.PosOrder,
                Status: obj.Status
            };
        };

        const incomingEditableFieldsStr = JSON.stringify(getEditableFields(value));

        if (incomingId && incomingId === currentId) {
            // Nếu parent đẩy xuống data cũ (giống hệt data parent đã đẩy lần trước) thì bỏ qua
            // để bảo vệ data đã được save ở detail panel không bị reset về quá khứ do parent không refresh.
            if (this._lastParentEditableFieldsStr === incomingEditableFieldsStr) {
                console.log('[DEBUG][item setter] Parent passed identical editable fields, ignoring stale data.');
                return;
            }
            this._lastParentEditableFieldsStr = incomingEditableFieldsStr;

            // Check if actual server data changed (e.g., after Save All)
            const isValueChanged = incomingEditableFieldsStr !== JSON.stringify(getEditableFields(this._item));

            if (isValueChanged) {
                console.log('[DEBUG][item setter] Server data updated, updating _originalItem to serve as new baseline for Undo');
                this._item = value;

                // Cập nhật lại bản gốc từ server để Undo
                this._originalItem = value ? JSON.parse(JSON.stringify(value)) : {};

                if (!this.isDirty) {
                    this.editedItem = value ? JSON.parse(JSON.stringify(value)) : {};
                } else {
                    // Nếu đang gõ mà server lưu xong trả về, thì mình kiểm tra lại isDirty
                    const orig = this._originalItem || {};
                    const curr = this.editedItem || {};
                    let dirty = false;
                    for (let key in curr) {
                        if (curr[key] != orig[key]) {
                            dirty = true;
                            break;
                        }
                    }
                    this.isDirty = dirty;
                }
            } else {
                console.log('[DEBUG][item setter] No value change from server, preserving current state.');
            }
            return;
        }

        this._lastParentEditableFieldsStr = incomingEditableFieldsStr;
        this._item = value;
        this.editedItem = value ? JSON.parse(JSON.stringify(value)) : {};
        this._originalItem = value ? JSON.parse(JSON.stringify(value)) : {};
        this.isDirty = false;
        console.log('[DEBUG][item setter] New node → reset. _originalItem:', JSON.stringify(this._originalItem));

        const name = this.editedItem?.name || '';
        const parts = name ? name.split('_') : [];
        this.selectedNodePrefix = parts.length > 1 ? parts[0] : null;

        // Load NOC data for the new node
        this.loadNocData();
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
        let friendlyLabel = label;
        if (prefix === PREFIX_SC) friendlyLabel = OBJ_SUB_CODE;
        else if (prefix === PREFIX_SCAT) friendlyLabel = OBJ_SUB_CATEGORY;
        else if (prefix === PREFIX_CAT) friendlyLabel = OBJ_CATEGORY;
        else if (prefix === PREFIX_BP) friendlyLabel = OBJ_BUSINESS_PROCESS;
        else if (prefix === PREFIX_PT) friendlyLabel = OBJ_PRODUCT_TYPE;

        const code = this.editedItem?.Code || '';
        return (friendlyLabel ? friendlyLabel + ' ID: ' : '') + code;
    }

    @api
    validateForm() {
        const inputs = [...this.template.querySelectorAll('lightning-input')];
        let allValid = true;

        inputs.forEach(inputCmp => {
            inputCmp.reportValidity(); // Ép UI hiển thị màu đỏ nếu có lỗi
            if (!inputCmp.checkValidity()) {
                allValid = false;
            }
        });

        console.log('[DEBUG][validateForm] Result:', allValid);
        return allValid;
    }

    handleSubmit(event) {
        if (!this.validateForm()) {
            this.showToast(LABEL_PLEASE_FILL_ALL, '', VARIANT_ERROR);
            console.error('[DEBUG][handleSubmit] Validation failed.');
            return;
        }

        const updateData = { ...this.editedItem };
        showLog('handleSubmit updateData', updateData);
        updateNode({ updateData })
            .then(() => {
                this.showToast(LABEL_UPDATED_SUCCESS, '', VARIANT_SUCCESS);
                showLog('handleSubmit SUCCESS', 'Bản ghi đã được lưu thành công');

                this.markAsSaved();

                this.dispatchEvent(new CustomEvent('save', {
                    bubbles: true,
                    composed: true
                }));
                // Bắt buộc gọi lại History panel sau khi save
                this.refreshHistoryPanel();
            })
            .catch(error => {
                this.showToast(LABEL_ERROR, error.body?.message || error.message, VARIANT_ERROR);
                showLog('handleSubmit ERROR', error);
            })
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;

        // Validation for whitespace-only input
        if (event.target.type !== 'checkbox' && typeof value === 'string') {
            if (value.length > 0 && value.trim().length === 0) {
                event.target.setCustomValidity('Vui lòng không chỉ nhập khoảng trắng');
            } else {
                event.target.setCustomValidity('');
            }
            event.target.reportValidity();
        }

        this.editedItem = JSON.parse(JSON.stringify({ ...this.editedItem, [field]: value }));

        const orig = this._originalItem || {};
        const curr = this.editedItem || {};

        // Check if ANY of the fields have changed
        let dirty = false;
        for (let key in curr) {
            if (curr[key] != orig[key]) {
                dirty = true;
                break;
            }
        }
        this.isDirty = dirty;

        console.log('[DEBUG][handleInputChange] isDirty evaluated to:', this.isDirty, 'Field changed:', field);

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
        if (record?.Id) fields.push({ label: LABEL_RECORD_ID, value: record.Id, type: TYPE_TEXT, isStatus: false });
        if (record?.Name) fields.push({ label: LABEL_NAME_EN, value: record.Name, type: TYPE_TEXT, isStatus: false });
        if (record?.NameVN__c) fields.push({ label: LABEL_NAME_VN_DISPLAY, value: record.NameVN__c, type: TYPE_TEXT, isStatus: false });
        fields.push({ label: LABEL_TYPE_DISPLAY, value: this.nodeTypeLabel, type: TYPE_TEXT, isStatus: false });
        return fields;
    }

    get hasHierarchyPath() {
        return this.hierarchyPath && this.hierarchyPath.length > 0;
    }

    get hierarchyPath() {
        if (!this.item || !this.mappingRecords.length) return [];
        const mapping = this.mappingRecords[0];
        if (!mapping) return [];
        const path = [];
        if (mapping.CS_Product_Line__r) path.push({ type: NODE_PRODUCT_LINE, name: mapping.CS_Product_Line__r.Name, label: LABEL_NODE_PRODUCT_LINE, icon: ICON_MAP[NODE_PRODUCT_LINE] || ICON_FALLBACK, isLast: false });
        if (mapping.CS_Service_Type__r) path.push({ type: NODE_SERVICE_TYPE, name: mapping.CS_Service_Type__r.Name, label: LABEL_NODE_SERVICE_TYPE, icon: ICON_MAP[NODE_SERVICE_TYPE] || ICON_FALLBACK, isLast: false });
        if (mapping.CS_Category__r) path.push({ type: NODE_CATEGORY, name: mapping.CS_Category__r.Name, label: LABEL_NODE_CATEGORY, icon: ICON_MAP[NODE_CATEGORY] || ICON_FALLBACK, isLast: false });
        if (mapping.CS_Sub_Category__r) path.push({ type: NODE_SUB_CATEGORY, name: mapping.CS_Sub_Category__r.Name, label: LABEL_NODE_SUB_CATEGORY, icon: ICON_MAP[NODE_SUB_CATEGORY] || ICON_FALLBACK, isLast: false });
        if (mapping.CS_Action__r) path.push({ type: NODE_ACTION, name: mapping.CS_Action__r.Name, label: LABEL_NODE_ACTION, icon: ICON_MAP[NODE_ACTION] || ICON_FALLBACK, isLast: false });
        if (path.length > 0) path[path.length - 1].isLast = true;
        return path;
    }

    get hasMappings() { return this.mappingRecords && this.mappingRecords.length > 0; }
    get hasChildNodes() { return this.childNodes && this.childNodes.length > 0; }
    get childNodes() { return this.item?.items || []; }

    get childNodesTitle() {
        const childTypeMap = {
            [NODE_PRODUCT_LINE]: LABEL_CHILD_SERVICE_TYPES,
            [NODE_SERVICE_TYPE]: LABEL_CHILD_CATEGORIES,
            [NODE_CATEGORY]: LABEL_CHILD_SUB_CATEGORIES,
            [NODE_SUB_CATEGORY]: LABEL_CHILD_ACTIONS
        };
        return childTypeMap[this.item?.type] || 'Child Nodes';
    }

    get totalMappings() { return this.mappingRecords?.length || 0; }
    get directChildren() { return this.childNodes?.length || 0; }
    get totalDescendants() {
        const countDescendants = (nodes) => {
            if (!nodes || !nodes.length) return 0;
            let count = nodes.length;
            nodes.forEach(node => { count += countDescendants(node.items); });
            return count;
        };
        return countDescendants(this.childNodes);
    }

    getNodeTypeLabel(nodeType) {
        const labels = {
            [NODE_PRODUCT_LINE]: LABEL_NODE_PRODUCT_LINE,
            [NODE_SERVICE_TYPE]: LABEL_NODE_SERVICE_TYPE,
            [NODE_CATEGORY]: LABEL_NODE_CATEGORY,
            [NODE_SUB_CATEGORY]: LABEL_NODE_SUB_CATEGORY,
            [NODE_ACTION]: LABEL_NODE_ACTION
        };
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

    // ── NOC Data Methods ──────────────────────────────────────
    async loadNocData() {
        const nocId = this._item?.id;
        if (!nocId) {
            this.nocData = {};
            this.nocOriginal = {};
            return;
        }
        this.nocLoading = true;
        this.nocError = null;
        try {
            const result = await getNocDetail({ nocId });
            this.nocData = {
                ...result,
                active: result.active === 'true',
                doNotBother: result.doNotBother === 'true',
                transferCallToCollection: result.transferCallToCollection === 'true',
                removePhone: result.removePhone === 'true'
            };
            this.nocOriginal = JSON.parse(JSON.stringify(this.nocData));
        } catch (error) {
            this.nocError = error;
            this.nocData = {};
            this.nocOriginal = {};
            console.error('[loadNocData] ERROR:', error);
            this.showToast(LABEL_ERROR, LABEL_ERROR_LOAD_NOC, VARIANT_ERROR);
        } finally {
            this.nocLoading = false;
        }
    }

    handleNocInputChange(event) {
        const field = event.target.dataset.nocField;
        let value;
        if (event.target.type === 'checkbox' || event.target.type === 'toggle') {
            value = event.target.checked;
        } else if (field === 'userGroup') {
            // dual-listbox returns array — join with semicolon to match Salesforce multi-select format
            value = event.detail.value.join(';');
        } else {
            value = event.target.value;
        }

        this.nocData = { ...this.nocData, [field]: value };

        // Dispatch buffer change so parent tracks NOC dirty state too
        this.dispatchEvent(new CustomEvent('nodebufferchange', {
            detail: { ...this.editedItem, _nocData: this.nocData },
            bubbles: true,
            composed: true
        }));
    }

    /**
     * @description Save NOC fields independently (called by Save All flow from parent)
     */
    @api
    async saveNocFields() {
        if (!this.isNocDirty || !this.nocData.id) return;
        try {
            await updateNocFields({
                nocId: this.nocData.id,
                customerType: this.nocData.customerType || '',
                userGroup: this.nocData.userGroup || '',
                isActive: this.nocData.active,
                doNotBother: this.nocData.doNotBother,
                transferCallToCollection: this.nocData.transferCallToCollection,
                removePhone: this.nocData.removePhone,
                nodeId: this.editedItem?.idType || null,
                nodeType: this.editedItem?.type || null
            });
            // Update original to match saved state
            this.nocOriginal = JSON.parse(JSON.stringify(this.nocData));
        } catch (error) {
            throw error; // Let parent handle the error
        }
    }

    handleRefresh() {
        // 1. Tự Component Con khôi phục về bản gốc (A1)
        this.editedItem = JSON.parse(JSON.stringify(this._originalItem));
        this.isDirty = false;

        // Reset NOC data to original
        this.nocData = JSON.parse(JSON.stringify(this.nocOriginal));

        // 2. Chỉ báo cho Cha biết idType để Cha xóa dòng đó khỏi pendingChanges
        this.dispatchEvent(new CustomEvent('nodebufferreset', {
            detail: { idType: this.item?.idType },
            bubbles: true,
            composed: true
        }));
        showLog('handleRefresh - Restored to original data', this.editedItem);
    }

    @api
    refreshData() {
        this.handleRefresh();
    }

    // ==========================================================
    // THÊM MỚI: Hàm để Component Cha gọi khi đã Save thành công
    // ==========================================================
    @api
    markAsSaved() {
        // Lấy dữ liệu vừa edit đè lên dữ liệu gốc để xác nhận đã lưu
        const updatedItem = { ...this._item, ...this.editedItem };
        this._originalItem = JSON.parse(JSON.stringify(updatedItem));
        this._item = JSON.parse(JSON.stringify(updatedItem));
        this.editedItem = JSON.parse(JSON.stringify(updatedItem));

        // Mark NOC as saved too
        if (this.nocData && this.nocData.id) {
            this.nocOriginal = JSON.parse(JSON.stringify(this.nocData));
        }

        // Tắt trạng thái thay đổi -> Nút Undo sẽ lập tức bị Disable
        this.isDirty = false;
        showLog('markAsSaved', 'Đã cập nhật bản gốc và disable nút Undo');
    }

    /**
     * Save BOTH Node fields and NOC fields (Sub-Processes, User Group, etc.)
     * in this tab at once. Triggered by the local "Save Node Details" button.
     */
    async handleSaveNodeDetails() {
        if (!this.isDirty && !this.isNocDirty) {
            this.showToast('', LABEL_NOTHING_TO_SAVE, VARIANT_INFO);
            return;
        }
        if (!this.validateForm()) {
            this.showToast(LABEL_ERROR, LABEL_PLEASE_FILL_ALL, VARIANT_ERROR);
            return;
        }
        this.loading = true;
        try {
            // 1. Save node-level fields (Alias/NameEN/NameVN/PosOrder/Status) if dirty
            if (this.isDirty) {
                await updateNode({ updateData: { ...this.editedItem } });
            }
            // 2. Save NOC-level fields (Customer Type / Active / Sub-Processes / User Group) if dirty
            if (this.isNocDirty && this.nocData && this.nocData.id) {
                await updateNocFields({
                    nocId: this.nocData.id,
                    customerType: this.nocData.customerType || '',
                    userGroup: this.nocData.userGroup || '',
                    isActive: this.nocData.active,
                    doNotBother: this.nocData.doNotBother,
                    transferCallToCollection: this.nocData.transferCallToCollection,
                    removePhone: this.nocData.removePhone,
                    nodeId: this.editedItem?.idType || null,
                    nodeType: this.editedItem?.type || null
                });
            }
            this.showToast(LABEL_TOAST_SUCCESS, LABEL_UPDATED_SUCCESS, VARIANT_SUCCESS);
            this.markAsSaved();
            // Notify parent so tree / pending changes are refreshed
            this.dispatchEvent(new CustomEvent('save', { bubbles: true, composed: true }));
            this.refreshHistoryPanel();
        } catch (error) {
            this.showToast(LABEL_ERROR, error.body?.message || error.message, VARIANT_ERROR);
            showLog('handleSaveNodeDetails ERROR', error);
        } finally {
            this.loading = false;
        }
    }

    connectedCallback() {
        if (this.item?.id) {
            const mappings = this.wiredMappingsResult?.data || [];
            this.processMappingData(mappings);
        }
    }

    get hasError() {
        return !!(this.error && (this.error.body?.message || this.error.message));
    }

    get errorMessage() {
        return this.error?.body?.message || this.error?.message || 'An error occurred while loading node details.';
    }

    showToast(title, message, variant) {
        // Tái sử dụng CustomEvent nếu bạn dùng showToast ở các component cha, 
        // hoặc import ShowToastEvent nếu muốn dùng Toast gốc.
        const event = new CustomEvent('showtoast', {
            detail: { title, message, variant },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(event);
    }
}