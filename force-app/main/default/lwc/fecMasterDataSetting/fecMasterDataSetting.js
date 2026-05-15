import { api, LightningElement, track, wire } from 'lwc';
import getMasterDataSettings from '@salesforce/apex/FEC_MasterDataSettingController.getMasterDataSettings';
import getMasterDataSettingsFresh from '@salesforce/apex/FEC_MasterDataSettingController.getMasterDataSettingsFresh';
import deleteMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.deleteRecord';
import deleteFraudIntegrationMapping from '@salesforce/apex/FEC_MasterDataSettingController.deleteFraudIntegrationMapping';
import saveMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.saveMasterDataSetting';
import getUserTypeIdByName from '@salesforce/apex/FEC_MasterDataSettingController.getUserTypeIdByName';
import getUserRoles from '@salesforce/apex/FEC_MasterDataSettingController.getUserRoles';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { refreshApex } from '@salesforce/apex';
import LABEL_COL_CHANNEL from '@salesforce/label/c.FEC_Col_Channel';
import LABEL_COL_APPLICABLE_ROLE from '@salesforce/label/c.FEC_Col_Applicable_Role';
import LABEL_COL_PROPERTY_NAME from '@salesforce/label/c.FEC_Col_Property_Name';
import LABEL_COL_SECTION from '@salesforce/label/c.FEC_Col_Section';
import LABEL_COL_ORDER from '@salesforce/label/c.FEC_Col_Order';
import LABEL_COL_STATUS from '@salesforce/label/c.FEC_Col_Status';
import LABEL_BUTTON_NEW_SETTING from '@salesforce/label/c.FEC_Button_New_Setting';
import LABEL_ACTION_EDIT from '@salesforce/label/c.FEC_Action_Edit';
import LABEL_ACTION_DELETE from '@salesforce/label/c.FEC_Action_Delete';
import LABEL_CONFIRM_DELETE_PROPERTY from '@salesforce/label/c.FEC_Confirm_Delete_Property';
import LABEL_TOAST_DELETED_SUCCESS from '@salesforce/label/c.FEC_Toast_Deleted_Success';
import LABEL_TOAST_SAVE_SUCCESS from '@salesforce/label/c.FEC_Toast_Save_Success';
import LABEL_TOAST_SUCCESS from '@salesforce/label/c.FEC_Toast_Success';
import LABEL_TOAST_UPDATE_STATUS_SUCCESS from '@salesforce/label/c.FEC_Toast_Update_Status_Success';
import LABEL_LABEL_READONLY from '@salesforce/label/c.FEC_Label_ReadOnly';
import LABEL_LABEL_MANDATORY from '@salesforce/label/c.FEC_Label_Mandatory';
import LABEL_LABEL_ACTION from '@salesforce/label/c.FEC_Label_Action';
import LABEL_TAB_PROPERTY_CONFIGURATION from '@salesforce/label/c.FEC_Tab_Property_Configuration';
import LABEL_TAB_FRAUD_INTEGRATION from '@salesforce/label/c.FEC_Tab_Fraud_Integration_Mapping';
import LABEL_MASTERDATA_TITLE from '@salesforce/label/c.FEC_MasterData_Title';
import LABEL_TOAST_ERROR from '@salesforce/label/c.FEC_Toast_Error';
import LABEL_DEFAULT_CHANNEL_NAME from '@salesforce/label/c.FEC_Default_Channel_Name';
import LABEL_MODAL_NEW_PROPERTY_TITLE from '@salesforce/label/c.FEC_Modal_New_Property_Title';
import LABEL_MODAL_EDIT_PROPERTY_TITLE from '@salesforce/label/c.FEC_Modal_Edit_Property_Title';
import LABEL_BUTTON_ADD_INTEGRATION from '@salesforce/label/c.FEC_Button_Add_Integration';
import LABEL_SEARCH_PLACEHOLDER from '@salesforce/label/c.FEC_Search_Placeholder';
import LABEL_WARNING_DELETE_NEW_ONLY from '@salesforce/label/c.FEC_Warning_Delete_New_Only';
import LABEL_CONFIRM_DELETE_TITLE_GENERIC from '@salesforce/label/c.FEC_Confirm_Delete_Title';
import LABEL_CONFIRM_DELETE_FRAUD_MSG from '@salesforce/label/c.FEC_Confirm_Delete_Fraud_Mapping_Msg';
import LABEL_ERROR_DELETE_FRAUD from '@salesforce/label/c.FEC_Error_Delete_Fraud_Mapping';
import LABEL_COL_FIELD_API_NAME from '@salesforce/label/c.FEC_Col_Field_API_Name';
import LABEL_COL_FIELD_LABEL_NAME from '@salesforce/label/c.FEC_Col_Field_Label_Name';
import LABEL_COL_FIELD_OBJECT_NAME from '@salesforce/label/c.FEC_Label_Field_Object_Name';
import LABEL_COL_SUB_SECTION from '@salesforce/label/c.FEC_Col_Sub_Section';
import LABEL_COL_SUB_SEC_ORDER from '@salesforce/label/c.FEC_Col_Sub_Sec_Order';
import LABEL_COL_SUB_SEC_LAYOUT from '@salesforce/label/c.FEC_Col_Sub_Sec_Layout';
import LABEL_COL_SUB_SEC_FIELD from '@salesforce/label/c.FEC_Col_Sub_Sec_Field';
import LABEL_COL_EDITABLE_ROLE from '@salesforce/label/c.FEC_Label_Editable_Role';
import LABEL_COL_PROCESS_STATUS from '@salesforce/label/c.FEC_Col_Process_Status';
import LABEL_LABEL_ACTIVE from '@salesforce/label/c.FEC_Label_Active';
import LABEL_LABEL_INACTIVE from '@salesforce/label/c.FEC_Label_Inactive';
import LABEL_TOOLTIP_CLICK_TO_DEACTIVATE from '@salesforce/label/c.FEC_Tooltip_Click_To_Deactivate';
import LABEL_TOOLTIP_CLICK_TO_ACTIVATE from '@salesforce/label/c.FEC_Tooltip_Click_To_Activate';
import LABEL_BUTTON_CANCEL from '@salesforce/label/c.FEC_Button_Cancel';
import LABEL_BUTTON_SAVE from '@salesforce/label/c.FEC_Button_Save';
import { FIELD_SECTION, FIELD_FIELD_ORDER_DISPLAY, TYPE_TEXT, TYPE_BOOLEAN, STATUS_NEW, STATUS_UPDATE, CUST_TYPE_NON_EXISTING, CUST_TYPE_EXISTING, ICON_CHEVRON_RIGHT, ICON_CHEVRON_DOWN, MASTER_DATA_SETTING_COLUMNS, STATUS_CLASS_BLUE, STATUS_CLASS_RED, STATUS_CLASS_YELLOW, CUST_CLASS_ALL, CUST_CLASS_NON_EXISTING, CUST_CLASS_EXISTING, DEFAULT_SORT_FIELD, DEFAULT_SORT_DIRECTION_ASC, DEFAULT_SORT_DIRECTION_DESC, FIELD_ADDITIONAL_FIELD_NAME, FIELD_OBJECT_FRAUD_INTEGRATION, ICON_ARROW_UP, ICON_ARROW_DOWN, CSS_BASE_SML_LEFT, FIELD_CHANNEL, FIELD_APPLICABLE_ROLE, VARIANT_SUCCESS, VARIANT_ERROR, FIELD_PROCESS_CHANGE_STATUS, FIELD_SUB_SECTION, FIELD_SUB_SECTION_ORDER, DEFAULT_CHANNEL_INTEGRATION_CODE } from 'c/fecConstants';

// Default labels for missing integration data
const LABEL_DEFAULT_PRODUCT_LINE = 'N/A';
const LABEL_DEFAULT_SERVICE_TYPE = 'N/A';
const LABEL_DEFAULT_CATEGORY = 'N/A';
const LABEL_DEFAULT_SUB_CATEGORY = 'N/A';

// Expose labels for template
const labelCardTitle = LABEL_MASTERDATA_TITLE;
const labelNewSetting = LABEL_BUTTON_NEW_SETTING;
const labelColChannel = LABEL_COL_CHANNEL;
const labelColApplicableRole = LABEL_COL_APPLICABLE_ROLE;
const labelColPropertyName = LABEL_COL_PROPERTY_NAME;
const labelColSection = LABEL_COL_SECTION;
const labelColOrder = LABEL_COL_ORDER;

const ACTIONS = [
    { label: LABEL_ACTION_EDIT, name: 'edit' },
    { label: LABEL_ACTION_DELETE, name: 'delete' }
];

const COLUMNS = MASTER_DATA_SETTING_COLUMNS;

/**
 * @description LWC Component quản lý cấu hình Master Data Setting cho CSM.
 * @date 2026-01-02
 * @author DAT NGO
 */
export default class FecMasterDataSetting extends LightningElement {
    @track fraudDataList;
    isLoading = false;
    isModalOpen = false;
    isIntegrationAdd = false;
    recordIdForEdit;
    selectedMappingId;
    ChangeStatus;
    _item;
    @track masterDataList = [];
    @track processedData = [];
    @track processedDataFraud = [];
    stageId;
    currentNatureOfCaseId;
    currentNatureOfCaseCode;
    FEC_Customer_Type;
    userTypeName;
    nocUserGroup = '';
    @track selectedRecord = {};
    recordIdForIntegration;
    integrationModeEnabled = false;
    @track integrationFormData = {
        selectedRoles: [],
        section: 'Case Information',
        subSection: 'Fraud Info',
        fieldStatus: true
    };
    @track roleOptions = [];
    searchTermProperty = '';
    roleSearchTerm = '';
    isRoleDropdownOpen = false;

    columns = COLUMNS;
    // labels for template use
    labelCardTitle = labelCardTitle;
    labelNewSetting = labelNewSetting;
    labelColChannel = labelColChannel;
    labelColApplicableRole = labelColApplicableRole;
    labelColPropertyName = labelColPropertyName;
    labelColSection = labelColSection;
    labelColOrder = labelColOrder;
    labelReadOnly = LABEL_LABEL_READONLY;
    labelMandatory = LABEL_LABEL_MANDATORY;
    labelAction = LABEL_LABEL_ACTION;
    labelTabPropertyConfiguration = LABEL_TAB_PROPERTY_CONFIGURATION;
    labelTabFraudIntegration = LABEL_TAB_FRAUD_INTEGRATION;
    labelActionEdit = LABEL_ACTION_EDIT;
    labelActionDelete = LABEL_ACTION_DELETE;
    labelColStatus = LABEL_COL_STATUS;
    // additional labels
    labelDefaultChannel = LABEL_DEFAULT_CHANNEL_NAME;
    labelModalNewProperty = LABEL_MODAL_NEW_PROPERTY_TITLE;
    labelSearchPlaceholder = LABEL_SEARCH_PLACEHOLDER;
    labelColFieldApiName = LABEL_COL_FIELD_API_NAME;
    labelColFieldLabelName = LABEL_COL_FIELD_LABEL_NAME;
    labelColFieldObjectName = LABEL_COL_FIELD_OBJECT_NAME;
    labelColSubSection = LABEL_COL_SUB_SECTION;
    labelColSubSecOrder = LABEL_COL_SUB_SEC_ORDER;
    labelColSubSecLayout = LABEL_COL_SUB_SEC_LAYOUT;
    labelColSubSecField = LABEL_COL_SUB_SEC_FIELD;
    labelColEditableRole = LABEL_COL_EDITABLE_ROLE;
    labelColProcessStatus = LABEL_COL_PROCESS_STATUS;
    defaultChannelCode = DEFAULT_CHANNEL_INTEGRATION_CODE;
    labelModalEditProperty = LABEL_MODAL_EDIT_PROPERTY_TITLE;
    labelAddIntegration = LABEL_BUTTON_ADD_INTEGRATION;
    labelActive = LABEL_LABEL_ACTIVE;
    labelInactive = LABEL_LABEL_INACTIVE;
    labelTooltipDeactivate = LABEL_TOOLTIP_CLICK_TO_DEACTIVATE;
    labelTooltipActivate = LABEL_TOOLTIP_CLICK_TO_ACTIVATE;
    labelActionCancel = LABEL_BUTTON_CANCEL;
    labelActionSave = LABEL_BUTTON_SAVE;

    wiredMasterDataResult;
    wiredFraudResult;

    sortedBy = DEFAULT_SORT_FIELD;
    sortDirection = DEFAULT_SORT_DIRECTION_ASC;
    modalTitle = '';
    
    get modalIconName() {
        return this.recordIdForEdit ? 'utility:edit' : 'utility:add';
    }

    // ==========================================================
    // KHỐI CODE HISTORY
    // ==========================================================
    isHistoryVisible = false;
    isFlowStagesVisible = true;

    get mainPanelSize() { return this.isHistoryVisible ? 9 : 12; }
    get toggleHistoryIcon() { return this.isHistoryVisible ? 'utility:close' : 'utility:history'; }
    get toggleHistoryLabel() { return this.isHistoryVisible ? 'Đóng Lịch sử' : 'Xem Lịch sử'; }
    get toggleButtonVariant() { return this.isHistoryVisible ? 'neutral' : 'brand-outline'; }

    handleToggleHistory() {
        this.isHistoryVisible = !this.isHistoryVisible;
        if (this.isHistoryVisible && this._pendingHistoryRefresh) {
            this._pendingHistoryRefresh = false;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => { this.refreshHistoryPanel(); }, 200);
        }
    }

    refreshHistoryPanel() {
        // Refresh all history components across all tabs
        const historySelectors = [
            '[data-id="propertyHistory"]',
            '[data-id="fraudHistory"]',
            '[data-id="decisionEngineHistory"]',
            '[data-id="propertiesMappingHistory"]'
        ];
        let found = false;
        for (const selector of historySelectors) {
            const comp = this.template.querySelector(selector);
            if (comp && typeof comp.refreshData === 'function') {
                comp.refreshData();
                found = true;
            }
        }
        if (!found) {
            this._pendingHistoryRefresh = true;
        }
    }
    // ==========================================================

    @api
    get item() {
        return this._item;
    }
    set item(value) {
        this._item = value;
        console.log('[MasterDataSetting] item received:', JSON.stringify(value));
        if (value && value.id) {
            this.currentNatureOfCaseId = value.id;
            this.currentNatureOfCaseCode = value.Code || value.name || '';
            this.FEC_Customer_Type = value.FEC_Customer_Type;
            this.nocUserGroup = value.FEC_User_Group || '';
            this.stageId = null;
            this.processedData = []; // Clear data cũ ngay lập tức
            
            // Truyền trực tiếp FEC_Customer_Type (Name) sang child
            // Child sẽ tự tìm ID tương ứng từ dropdown options
            if (this.FEC_Customer_Type) {
                this.userTypeName = this.FEC_Customer_Type.toUpperCase();
            }
        }
    }

    get hasFraudData() {
        return this.fraudDataList && this.fraudDataList.length > 0;
    }

    get hasPropertyData() {
        return this.processedData && this.processedData.length > 0;
    }

    // Boolean getters for history component is-integration attribute
    get isPropertyIntegration() { return false; }
    get isFraudIntegration() { return true; }

    // Business Process Id for Decision Engine history (extracted from item.idType)
    get currentBusinessProcessId() {
        if (!this._item) return null;
        const rawType = (this._item.type || '').replace(/\s+/g, '');
        const nodeType = rawType || 'BusinessProcess';
        const leafTypes = new Set(['Stage', 'Category', 'SubCategory', 'SubCode']);
        if (leafTypes.has(nodeType)) return null;
        return this._item.idType || null;
    }

    handleDecisionEngineChanged() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const hist = this.template.querySelector('[data-id="decisionEngineHistory"]');
            if (hist && typeof hist.refreshData === 'function') {
                hist.refreshData();
            }
        }, 500);
    }

    handlePropertiesMappingChanged() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const hist = this.template.querySelector('[data-id="propertiesMappingHistory"]');
            if (hist && typeof hist.refreshData === 'function') {
                hist.refreshData();
            }
        }, 500);
    }

    // Record Ids for Property Configuration history (non-integration)
    get propertyRecordIds() {
        if (!this.masterDataList) return [];
        return this.masterDataList
            .filter(r => !r.FEC_Data_Integration_Mapping__c)
            .map(r => r.Id);
    }

    // Record Ids for Fraud Integration history (integration)
    get fraudRecordIds() {
        if (!this.fraudDataList) return [];
        return this.fraudDataList.map(r => r.Id);
    }

    // Tab 1: Properties
    @wire(getMasterDataSettings, {
        selectedNodeId: '$currentNatureOfCaseId',
        selectedStageId: '$stageId',
        isIntegration: false
    })
    wiredProperties(result) {
        this.wiredMasterDataResult = result;
        const { data, error } = result;

        if (data) {
            this.masterDataList = data;
            
            // XỬ LÝ DATA NGAY TẠI ĐÂY (Thay thế cho Getter)
            this.processedData = data.map((row, index) => {
                const rowStatus = row.Process_Change_Status__c || '';
                
                // 1. Xác định màu icon Status
                let statusClass = STATUS_CLASS_BLUE;
                if (rowStatus === STATUS_NEW) statusClass = STATUS_CLASS_RED;
                else if (rowStatus === STATUS_UPDATE) statusClass = STATUS_CLASS_YELLOW;

                // 2. Xác định màu icon Customer Type
                let custTypeClass = CUST_CLASS_ALL;
                if (this.FEC_Customer_Type === CUST_TYPE_NON_EXISTING) custTypeClass = CUST_CLASS_NON_EXISTING;
                else if (this.FEC_Customer_Type === CUST_TYPE_EXISTING) custTypeClass = CUST_CLASS_EXISTING;

                return {
                    ...row,
                    rowNumber: index + 1,
                    FEC_Additional_Field_Name: row.FEC_Additional_Field__r ? row.FEC_Additional_Field__r.Name : '',
                    FEC_Channel_Name_Name: row.FEC_MDM_Channel__r ? row.FEC_MDM_Channel__r.Name : '',
                    FEC_Applicable_Role__c: row.FEC_Applicable_Role__c || '',
                    FEC_Section__c: row.FEC_Section__c || '',
                    FEC_Sub_Section__c: row.FEC_Sub_Section__c || '',
                    FEC_Sub_Section_Order__c: row.FEC_Sub_Section_Order__c || 0,
                    FEC_Sub_Section_Layout__c: row.FEC_Sub_Section_Layout__c || 0,
                    FEC_Sub_Section_Field_Layout__c: row.FEC_Sub_Section_Field_Layout__c || 0,
                    computedColumnCount: row.FEC_Sub_Section_Field_Layout__c > 0 ? Math.floor(12 / row.FEC_Sub_Section_Field_Layout__c) : 4,
                    FEC_Field_Order_Display__c: row.FEC_Field_Order_Display__c || 0,
                    FEC_Field_Status__c: row.FEC_Field_Status__c || false,
                    FEC_Field_ReadOnly__c: row.FEC_Field_ReadOnly__c || false,
                    FEC_Field_Mandatory__c: row.FEC_Field_Mandatory__c || false,
                    FEC_Field_Editable__c: row.FEC_Field_Editable__c || false,
                    FEC_Field_Masking__c: row.FEC_Field_Masking__c || false,
                    FEC_Masking_Type__c: row.FEC_Masking_Type__c || '',
                    FEC_Field_Reverted__c: row.FEC_Field_Reverted__c || false,
                    FEC_Editable_Role__c: row.FEC_Editable_Role__c || '',
                    dynamicIconClass: `${CSS_BASE_SML_LEFT} ${statusClass}`,
                    customerIconClass: `${CSS_BASE_SML_LEFT} ${custTypeClass}`
                };
            });
            
            // Reset sort to default when new data arrives
            this.sortedBy = DEFAULT_SORT_FIELD;
            this.sortDirection = DEFAULT_SORT_DIRECTION_ASC;
            
            // Sort the data
            this.sortData(this.sortedBy, this.sortDirection);
            
            // Store full dataset for search filtering
            this._allProcessedData = [...this.processedData];
            
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error;
            console.error('[wiredProperties] ERROR:', error);
            this.showToast(LABEL_TOAST_ERROR, 'Load Properties failed', VARIANT_ERROR);
            this.isLoading = false;
        }
    }

    // Tab 2: Fraud
    @wire(getMasterDataSettings, {
        selectedNodeId: '$currentNatureOfCaseId',
        selectedStageId: '$stageId',
        isIntegration: true
    })
    wiredFraud(result) {
        this.wiredFraudResult = result;
        const { data, error } = result;
        console.log('[wiredFraud] CALLED. data length:', data ? data.length : 'null/undefined', 'error:', error);

        if (data) {
            console.log('[wiredFraud] Data received:', data.length, 'records');
            // Luôn gán lại giá trị kể cả khi data là danh sách rỗng []
            this.fraudDataList = this.processMasterData(data);
            console.log('[wiredFraud] fraudDataList length:', this.fraudDataList ? this.fraudDataList.length : 'null');
            console.log('[wiredFraud] hasFraudData:', this.hasFraudData);
            this.processedDataFraud = this.fraudDataList.map(row => {
                // 1. Xác định màu icon Status
                let statusClass = STATUS_CLASS_BLUE;
                if (row.Process_Change_Status__c === STATUS_NEW) statusClass = STATUS_CLASS_RED;
                else if (row.Process_Change_Status__c === STATUS_UPDATE) statusClass = STATUS_CLASS_YELLOW;

                // 2. Xác định màu icon Customer Type
                let custTypeClass = CUST_CLASS_ALL;
                if (this.FEC_Customer_Type === CUST_TYPE_NON_EXISTING) custTypeClass = CUST_CLASS_NON_EXISTING;
                else if (this.FEC_Customer_Type === CUST_TYPE_EXISTING) custTypeClass = CUST_CLASS_EXISTING;

                return {
                    ...row,
                    dynamicIconClass: `${CSS_BASE_SML_LEFT} ${statusClass}`,
                    customerIconClass: `${CSS_BASE_SML_LEFT} ${custTypeClass}`
                };
            });
            this.error = undefined;
        } else if (error) {
            this.fraudDataList = undefined;
            this.error = error;
            console.error('[wiredFraud] ERROR:', error);
        }
    }

    /**
     * @description Override processMasterData để bổ sung các thuộc tính UI-only.
     */
    processMasterData(data) {
        if (!data) return [];
        return data.map(record => {
            return {
                ...record,
                FEC_Stage_Name_Name: record.FEC_Stage_Name__r?.Name || '',
                FEC_Additional_Field_Name: record.FEC_Additional_Field__r?.Name || '',
                FEC_Channel_Name_Name: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Channel__c || '',
                FEC_Field_Status__c: !!record.FEC_Field_Status__c,            // Thuộc tính phục vụ UI Expand
                isExpanded: false,
                expandIcon: ICON_CHEVRON_RIGHT,
                // Field IDs from FEC_Data_Integration_Mapping__r relationship
                FEC_Int_Product_Line_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Product_Line_Id__c || '',
                FEC_Int_Service_Type_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Service_Type_Id__c || '',
                FEC_Int_Category_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Category_Id__c || '',
                FEC_Int_Sub_Category_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Sub_Category_Id__c || '',
                FEC_Int_Sub_Code_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Sub_Code_Id__c || '',
                FEC_Int_Channel__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Channel__c || '',
                // Display values (placeholders - will show IDs until we fetch actual values)
                Product_Line__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Product_Line_Id__c || LABEL_DEFAULT_PRODUCT_LINE,
                Service_Type__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Service_Type_Id__c || LABEL_DEFAULT_SERVICE_TYPE,
                Category__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Category_Id__c || LABEL_DEFAULT_CATEGORY,
                Sub_Category__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Sub_Category_Id__c || LABEL_DEFAULT_SUB_CATEGORY,
                Sub_Code__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Sub_Code_Id__c || 'N/A'
            };
        });
    }

    /**
    * @description Xử lý đóng/mở dòng để hiển thị component chỉnh sửa.
    * Chỉ cho phép mở 1 dòng tại 1 thời điểm - đóng các dòng khác khi mở dòng mới.
    */
    toggleExpand(event) {
        const recordId = event.currentTarget.dataset.id;

        this.processedDataFraud = this.processedDataFraud.map(item => {
            const isCurrentRecord = item.Id === recordId;
            
            if (isCurrentRecord) {
                const newStatus = !item.isExpanded;
                
                // When expanding, load the existing form data
                if (newStatus) {
                    this.recordIdForIntegration = recordId; // Track for edit mode
                    this.integrationFormData = {
                        selectedRoles: item.FEC_Applicable_Role__c ? item.FEC_Applicable_Role__c.split(',').map(r => r.trim()) : [],
                        section: item.FEC_Section__c || 'Case Information',
                        subSection: item.FEC_Sub_Section__c || 'Fraud Info',
                        fieldStatus: !!item.FEC_Field_Status__c
                    };
                } else {
                    // Reset form data when collapsing
                    this.recordIdForIntegration = undefined;
                    this.integrationFormData = {
                        selectedRoles: [],
                        section: 'Case Information',
                        subSection: 'Fraud Info',
                        fieldStatus: true
                    };
                }
                
                return {
                    ...item,
                    isExpanded: newStatus,
                    expandIcon: newStatus ? ICON_CHEVRON_DOWN : ICON_CHEVRON_RIGHT
                };
            }
            
            // Always close other rows when opening/closing the current row
            return { 
                ...item, 
                isExpanded: false, 
                expandIcon: ICON_CHEVRON_RIGHT 
            };
        });
        
        // Also sync fraudDataList
        if (this.fraudDataList) {
            this.fraudDataList = this.processedDataFraud;
        }
    }

    /**
     * @description Xử lý khi người dùng chọn một Stage khác trên Flow.
     * Cần reset các biến trạng thái để tránh việc hiển thị dữ liệu cũ của Stage trước đó.
     */
    handleStageClick(event) {
        try {
            const newStageId = event.detail;

            // 1. Reset dữ liệu danh sách về undefined để UI hiển thị trạng thái loading
            this.masterDataList = undefined;
            this.fraudDataList = undefined;
            this.processedData = [];
            this.processedDataFraud = [];

            // 2. Đóng các form edit/add đang mở
            this.isIntegrationAdd = false;
            this.selectedMappingId = null;
            this.isModalOpen = false;

            // 3. Cập nhật Stage Id mới - This will trigger wire adapter
            this.stageId = newStageId;
        } catch (error) {
            console.error('[handleStageClick] Error:', error);
        }
    }

    // --- Action Handlers ---
    handleAddIntegration() {
        // Đảm bảo FEC_Customer_Type có giá trị
        if (!this.FEC_Customer_Type) {
            console.warn('[handleAddIntegration] WARNING: FEC_Customer_Type is empty!');
        }
        
        this.selectedMappingId = null;
        this.recordIdForIntegration = undefined; // Reset form to create mode
        this.integrationModeEnabled = true;
        this.isIntegrationAdd = true;
    }

    handleSaveIntegration(event) {
        const buttonDataId = event?.currentTarget?.dataset?.id;
        
        let child;
        
        if (buttonDataId) {
            // Edit mode: find the specific c-fec-integration-mapping for this row
            child = this.template.querySelector(
                `c-fec-integration-mapping[data-mapping-row="${buttonDataId}"]`
            );
        } else {
            // Add mode: find the c-fec-integration-mapping in add section
            child = this.template.querySelector(
                'c-fec-integration-mapping[data-mapping-mode="add"]'
            );
        }
        
        if (child) {
            if (typeof child.handleSave === 'function') {
                child.handleSave();
            } else {
                this.showToast('Error', 'Save method not available on component', VARIANT_ERROR);
                console.error('[handleSaveIntegration] ERROR: handleSave method not found');
            }
        } else {
            this.showToast('Error', 'Integration mapping component not found', VARIANT_ERROR);
            console.error('[handleSaveIntegration] ERROR: Child component not found. buttonDataId:', buttonDataId);
        }
    }

    handleCancelIntegration() {
        this.isIntegrationAdd = false;
        // Reset form data
        this.integrationFormData = {
            selectedRoles: [],
            section: 'Case Information',
            subSection: 'Fraud Info',
            fieldStatus: true
        };
    }

    /**
 * @description Xử lý thay đổi trạng thái Active/Inactive trực tiếp từ Badge.
 * @param {Event} event 
 */
    async handleToggleStatus(event) {
        const recordId = event.currentTarget.dataset.id;
        const currentStatus = event.currentTarget.dataset.status === 'true'; // Chuyển string sang boolean
        const newStatus = !currentStatus;

        const updateReq = {
            Id: recordId,
            FEC_Field_Status__c: newStatus,
        };

        this.isLoading = true; // Bật spinner để chặn thao tác trùng lặp

        try {
            await saveMasterDataSetting({ mappingReq: updateReq });

            // 3. Thông báo thành công
            const statusLabel = newStatus ? this.labelActive : this.labelInactive;
            this.showToast(LABEL_TOAST_UPDATE_STATUS_SUCCESS, statusLabel, VARIANT_SUCCESS);

            // 4. Refresh dữ liệu để UI cập nhật Badge mới
            await refreshApex(this.wiredFraudResult);
            
            // HISTORY: Refresh history panel
            this.refreshHistoryPanel();

        } catch (error) {
            console.error('[handleToggleStatus] ERROR:', error);
            this.showToast(LABEL_TOAST_UPDATE_STATUS_SUCCESS, 'Không thể cập nhật trạng thái: ' + (error.body?.message || error.message), VARIANT_ERROR);
        } finally {
            this.isLoading = false;
        }
    }

    handleSuccessIntegration(event) {
        console.log('[handleSuccessIntegration] EVENT RECEIVED:', JSON.stringify(event.detail));
        console.log('[handleSuccessIntegration] currentNatureOfCaseId:', this.currentNatureOfCaseId);
        console.log('[handleSuccessIntegration] stageId:', this.stageId);
        this.isLoading = true;

        const integrationId = event.detail.mappingId;
        console.log('[handleSuccessIntegration] integrationId:', integrationId);

        // Combine mapping data with integration form data
        // Calculate Fraud Info Sub Section Order:
        // 1. Nếu có Property Info → Fraud Info = Property Info order + 1
        // 2. Nếu không có Property Info → Fraud Info = max order của tất cả sub sections đã có + 1
        // 3. Nếu chưa có sub section nào → Fraud Info = 1
        let fraudInfoOrder = 1;
        if (this.processedData && this.processedData.length > 0) {
            const propertyInfoRows = this.processedData.filter(
                row => row.FEC_Sub_Section__c === 'Property Info' && row.FEC_Sub_Section_Order__c
            );
            if (propertyInfoRows.length > 0) {
                // Có Property Info → lấy order của nó + 1
                fraudInfoOrder = Math.max(...propertyInfoRows.map(r => r.FEC_Sub_Section_Order__c)) + 1;
            } else {
                // Không có Property Info → lấy max order của tất cả sub sections + 1
                const allOrders = this.processedData
                    .filter(row => row.FEC_Sub_Section_Order__c)
                    .map(r => r.FEC_Sub_Section_Order__c);
                if (allOrders.length > 0) {
                    fraudInfoOrder = Math.max(...allOrders) + 1;
                }
            }
        }

        const newMapping = {
            FEC_Data_Integration_Mapping__c: integrationId,
            FEC_Nature_Of_Case__c: this.currentNatureOfCaseId,
            FEC_Stage_Name__c: this.stageId,
            FEC_Applicable_Role__c: this.integrationFormData.selectedRoles.join(','),
            FEC_Section__c: this.integrationFormData.section,
            FEC_Sub_Section__c: this.integrationFormData.subSection,
            FEC_Sub_Section_Order__c: fraudInfoOrder,
            FEC_Field_Editable__c: true,
            FEC_Field_Status__c: this.integrationFormData.fieldStatus
        };
        console.log('[handleSuccessIntegration] newMapping:', JSON.stringify(newMapping));

        // If in edit mode (recordIdForIntegration is set), include the record ID for update
        if (this.recordIdForIntegration) {
            newMapping.Id = this.recordIdForIntegration;
        }

        console.log('[handleSuccessIntegration] CALLING saveMasterDataSetting NOW...');
        saveMasterDataSetting({ mappingReq: newMapping })
            .then((result) => {
                console.log('[handleSuccessIntegration] saveMasterDataSetting SUCCESS, result:', result);
                this.isIntegrationAdd = false;
                this.recordIdForIntegration = undefined;
                this.integrationFormData = {
                    selectedRoles: [],
                    section: 'Case Information',
                    subSection: 'Fraud Info',
                    fieldStatus: true
                };
                // Imperative call to bypass cacheable=true cache
                console.log('[handleSuccessIntegration] Calling getMasterDataSettings imperatively...');
                return getMasterDataSettingsFresh({
                    selectedNodeId: this.currentNatureOfCaseId,
                    selectedStageId: this.stageId,
                    isIntegration: true
                });
            })
            .then((data) => {
                console.log('[handleSuccessIntegration] Imperative result:', data ? data.length : 'null', 'records');
                if (data) {
                    this.fraudDataList = this.processMasterData(data);
                    this.processedDataFraud = this.fraudDataList.map(row => {
                        let statusClass = STATUS_CLASS_BLUE;
                        if (row.Process_Change_Status__c === STATUS_NEW) statusClass = STATUS_CLASS_RED;
                        else if (row.Process_Change_Status__c === STATUS_UPDATE) statusClass = STATUS_CLASS_YELLOW;
                        let custTypeClass = CUST_CLASS_ALL;
                        if (this.FEC_Customer_Type === CUST_TYPE_NON_EXISTING) custTypeClass = CUST_CLASS_NON_EXISTING;
                        else if (this.FEC_Customer_Type === CUST_TYPE_EXISTING) custTypeClass = CUST_CLASS_EXISTING;
                        return {
                            ...row,
                            dynamicIconClass: `${CSS_BASE_SML_LEFT} ${statusClass}`,
                            customerIconClass: `${CSS_BASE_SML_LEFT} ${custTypeClass}`
                        };
                    });
                }
                // Delay refresh để History Tracking kịp commit async
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    this.refreshHistoryPanel();
                }, 500);
            })
            .catch(error => {
                console.error('[handleSuccessIntegration] saveMasterDataSetting ERROR:', error);
                console.error('[handleSuccessIntegration] Error body:', JSON.stringify(error?.body));
                console.error('[handleSuccessIntegration] Error message:', error?.body?.message || error?.message);
                this.showToast('ERROR saving MDM', error?.body?.message || error?.message || 'Unknown error', VARIANT_ERROR);
            })
            .finally(() => {
                console.log('[handleSuccessIntegration] FINALLY block reached');
                this.isLoading = false;
            });
    }

    handleEditRow(id) {
        this.recordIdForEdit = id;
        const foundRecord = this.processedData.find(r => r.Id === id);
        this.selectedRecord = foundRecord || {};
        this.isModalOpen = true;
        this.modalTitle = this.labelModalEditProperty || LABEL_MODAL_EDIT_PROPERTY_TITLE;
    }

    handleRowAction(event) {
        // Lấy action name từ value của menu item
        const actionName = event.detail.value;
        // Lấy ID từ data-id được gán ở lightning-button-menu
        const rowId = event.currentTarget.dataset.id;

        console.log('Action:', actionName, 'Row ID:', rowId);

        switch (actionName) {
            case 'edit':
                this.handleEditRow(rowId);
                break;
            case 'delete':
                // Tìm record trong processedData để kiểm tra trạng thái
                const row = this.processedData.find(item => item.Id === rowId);
                if (row && row[FIELD_PROCESS_CHANGE_STATUS] !== STATUS_NEW) {
                    this.showToast(LABEL_TOAST_ERROR, LABEL_WARNING_DELETE_NEW_ONLY, 'warning');
                    return;
                }
                this.handleDeleteRow(rowId);
                break;
            default:
                break;
        }
    }

    /**
     * Handle direct icon click (Edit/Delete) from table row
     */
    handleIconAction(event) {
        const actionName = event.currentTarget.dataset.action;
        const rowId = event.currentTarget.dataset.id;
        switch (actionName) {
            case 'edit':
                this.handleEditRow(rowId);
                break;
            case 'delete': {
                const row = this.processedData.find(item => item.Id === rowId);
                if (row && row[FIELD_PROCESS_CHANGE_STATUS] !== STATUS_NEW) {
                    this.showToast(LABEL_TOAST_ERROR, LABEL_WARNING_DELETE_NEW_ONLY, 'warning');
                    return;
                }
                this.handleDeleteRow(rowId);
                break;
            }
            default:
                break;
        }
    }

    handleFraudRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === 'edit') {
            this.selectedMappingId = row.FEC_Data_Integration_Mapping__c;
            this.isIntegrationAdd = true;
        }
    }

    // --- Core Methods ---
    async handleDeleteRow(recordId) {
        const confirmed = await LightningConfirm.open({
            message: LABEL_CONFIRM_DELETE_PROPERTY,
            variant: 'header',
            label: LABEL_CONFIRM_DELETE_TITLE_GENERIC,
            theme: 'warning'
        });
        if (!confirmed) return;

        try {
            await deleteMasterDataSetting({ recordId });
            this.showToast(LABEL_TOAST_DELETED_SUCCESS, '', VARIANT_SUCCESS);
            await refreshApex(this.wiredMasterDataResult);

            // HISTORY: Refresh history panel
            this.refreshHistoryPanel();
        } catch (error) {
            this.showToast(LABEL_TOAST_ERROR, error.body?.message || error.message || 'Unknown error', VARIANT_ERROR);
        }
    }

    openNewSettingModal() {
        this.modalTitle = this.labelModalNewProperty || LABEL_MODAL_NEW_PROPERTY_TITLE;
        this.recordIdForEdit = null;
        
        // Pass existing fields to the form to prevent duplicates
        const existingFields = this.masterDataList ? this.masterDataList.map(item => item.FEC_Additional_Field__c).filter(Boolean) : [];
        this.selectedRecord = { existingFields };

        // Tìm giá trị lớn nhất của FEC_Field_Order_Display__c trong danh sách hiện tại
        if (this.masterDataList && this.masterDataList.length > 0) {
            const maxOrder = Math.max(...this.masterDataList.map(item => item.FEC_Field_Order_Display__c || 0));
            this.nextOrder = maxOrder + 1;
        } else {
            this.nextOrder = 1;
        }
        this.isModalOpen = true;
    }

    closeModal() {
        this.isModalOpen = false;
        this.isSavingModal = false;
    }

    isSavingModal = false;

    handleSaveFromModal() {
        const formCmp = this.template.querySelector('c-fec-master-data-setting-form');
        if (formCmp) {
            formCmp.submitForm();
        }
    }

    handleSuccess() {
        try {
            this.isSavingModal = false;
            this.closeModal();
            // this.showToast(LABEL_TOAST_SAVE_SUCCESS, '', VARIANT_SUCCESS);
            
            this.isLoading = true;
            if (this.wiredMasterDataResult) {
                refreshApex(this.wiredMasterDataResult)
                    .then(() => {
                        // Data should be updated now via wiredProperties callback
                        // processedData should be updated automatically
                        this.isLoading = false;

                        // HISTORY: Delay refresh để History Tracking kịp commit async
                        // eslint-disable-next-line @lwc/lwc/no-async-operation
                        setTimeout(() => {
                            this.refreshHistoryPanel();
                        }, 500);
                    })
                    .catch(refreshError => {
                        console.error('Error refreshing wire adapter:', refreshError);
                        this.isLoading = false;
                    });
            } else {
                this.isLoading = false;
            }
        } catch (error) {
            console.error('Error in handleSuccess:', error);
            this.isLoading = false;
            try {
                this.closeModal();
            } catch (closeError) {
                console.error('Error closing modal:', closeError);
            }
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }



    // Hàm xử lý khi click vào Header
    handleSort(event) {
        const fieldName = event.currentTarget.dataset.field;

        // Nếu click lại cột cũ thì đảo chiều, click cột mới thì mặc định là DEFAULT_SORT_DIRECTION_ASC
        if (this.sortedBy === fieldName) {
            this.sortDirection = this.sortDirection === DEFAULT_SORT_DIRECTION_ASC ? DEFAULT_SORT_DIRECTION_DESC : DEFAULT_SORT_DIRECTION_ASC;
        } else {
            this.sortedBy = fieldName;
            this.sortDirection = DEFAULT_SORT_DIRECTION_ASC;
        }

        this.sortData(this.sortedBy, this.sortDirection);
    }

    // Logic sắp xếp mảng
    // Shallow copy via spread is sufficient here — sort() only reorders array elements
    // without mutating the objects themselves, so deep cloning is unnecessary.
    sortData(fieldName, direction) {
        const keyValue = (a) => a[fieldName];
        const isReverse = direction === DEFAULT_SORT_DIRECTION_ASC ? 1 : -1;

        this.processedData = [...this.processedData].sort((x, y) => {
            let xVal = keyValue(x) ? keyValue(x) : '';
            let yVal = keyValue(y) ? keyValue(y) : '';

            // Xử lý nếu là kiểu số (Order)
            if (typeof xVal === 'number' && typeof yVal === 'number') {
                return isReverse * (xVal - yVal);
            }

            // Mặc định so sánh chuỗi (String)
            return isReverse * ((xVal > yVal) - (yVal > xVal));
        }).map((row, index) => ({ ...row, rowNumber: index + 1 }));
    }

    handleSearchProperty(event) {
        this.searchTermProperty = event.target.value;
        this.applyPropertySearch();
    }

    applyPropertySearch() {
        if (!this._allProcessedData) return;
        if (!this.searchTermProperty || this.searchTermProperty.trim() === '') {
            this.processedData = [...this._allProcessedData];
        } else {
            const key = this.searchTermProperty.toLowerCase().trim();
            this.processedData = this._allProcessedData.filter(row => {
                const propName = (row.FEC_Additional_Field_Name || '').toLowerCase();
                const channel = (row.FEC_Channel_Name_Name || '').toLowerCase();
                const role = (row.FEC_Applicable_Role__c || '').toLowerCase();
                const section = (row.FEC_Section__c || '').toLowerCase();
                return propName.includes(key) || channel.includes(key) || role.includes(key) || section.includes(key);
            });
        }
        // Re-number rows
        this.processedData = this.processedData.map((row, index) => ({ ...row, rowNumber: index + 1 }));
    }

    // Getter ảo để hiển thị icon (Lưu ý: Trong LWC bạn không thể gọi hàm có tham số trực tiếp từ HTML, 
    // nên dùng logic render thủ công hoặc dùng template if:true cho từng cột)

    get sortIconName() {
        return this.sortDirection === 'asc' ? ICON_ARROW_UP : ICON_ARROW_DOWN;
    }

    get isChannelSorted() { return this.sortedBy === FIELD_CHANNEL; }
    get isPropertySorted() { return this.sortedBy === FIELD_ADDITIONAL_FIELD_NAME; }
    get isRoleSorted() { return this.sortedBy === FIELD_APPLICABLE_ROLE; }
    get isSectionSorted() { return this.sortedBy === FIELD_SECTION; }
    get isSubSectionSorted() { return this.sortedBy === FIELD_SUB_SECTION; }
    get isSubSectionOrderSorted() { return this.sortedBy === FIELD_SUB_SECTION_ORDER; }
    get isOrderSorted() { return this.sortedBy === FIELD_FIELD_ORDER_DISPLAY; }

    get computedIconClass() {
        let baseClass = CSS_BASE_SML_LEFT;
        let statusClass = STATUS_CLASS_BLUE;
        const status = this.ChangeStatus;

        if (status === STATUS_NEW) {
            statusClass = STATUS_CLASS_RED;
        } else if (status === STATUS_UPDATE) {
            statusClass = STATUS_CLASS_YELLOW;
        }
        return `${baseClass} ${statusClass}`;
    }

    /**
     * @description Fetch user roles for Applicable Roles dropdown
     */
    @wire(getUserRoles)
    wiredRoles(result) {
        if (result.data) {
            this.roleOptions = result.data;
        } else if (result.error) {
            console.error('[wiredRoles] ERROR:', result.error);
        }
    }

    // --- Integration Form Handlers ---
    get filteredRoleOptions() {
        if (!this.roleOptions) return [];
        if (!this.roleSearchTerm || this.roleSearchTerm.trim() === '') {
            return this.roleOptions;
        }
        const key = this.roleSearchTerm.toLowerCase().trim();
        return this.roleOptions.filter(opt => 
            (opt.label || '').toLowerCase().includes(key)
        );
    }

    // Section options for Fraud Integration Mapping Settings (fixed: Case Information only)
    get integrationSectionOptions() {
        return [
            { label: 'Case Information', value: 'Case Information' }
        ];
    }

    // Sub Section options for Fraud Integration Mapping (fixed: Fraud Info only)
    get integrationSubSectionOptions() {
        return [
            { label: 'Fraud Info', value: 'Fraud Info' }
        ];
    }

    // Column count options removed — not needed for Fraud Integration Mapping

    handleRoleSearchInput(event) {
        this.roleSearchTerm = event.target.value;
        this.isRoleDropdownOpen = true;
    }

    handleRoleSearchFocus() {
        this.isRoleDropdownOpen = true;
    }

    handleRoleSearchBlur() {
        // Delay to allow click on dropdown item to register
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => { this.isRoleDropdownOpen = false; }, 200);
    }

    handleSelectRoleFromList(event) {
        const selectedRole = event.currentTarget.dataset.value;
        if (selectedRole && !this.integrationFormData.selectedRoles.includes(selectedRole)) {
            this.integrationFormData.selectedRoles = [...this.integrationFormData.selectedRoles, selectedRole];
        }
        this.roleSearchTerm = '';
        this.isRoleDropdownOpen = false;
    }

    handleRoleItemHover(event) {
        event.currentTarget.style.backgroundColor = '#f3f3f3';
        event.currentTarget.addEventListener('mouseleave', (e) => {
            e.currentTarget.style.backgroundColor = '#ffffff';
        }, { once: true });
    }

    handleSelectRole(event) {
        const selectedRole = event.detail.value;
        if (selectedRole && !this.integrationFormData.selectedRoles.includes(selectedRole)) {
            this.integrationFormData.selectedRoles = [...this.integrationFormData.selectedRoles, selectedRole];
        }
    }

    handleRemoveRole(event) {
        // Try multiple ways to get the role name from the pill
        let roleToRemove = event.detail.name; // Standard way
        
        // Fallback: try to get from currentTarget attributes
        if (!roleToRemove) {
            roleToRemove = event.currentTarget.getAttribute('name');
        }
        
        // Fallback 2: try data-role attribute
        if (!roleToRemove) {
            roleToRemove = event.currentTarget.getAttribute('data-role');
        }
        
        // Fallback 3: try label attribute
        if (!roleToRemove) {
            roleToRemove = event.currentTarget.getAttribute('label');
        }
        
        if (!roleToRemove) {
            console.error('[handleRemoveRole] ERROR: Could not find role name from any source');
            return;
        }
        
        this.integrationFormData = {
            ...this.integrationFormData,
            selectedRoles: this.integrationFormData.selectedRoles.filter(
                role => role !== roleToRemove
            )
        };
    }

    handleInputChange(event) {
        const fieldName = event.currentTarget.dataset.field;
        const value = event.detail.value;
        
        if (fieldName === 'section') {
            this.integrationFormData = { ...this.integrationFormData, section: value };
        } else if (fieldName === 'subSection') {
            this.integrationFormData = { ...this.integrationFormData, subSection: value };
        }
    }

    handleCheckboxChange(event) {
        const fieldName = event.currentTarget.dataset.field;
        const value = event.detail.checked;
        
        if (fieldName === 'fieldStatus') {
            this.integrationFormData.fieldStatus = value;
        }
    }

    /**
     * Handle delete fraud integration mapping
     * @param {Event} event - Click event from delete button
     */
    async handleDeleteFraud(event) {
        const recordId = event.currentTarget.dataset.id;
        
        if (!recordId) {
            this.showToast(LABEL_TOAST_ERROR, 'Record ID not found', VARIANT_ERROR);
            return;
        }

        // Show confirmation dialog
        const confirmed = await LightningConfirm.open({
            message: LABEL_CONFIRM_DELETE_FRAUD_MSG,
            variant: 'header',
            label: LABEL_CONFIRM_DELETE_TITLE_GENERIC,
            theme: 'warning'
        });
        
        if (!confirmed) {
            return;
        }

        this.isLoading = true;

        // Call Apex to soft-delete record
        deleteFraudIntegrationMapping({ recordId: recordId })
            .then(() => {
                this.showToast(LABEL_TOAST_SUCCESS, LABEL_TOAST_DELETED_SUCCESS, VARIANT_SUCCESS);
                
                // Imperative call to bypass cacheable=true cache
                return getMasterDataSettingsFresh({
                    selectedNodeId: this.currentNatureOfCaseId,
                    selectedStageId: this.stageId,
                    isIntegration: true
                });
            })
            .then((data) => {
                if (data) {
                    this.fraudDataList = this.processMasterData(data);
                    this.processedDataFraud = this.fraudDataList.map(row => {
                        let statusClass = STATUS_CLASS_BLUE;
                        if (row.Process_Change_Status__c === STATUS_NEW) statusClass = STATUS_CLASS_RED;
                        else if (row.Process_Change_Status__c === STATUS_UPDATE) statusClass = STATUS_CLASS_YELLOW;
                        let custTypeClass = CUST_CLASS_ALL;
                        if (this.FEC_Customer_Type === CUST_TYPE_NON_EXISTING) custTypeClass = CUST_CLASS_NON_EXISTING;
                        else if (this.FEC_Customer_Type === CUST_TYPE_EXISTING) custTypeClass = CUST_CLASS_EXISTING;
                        return {
                            ...row,
                            dynamicIconClass: `${CSS_BASE_SML_LEFT} ${statusClass}`,
                            customerIconClass: `${CSS_BASE_SML_LEFT} ${custTypeClass}`
                        };
                    });
                } else {
                    this.fraudDataList = [];
                    this.processedDataFraud = [];
                }
                this.isLoading = false;

                // HISTORY: Refresh history panel
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => { this.refreshHistoryPanel(); }, 500);
            })
            .catch(error => {
                this.isLoading = false;
                const errorMessage = error.body?.message || error.message || LABEL_ERROR_DELETE_FRAUD;
                console.error('[handleDeleteFraud] ERROR:', error);
                this.showToast(LABEL_TOAST_ERROR, errorMessage, VARIANT_ERROR);
            });
    }
}