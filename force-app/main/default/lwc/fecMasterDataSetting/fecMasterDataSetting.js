import { api, LightningElement, track, wire } from 'lwc';
import getMasterDataSettings from '@salesforce/apex/FEC_MasterDataSettingController.getMasterDataSettings';
import deleteMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.deleteRecord';
import deleteFraudIntegrationMapping from '@salesforce/apex/FEC_MasterDataSettingController.deleteFraudIntegrationMapping';
import saveMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.saveMasterDataSetting';
import getUserTypeIdByName from '@salesforce/apex/FEC_MasterDataSettingController.getUserTypeIdByName';
import getUserRoles from '@salesforce/apex/FEC_MasterDataSettingController.getUserRoles';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { showLog } from 'c/fecMDMUtils';
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
import LABEL_LABEL_ACTIVE from '@salesforce/label/c.FEC_Label_Active';
import LABEL_LABEL_INACTIVE from '@salesforce/label/c.FEC_Label_Inactive';
import LABEL_TOOLTIP_CLICK_TO_DEACTIVATE from '@salesforce/label/c.FEC_Tooltip_Click_To_Deactivate';
import LABEL_TOOLTIP_CLICK_TO_ACTIVATE from '@salesforce/label/c.FEC_Tooltip_Click_To_Activate';
import { FIELD_SECTION, FIELD_FIELD_ORDER_DISPLAY, TYPE_TEXT, TYPE_BOOLEAN, STATUS_NEW, STATUS_UPDATE, CUST_TYPE_NON_EXISTING, CUST_TYPE_EXISTING, ICON_CHEVRON_RIGHT, ICON_CHEVRON_DOWN, MASTER_DATA_SETTING_COLUMNS, STATUS_CLASS_BLUE, STATUS_CLASS_RED, STATUS_CLASS_YELLOW, CUST_CLASS_ALL, CUST_CLASS_NON_EXISTING, CUST_CLASS_EXISTING, DEFAULT_SORT_FIELD, DEFAULT_SORT_DIRECTION_ASC, DEFAULT_SORT_DIRECTION_DESC, FIELD_ADDITIONAL_FIELD_NAME, FIELD_OBJECT_FRAUD_INTEGRATION, ICON_ARROW_UP, ICON_ARROW_DOWN, CSS_BASE_SML_LEFT, FIELD_CHANNEL, FIELD_APPLICABLE_ROLE, VARIANT_SUCCESS, VARIANT_ERROR } from 'c/fecConstants';

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
    @track isLoading = false;
    @track isModalOpen = false;
    @track isIntegrationAdd = false;
    @track recordIdForEdit;
    @track selectedMappingId;
    @track ChangeStatus;
    @track _item;
    @track masterDataList = [];
    @track processedData = [];
    @track processedDataFraud = [];
    @track stageId;
    @track currentNatureOfCaseId;
    @track FEC_Customer_Type;
    @track userTypeName;
    @track selectedRecord = {};
    @track recordIdForIntegration;
    @track integrationModeEnabled = false;
    @track integrationFormData = {
        selectedRoles: [],
        section: '',
        fieldStatus: true,
        fieldReadOnly: false,
        fieldMandatory: false
    };
    @track roleOptions = [];

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
    labelModalEditProperty = LABEL_MODAL_EDIT_PROPERTY_TITLE;
    labelAddIntegration = LABEL_BUTTON_ADD_INTEGRATION;
    labelActive = LABEL_LABEL_ACTIVE;
    labelInactive = LABEL_LABEL_INACTIVE;
    labelTooltipDeactivate = LABEL_TOOLTIP_CLICK_TO_DEACTIVATE;
    labelTooltipActivate = LABEL_TOOLTIP_CLICK_TO_ACTIVATE;

    wiredMasterDataResult;
    wiredFraudResult;

    @track sortedBy = DEFAULT_SORT_FIELD;
    @track sortDirection = DEFAULT_SORT_DIRECTION_ASC;
    modalTitle = '';

    @api
    get item() {
        return this._item;
    }
    set item(value) {
        this._item = value;
        showLog('set item', value);
        if (value && value.id) {
            this.currentNatureOfCaseId = value.id;
            this.FEC_Customer_Type = value.FEC_Customer_Type;
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

    // Tab 1: Properties
    @wire(getMasterDataSettings, {
        selectedNodeId: '$currentNatureOfCaseId',
        selectedStageId: '$stageId',
        isIntegration: false
    })
    wiredProperties(result) {
        showLog('[wiredProperties] stageId,currentNatureOfCaseId:', 
            {stageId:this.stageId, currentNatureOfCaseId:this.currentNatureOfCaseId});
        this.wiredMasterDataResult = result;
        const { data, error } = result;

        if (data) {
            showLog('[wiredProperties] Raw Data from Apex', data);
            this.masterDataList = data;
            
            // XỬ LÝ DATA NGAY TẠI ĐÂY (Thay thế cho Getter)
            this.processedData = data.map(row => {
                const rowStatus = row.Process_Change_Status__c || '';
                
                // Handle channel - could be from lookup relationship or text field
                let channelDisplay = '';
                if (row.FEC_Case_Channel__r?.Name) {
                    channelDisplay = row.FEC_Case_Channel__r.Name;
                } else if (row.FEC_Channel__c) {
                    channelDisplay = row.FEC_Channel__c;
                } else {
                    channelDisplay = LABEL_DEFAULT_CHANNEL_NAME;
                }
                
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
                    // Map thêm label cho Property Name từ quan hệ __r
                    FEC_Additional_Field_Name: row.FEC_Additional_Field__r ? row.FEC_Additional_Field__r.Name : '',
                    FEC_Channel_Name_Name: channelDisplay,
                    // Ensure all fields have values (FLS might strip them)
                    FEC_Applicable_Role__c: row.FEC_Applicable_Role__c || '',
                    FEC_Section__c: row.FEC_Section__c || '',
                    FEC_Field_Order_Display__c: row.FEC_Field_Order_Display__c || 0,
                    FEC_Field_Status__c: row.FEC_Field_Status__c || false,
                    FEC_Field_ReadOnly__c: row.FEC_Field_ReadOnly__c || false,
                    FEC_Field_Mandatory__c: row.FEC_Field_Mandatory__c || false,
                    dynamicIconClass: `${CSS_BASE_SML_LEFT} ${statusClass}`,
                    customerIconClass: `${CSS_BASE_SML_LEFT} ${custTypeClass}`
                };
            });
            
            // Reset sort to default when new data arrives
            this.sortedBy = DEFAULT_SORT_FIELD;
            this.sortDirection = DEFAULT_SORT_DIRECTION_ASC;
            
            // Sort the data
            this.sortData(this.sortedBy, this.sortDirection);
            
            this.error = undefined;
            this.isLoading = false;
        } else if (error) {
            this.error = error;
            showLog('[wiredProperties] ERROR:', error);
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

        if (data) {
            // Luôn gán lại giá trị kể cả khi data là danh sách rỗng []
            this.fraudDataList = this.processMasterData(data);
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
            showLog('wiredFraud DATA', data);
        } else if (error) {
            this.fraudDataList = undefined;
            this.error = error;
            showLog('wiredFraud ERROR', error);
        }
    }

    /**
     * @description Override processMasterData để bổ sung các thuộc tính UI-only.
     */
    processMasterData(data) {
        if (!data) return [];
        return data.map(record => {
            showLog('processMasterData Record Status', record.Process_Change_Status__c);
            
            // Handle channel - could be from lookup relationship or text field
            let channelDisplay = '';
            if (record.FEC_Case_Channel__r?.Name) {
                channelDisplay = record.FEC_Case_Channel__r.Name;
            } else if (record.FEC_Channel__c) {
                channelDisplay = record.FEC_Channel__c;
            } else {
                channelDisplay = LABEL_DEFAULT_CHANNEL_NAME;
            }
            
            return {
                ...record,
                FEC_Stage_Name_Name: record.FEC_Stage_Name__r?.Name || '',
                FEC_Additional_Field_Name: record.FEC_Additional_Field__r?.Name || '',
                FEC_Channel_Name_Name: channelDisplay,
                FEC_Field_Status__c: !!record.FEC_Field_Status__c,            // Thuộc tính phục vụ UI Expand
                isExpanded: false,
                expandIcon: ICON_CHEVRON_RIGHT,
                // Field IDs from FEC_Data_Integration_Mapping__r relationship
                FEC_Int_Product_Line_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Product_Line_Id__c || '',
                FEC_Int_Service_Type_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Service_Type_Id__c || '',
                FEC_Int_Category_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Category_Id__c || '',
                FEC_Int_Sub_Category_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Sub_Category_Id__c || '',
                FEC_Int_Sub_Code_Id__c: record.FEC_Data_Integration_Mapping__r?.FEC_Int_Sub_Code_Id__c || '',
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
        showLog('[toggleExpand] RecordId: ' + recordId);

        this.processedDataFraud = this.processedDataFraud.map(item => {
            const isCurrentRecord = item.Id === recordId;
            
            if (isCurrentRecord) {
                const newStatus = !item.isExpanded;
                
                // When expanding, load the existing form data
                if (newStatus) {
                    this.recordIdForIntegration = recordId; // Track for edit mode
                    this.integrationFormData = {
                        selectedRoles: item.FEC_Applicable_Role__c ? item.FEC_Applicable_Role__c.split(',').map(r => r.trim()) : [],
                        section: item.FEC_Section__c || '',
                        fieldStatus: !!item.FEC_Field_Status__c,
                        fieldReadOnly: !!item.FEC_Field_ReadOnly__c,
                        fieldMandatory: !!item.FEC_Field_Mandatory__c
                    };
                    showLog('[toggleExpand] Loaded form data:', this.integrationFormData);
                } else {
                    // Reset form data when collapsing
                    this.recordIdForIntegration = undefined;
                    this.integrationFormData = {
                        selectedRoles: [],
                        section: '',
                        fieldStatus: true,
                        fieldReadOnly: false,
                        fieldMandatory: false
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
            showLog('[handleStageClick] START');
            
            const newStageId = event.detail;
            showLog('[handleStageClick] Received stageId:', newStageId);

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
            
            showLog('[handleStageClick] stageId updated to:', this.stageId);
            showLog('[handleStageClick] Wire adapter should be triggered now');
        } catch (error) {
            console.error('[handleStageClick] Error:', error);
        }
    }

    // --- Action Handlers ---
    handleAddIntegration() {
        showLog('[handleAddIntegration] START');
        showLog('[handleAddIntegration] FEC_Customer_Type:', this.FEC_Customer_Type);
        showLog('[handleAddIntegration] currentNatureOfCaseId:', this.currentNatureOfCaseId);
        showLog('[handleAddIntegration] stageId:', this.stageId);
        
        // Đảm bảo FEC_Customer_Type có giá trị
        if (!this.FEC_Customer_Type) {
            showLog('[handleAddIntegration] WARNING: FEC_Customer_Type is empty!');
        }
        
        this.selectedMappingId = null;
        this.recordIdForIntegration = undefined; // Reset form to create mode
        this.integrationModeEnabled = true;
        this.isIntegrationAdd = true;
    }

    handleSaveIntegration(event) {
        const buttonDataId = event?.currentTarget?.dataset?.id;
        showLog('[handleSaveIntegration] START - buttonDataId:', buttonDataId);
        
        let child;
        
        if (buttonDataId) {
            // Edit mode - find the child component in the expanded row
            // The expanded row contains data-id attribute on the button
            // We need to find the nearest parent that contains the integration-mapping component
            
            // Method 1: Find parent with matching data-id and look for c-fec-integration-mapping inside
            const parentButton = this.template.querySelector(`lightning-button[data-id="${buttonDataId}"]`);
            showLog('[handleSaveIntegration] Found parentButton:', !!parentButton);
            
            if (parentButton) {
                // Go up to find the expanded section container
                let container = parentButton.closest('.slds-p-around_medium');
                showLog('[handleSaveIntegration] Found container (slds-p-around_medium):', !!container);
                
                if (container) {
                    child = container.querySelector('c-fec-integration-mapping');
                    showLog('[handleSaveIntegration] Found child in container:', !!child);
                }
            }
            
            // Fallback: Search all c-fec-integration-mapping components
            if (!child) {
                showLog('[handleSaveIntegration] Fallback: searching all c-fec-integration-mapping');
                const allMappingComponents = this.template.querySelectorAll('c-fec-integration-mapping');
                showLog('[handleSaveIntegration] Total c-fec-integration-mapping found:', allMappingComponents.length);
                
                // In edit mode, should be the last one (not the add form)
                if (allMappingComponents.length > 1) {
                    child = allMappingComponents[allMappingComponents.length - 1];
                    showLog('[handleSaveIntegration] Using last mapping component');
                } else if (allMappingComponents.length === 1) {
                    child = allMappingComponents[0];
                    showLog('[handleSaveIntegration] Using only mapping component');
                }
            }
        } else {
            // Create mode - find the first component in the add section (isIntegrationAdd = true)
            const addSection = this.template.querySelector('.slds-box.slds-theme_default');
            showLog('[handleSaveIntegration] Found addSection:', !!addSection);
            
            if (addSection) {
                child = addSection.querySelector('c-fec-integration-mapping');
                showLog('[handleSaveIntegration] Found child in add section:', !!child);
            } else {
                // Fallback: Get first c-fec-integration-mapping
                const allMappingComponents = this.template.querySelectorAll('c-fec-integration-mapping');
                if (allMappingComponents.length > 0) {
                    child = allMappingComponents[0];
                    showLog('[handleSaveIntegration] Using first mapping component as fallback');
                }
            }
        }
        
        if (child) {
            showLog('[handleSaveIntegration] Calling child.handleSave()');
            if (typeof child.handleSave === 'function') {
                child.handleSave();
            } else {
                this.showToast('Error', 'Save method not available on component', VARIANT_ERROR);
                showLog('[handleSaveIntegration] ERROR: handleSave method not found');
            }
        } else {
            this.showToast('Error', 'Integration mapping component not found', VARIANT_ERROR);
            showLog('[handleSaveIntegration] ERROR: Child component not found');
            showLog('[handleSaveIntegration] buttonDataId:', buttonDataId);
            showLog('[handleSaveIntegration] isIntegrationAdd:', this.isIntegrationAdd);
        }
    }

    handleCancelIntegration() {
        this.isIntegrationAdd = false;
        // Reset form data
        this.integrationFormData = {
            selectedRoles: [],
            section: '',
            fieldStatus: true,
            fieldReadOnly: false,
            fieldMandatory: false
        };
        showLog('[handleCancelIntegration] Form cancelled and reset');
    }

    /**
 * @description Xử lý thay đổi trạng thái Active/Inactive trực tiếp từ Badge.
 * @param event 
 */
    async handleToggleStatus(event) {
        const recordId = event.currentTarget.dataset.id;
        const currentStatus = event.currentTarget.dataset.status === 'true'; // Chuyển string sang boolean
        const newStatus = !currentStatus;

        showLog('[handleToggleStatus] START - RecordId: ' + recordId + ' New Status: ' + newStatus);

        // 1. Tạo object data để update (Tuân thủ Prefix FEC_)
        const updateReq = {
            Id: recordId,
            FEC_Field_Status__c: newStatus,
        };

        this.isLoading = true; // Bật spinner để chặn thao tác trùng lặp

        try {
            // 2. Gọi Apex để update (Sử dụng lại hàm save hoặc update tùy Controller của bạn)
            // Ở đây tôi giả định dùng chung hàm saveMasterDataSetting có chức năng upsert
            await saveMasterDataSetting({ mappingReq: updateReq });

            // 3. Thông báo thành công
            const statusLabel = newStatus ? this.labelActive : this.labelInactive;
            this.showToast(LABEL_TOAST_UPDATE_STATUS_SUCCESS, statusLabel, VARIANT_SUCCESS);

            // 4. Refresh dữ liệu để UI cập nhật Badge mới
            await refreshApex(this.wiredFraudResult);

        } catch (error) {
            showLog('[handleToggleStatus] ERROR', error);
            this.showToast(LABEL_TOAST_UPDATE_STATUS_SUCCESS, 'Không thể cập nhật trạng thái: ' + (error.body?.message || error.message), VARIANT_ERROR);
        } finally {
            this.isLoading = false;
            showLog('[handleToggleStatus] RETURN');
        }
    }

    handleSuccessIntegration(event) {
        showLog('[handleSuccessIntegration] START');
        this.isLoading = true;

        const integrationId = event.detail.mappingId;
        showLog('[handleSuccessIntegration] Integration mappingId:', integrationId);
        showLog('[handleSuccessIntegration] recordIdForIntegration:', this.recordIdForIntegration);

        // Combine mapping data with integration form data
        const newMapping = {
            FEC_Data_Integration_Mapping__c: integrationId,
            FEC_Field_Object_Name__c: FIELD_OBJECT_FRAUD_INTEGRATION,
            FEC_Nature_Of_Case__c: this.currentNatureOfCaseId,
            FEC_Stage_Name__c: this.stageId,
            FEC_Customer_Type__c: this.FEC_Customer_Type,
            FEC_Applicable_Role__c: this.integrationFormData.selectedRoles.join(','),
            FEC_Section__c: this.integrationFormData.section,
            FEC_Field_Mandatory__c: this.integrationFormData.fieldMandatory,
            FEC_Field_ReadOnly__c: this.integrationFormData.fieldReadOnly,
            FEC_Field_Editable__c: true,
            FEC_Field_Status__c: this.integrationFormData.fieldStatus,
            FEC_Channel__c: 'FIMA' // Added channel value
        };
        
        // If in edit mode (recordIdForIntegration is set), include the record ID for update
        if (this.recordIdForIntegration) {
            newMapping.Id = this.recordIdForIntegration;
        }
        
        showLog('[handleSuccessIntegration] Mapping to save:', newMapping);

        saveMasterDataSetting({ mappingReq: newMapping })
            .then(() => {
                // this.showToast(LABEL_TOAST_SAVE_SUCCESS, '', VARIANT_SUCCESS);
                this.isIntegrationAdd = false;
                this.recordIdForIntegration = undefined; // Reset
                // Reset form data
                this.integrationFormData = {
                    selectedRoles: [],
                    section: '',
                    fieldStatus: true,
                    fieldReadOnly: false,
                    fieldMandatory: false
                };
                return refreshApex(this.wiredFraudResult);
            })
            .catch(error => this.showToast(LABEL_TOAST_ERROR, error.body?.message || error.message, VARIANT_ERROR))
            .finally(() => {
                this.isLoading = false;
                showLog('[handleSuccessIntegration] RETURN');
            });
    }
    handleEditRow(id) {
        showLog('[handleEditRow] START - RecordId:', id);
        this.recordIdForEdit = id;
        // Tìm record trong processedData để debug
        const foundRecord = this.processedData.find(r => r.Id === id);
        showLog('[handleEditRow] Found Record:', foundRecord);
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
                this.handleDeleteRow(rowId);
                break;
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
        if (confirm(LABEL_CONFIRM_DELETE_PROPERTY)) {
            try {
                await deleteMasterDataSetting({ recordId });
                this.showToast(LABEL_TOAST_DELETED_SUCCESS, '', VARIANT_SUCCESS);
                refreshApex(this.wiredMasterDataResult);
            } catch (error) {
                this.showToast(LABEL_TOAST_ERROR, error.body.message, VARIANT_ERROR);
            }
        }
    }

    openNewSettingModal() {
        this.modalTitle = this.labelModalNewProperty || LABEL_MODAL_NEW_PROPERTY_TITLE;
        this.recordIdForEdit = null;
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
    }

    handleSuccess() {
        try {
            this.closeModal();
            this.showToast(LABEL_TOAST_SAVE_SUCCESS, '', VARIANT_SUCCESS);
            
            showLog('[handleSuccess] START - refreshing data');
            this.isLoading = true;
            
            // Refresh the wire adapter - this will trigger wiredProperties callback
            if (this.wiredMasterDataResult) {
                refreshApex(this.wiredMasterDataResult)
                    .then(() => {
                        showLog('[handleSuccess] refreshApex completed successfully');
                        // Data should be updated now via wiredProperties callback
                        // processedData should be updated automatically
                        this.isLoading = false;
                    })
                    .catch(refreshError => {
                        showLog('[handleSuccess] refreshApex error:', refreshError);
                        console.error('Error refreshing wire adapter:', refreshError);
                        this.isLoading = false;
                    });
            } else {
                showLog('[handleSuccess] wiredMasterDataResult is not available');
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
    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.processedData));

        // Hàm so sánh
        const keyValue = (a) => {
            return a[fieldName];
        };

        const isReverse = direction === DEFAULT_SORT_DIRECTION_ASC ? 1 : -1;

        parseData.sort((x, y) => {
            let xVal = keyValue(x) ? keyValue(x) : '';
            let yVal = keyValue(y) ? keyValue(y) : '';

            // Xử lý nếu là kiểu số (Order)
            if (typeof xVal === 'number' && typeof yVal === 'number') {
                return isReverse * (xVal - yVal);
            }

            // Mặc định so sánh chuỗi (String)
            return isReverse * ((xVal > yVal) - (yVal > xVal));
        });

        this.processedData = parseData;
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
    get isOrderSorted() { return this.sortedBy === FIELD_FIELD_ORDER_DISPLAY; }

    get computedIconClass() {
        let baseClass = CSS_BASE_SML_LEFT;
        let statusClass = STATUS_CLASS_BLUE;
        const status = this.ChangeStatus;
        showLog('computedIconClass status', status);

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
            showLog('[wiredRoles] Fetched roles:', result.data);
            this.roleOptions = result.data;
        } else if (result.error) {
            showLog('[wiredRoles] ERROR:', result.error);
        }
    }

    // --- Integration Form Handlers ---
    handleSelectRole(event) {
        const selectedRole = event.detail.value;
        if (selectedRole && !this.integrationFormData.selectedRoles.includes(selectedRole)) {
            this.integrationFormData.selectedRoles = [...this.integrationFormData.selectedRoles, selectedRole];
            showLog('[handleSelectRole] Role added:', selectedRole);
        }
    }

    handleRemoveRole(event) {
        // Try multiple ways to get the role name from the pill
        let roleToRemove = event.detail.name; // Standard way
        
        showLog('[handleRemoveRole] event.detail:', event.detail);
        showLog('[handleRemoveRole] event.detail.name:', roleToRemove);
        
        // Fallback: try to get from currentTarget attributes
        if (!roleToRemove) {
            roleToRemove = event.currentTarget.getAttribute('name');
            showLog('[handleRemoveRole] Fallback to currentTarget.name:', roleToRemove);
        }
        
        // Fallback 2: try data-role attribute
        if (!roleToRemove) {
            roleToRemove = event.currentTarget.getAttribute('data-role');
            showLog('[handleRemoveRole] Fallback to data-role:', roleToRemove);
        }
        
        // Fallback 3: try label attribute
        if (!roleToRemove) {
            roleToRemove = event.currentTarget.getAttribute('label');
            showLog('[handleRemoveRole] Fallback to label:', roleToRemove);
        }
        
        if (!roleToRemove) {
            showLog('[handleRemoveRole] ERROR: Could not find role name from any source');
            return;
        }
        
        showLog('[handleRemoveRole] Final roleToRemove:', roleToRemove);
        
        this.integrationFormData = {
            ...this.integrationFormData,
            selectedRoles: this.integrationFormData.selectedRoles.filter(
                role => role !== roleToRemove
            )
        };
        
        showLog('[handleRemoveRole] Role removed successfully. Remaining roles:', this.integrationFormData.selectedRoles);
    }

    handleInputChange(event) {
        const fieldName = event.currentTarget.dataset.field;
        const value = event.detail.value;
        
        if (fieldName === 'section') {
            this.integrationFormData.section = value;
            showLog('[handleInputChange] Section updated:', value);
        }
    }

    handleCheckboxChange(event) {
        const fieldName = event.currentTarget.dataset.field;
        const value = event.detail.checked;
        
        if (fieldName === 'fieldStatus') {
            this.integrationFormData.fieldStatus = value;
        } else if (fieldName === 'fieldReadOnly') {
            this.integrationFormData.fieldReadOnly = value;
        } else if (fieldName === 'fieldMandatory') {
            this.integrationFormData.fieldMandatory = value;
        }
        showLog(`[handleCheckboxChange] ${fieldName} updated:`, value);
    }

    /**
     * Handle delete fraud integration mapping
     * @param {Event} event - Click event from delete button
     */
    handleDeleteFraud(event) {
        const recordId = event.currentTarget.dataset.id;
        
        if (!recordId) {
            this.showToast(LABEL_TOAST_ERROR, 'Record ID not found', VARIANT_ERROR);
            return;
        }

        // Show confirmation dialog
        const confirmed = confirm('Bạn có chắc chắn muốn xóa fraud integration mapping này? Hành động này không thể hoàn tác.');
        
        if (!confirmed) {
            return;
        }

        this.isLoading = true;
        showLog('[handleDeleteFraud] START - recordId:', recordId);

        // Call Apex to delete record
        deleteFraudIntegrationMapping({ recordId: recordId })
            .then(() => {
                showLog('[handleDeleteFraud] Delete successful');
                this.showToast(LABEL_TOAST_SUCCESS, LABEL_TOAST_DELETED_SUCCESS, VARIANT_SUCCESS);
                
                // Refresh the fraud data
                return refreshApex(this.wiredFraudResult);
            })
            .then(() => {
                showLog('[handleDeleteFraud] Data refreshed successfully');
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                const errorMessage = error.body?.message || error.message || 'Lỗi khi xóa fraud integration mapping';
                showLog('[handleDeleteFraud] ERROR:', error);
                this.showToast(LABEL_TOAST_ERROR, errorMessage, VARIANT_ERROR);
                console.error('Delete error:', error);
            });
    }
}