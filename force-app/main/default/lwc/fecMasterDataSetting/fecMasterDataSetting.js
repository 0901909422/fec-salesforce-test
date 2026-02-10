import { api, LightningElement, track, wire } from 'lwc';
import getMasterDataSettings from '@salesforce/apex/FEC_MasterDataSettingController.getMasterDataSettings';
import deleteMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.deleteRecord';
import saveMasterDataSetting from '@salesforce/apex/FEC_MasterDataSettingController.saveMasterDataSetting';
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
import { FIELD_SECTION, FIELD_FIELD_ORDER_DISPLAY, TYPE_TEXT, TYPE_BOOLEAN, STATUS_NEW, STATUS_UPDATE, CUST_TYPE_NON_EXISTING, CUST_TYPE_EXISTING, ICON_CHEVRON_RIGHT, ICON_CHEVRON_DOWN, MASTER_DATA_SETTING_COLUMNS, STATUS_CLASS_BLUE, STATUS_CLASS_RED, STATUS_CLASS_YELLOW, CUST_CLASS_ALL, CUST_CLASS_NON_EXISTING, CUST_CLASS_EXISTING, DEFAULT_SORT_FIELD, DEFAULT_SORT_DIRECTION_ASC, DEFAULT_SORT_DIRECTION_DESC, FIELD_ADDITIONAL_FIELD_NAME, FIELD_OBJECT_FRAUD_INTEGRATION, ICON_ARROW_UP, ICON_ARROW_DOWN, CSS_BASE_SML_LEFT, FIELD_CHANNEL, FIELD_APPLICABLE_ROLE } from 'c/fecConstants';

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
    @track stageId;
    @track currentNatureOfCaseId;
    @track FEC_Customer_Type;

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
        this.wiredMasterDataResult = result;
        const { data, error } = result;

        if (data) {
            showLog('wiredProperties DATA: ', data);
            this.masterDataList = data;
            // XỬ LÝ DATA NGAY TẠI ĐÂY (Thay thế cho Getter)
            this.processedData = data.map(row => {
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
                    // Map thêm label cho Property Name từ quan hệ __r
                    FEC_Additional_Field_Name: row.FEC_Additional_Field__r ? row.FEC_Additional_Field__r.Name : '',
                    dynamicIconClass: `${CSS_BASE_SML_LEFT} ${statusClass}`,
                    customerIconClass: `${CSS_BASE_SML_LEFT} ${custTypeClass}`
                };
            });
            this.sortData(this.sortedBy, this.sortDirection);
            this.error = undefined;
            // showLog('wiredProperties DATA', data);
        } else if (error) {
            this.error = error;
            showLog('wiredProperties ERROR', error);
            this.showToast(LABEL_TOAST_ERROR, 'Load Properties failed', VARIANT_ERROR);
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
            this.ChangeStatus = record.Process_Change_Status__c;
            showLog('processMasterData ChangeStatus', this.ChangeStatus);
            return {

                ...record,
                FEC_Stage_Name_Name: record.FEC_Stage_Name__r?.Name || '',
                FEC_Additional_Field_Name: record.FEC_Additional_Field__r?.Name || '',
                FEC_Channel_Name_Name: record.FEC_Channel__r?.Name || LABEL_DEFAULT_CHANNEL_NAME,
                FEC_Field_Status__c: !!record.FEC_Field_Status__c,            // Thuộc tính phục vụ UI Expand
                isExpanded: false,
                expandIcon: ICON_CHEVRON_RIGHT,
                // Các field giả định từ hình của bạn (cần mapping đúng API Name thực tế)
                Product_Line__c: record.FEC_Data_Integration_Mapping__r?.Product_Line__c || LABEL_DEFAULT_PRODUCT_LINE,
                Service_Type__c: record.FEC_Data_Integration_Mapping__r?.Service_Type__c || LABEL_DEFAULT_SERVICE_TYPE,
                Category__c: record.FEC_Data_Integration_Mapping__r?.Category__c || LABEL_DEFAULT_CATEGORY,
                Sub_Category__c: record.FEC_Data_Integration_Mapping__r?.Sub_Category__c || LABEL_DEFAULT_SUB_CATEGORY
            };
        });
    }

    /**
    * @description Xử lý đóng/mở dòng để hiển thị component chỉnh sửa.
    */
    toggleExpand(event) {
        const recordId = event.currentTarget.dataset.id;
        showLog('[toggleExpand] RecordId: ' + recordId);

        this.fraudDataList = this.fraudDataList.map(item => {
            if (item.Id === recordId) {
                const newStatus = !item.isExpanded;
                return {
                    ...item,
                    isExpanded: newStatus,
                    expandIcon: newStatus ? ICON_CHEVRON_DOWN : ICON_CHEVRON_RIGHT
                };
            }
            // Tùy chọn: Đóng các dòng khác khi mở dòng mới
            return { ...item, isExpanded: false, expandIcon: ICON_CHEVRON_RIGHT };
        });
    }

    /**
     * @description Xử lý khi người dùng chọn một Stage khác trên Flow.
     * Cần reset các biến trạng thái để tránh việc hiển thị dữ liệu cũ của Stage trước đó.
     */
    handleStageClick(event) {
        showLog('[handleStageClick] START');

        // 1. Cập nhật Stage Id mới
        this.stageId = event.detail;

        // 2. Reset dữ liệu danh sách về null/undefined để UI hiển thị trạng thái loading hoặc trống
        this.masterDataList = undefined;
        this.fraudDataList = undefined;

        // 3. Đóng các form edit/add đang mở
        this.isIntegrationAdd = false;
        this.selectedMappingId = null;
        this.isModalOpen = false;

        showLog('[handleStageClick] StageId: ' + this.stageId);
    }

    // --- Action Handlers ---
    handleAddIntegration() {
        this.selectedMappingId = null;
        this.isIntegrationAdd = true;
    }

    handleSaveIntegration() {
        const child = this.template.querySelector('c-fec-integration-mapping');
        if (child) child.handleSave();
    }

    handleCancelIntegration() {
        this.isIntegrationAdd = false;
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

        const recordId = event.currentTarget?.dataset?.id;
        showLog('[handleSuccessIntegration] RecordId:', recordId);

        const integrationId = event.detail.mappingId;

        const newMapping = {
            Id: recordId,
            FEC_Data_Integration_Mapping__c: integrationId,
            FEC_Field_Object_Name__c: FIELD_OBJECT_FRAUD_INTEGRATION,
            FEC_Nature_Of_Case__c: this.currentNatureOfCaseId,
            FEC_Stage_Name__c: this.stageId,
            FEC_Customer_Type__c: this.FEC_Customer_Type,
            FEC_Field_Mandatory__c: false,
            FEC_Field_ReadOnly__c: false,
            FEC_Field_Editable__c: true,
            FEC_Field_Status__c: true
        };
        showLog('[handleSuccessIntegration] New Master Data Setting:', newMapping);

        saveMasterDataSetting({ mappingReq: newMapping })
            .then(() => {
                this.showToast(LABEL_TOAST_SAVE_SUCCESS, '', VARIANT_SUCCESS);
                this.isIntegrationAdd = false;
                return refreshApex(this.wiredFraudResult);
            })
            .catch(error => this.showToast(LABEL_TOAST_ERROR, error.body.message, VARIANT_ERROR))
            .finally(() => {
                this.isLoading = false;
                showLog('[handleSuccessIntegration] RETURN');
            });
    }
    handleEditRow(id) {
        this.recordIdForEdit = id;
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
        this.closeModal();
        this.showToast(LABEL_TOAST_SAVE_SUCCESS, '', VARIANT_SUCCESS);
        refreshApex(this.wiredMasterDataResult);
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
        let parseData = JSON.parse(JSON.stringify(this.masterDataList));

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

        this.masterDataList = parseData;
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
}