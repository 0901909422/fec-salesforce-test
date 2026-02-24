import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex'; // 1. Import refreshApex
import getAllMasterData from '@salesforce/apex/FEC_CleanUpMasterDataController.getAllMasterData';
import syncDataToMDM from '@salesforce/apex/FEC_CleanUpMasterDataController.syncDataToMDM';
import pushMDMToLive from '@salesforce/apex/FEC_CleanUpMasterDataController.pushMDMToLive'; // Nút mới

import LABEL_TITLE from '@salesforce/label/c.FEC_AllMasterData_Title';
import LABEL_REFRESH from '@salesforce/label/c.FEC_Refresh_Data';
import LABEL_RESET_MDM from '@salesforce/label/c.FEC_Reset_MDM';
import LABEL_PUSH_MDM from '@salesforce/label/c.FEC_Push_MDM_To_Live';
import LABEL_TAB_PRODUCT from '@salesforce/label/c.FEC_Tab_Product_Type';
import LABEL_TAB_BP from '@salesforce/label/c.FEC_Tab_Business_Process';
import LABEL_TAB_CATEGORY from '@salesforce/label/c.FEC_Tab_Category';
import LABEL_TAB_SUB_CATEGORY from '@salesforce/label/c.FEC_Tab_Sub_Category';
import LABEL_TAB_SUB_CODE from '@salesforce/label/c.FEC_Tab_Sub_Code';
import LABEL_TAB_MASTER_SETTING from '@salesforce/label/c.FEC_Tab_Master_Setting';
import LABEL_TAB_CHANNEL from '@salesforce/label/c.FEC_Tab_Channel';
import LABEL_TAB_NOC from '@salesforce/label/c.FEC_Tab_Nature_Of_Case';
import LABEL_TAB_ADD_FIELD from '@salesforce/label/c.FEC_Tab_Additional_Field';
import LABEL_TAB_ADD_FIELD_LIST from '@salesforce/label/c.FEC_Tab_Additional_Field_List_Value';
import LABEL_TAB_CASE_STAGE from '@salesforce/label/c.FEC_Tab_Case_Stage';
import { FIELD_ID, FIELD_EXTERNAL_ID, FIELD_NAME, FIELD_ALIAS, FIELD_CODE, FIELD_NAME_VN, FIELD_POS_ORDER, FIELD_STATUS, FIELD_PROCESS_STATUS } from 'c/fecConstants';
import LABEL_COL_ID from '@salesforce/label/c.FEC_Col_ID';
import LABEL_COL_EXTERNALID from '@salesforce/label/c.FEC_Col_ExternalID';
import LABEL_COL_NAME from '@salesforce/label/c.FEC_Col_Name';
import LABEL_COL_ALIAS from '@salesforce/label/c.FEC_Col_Alias';
import LABEL_COL_CODE from '@salesforce/label/c.FEC_Col_Code';
import LABEL_COL_NAME_VN from '@salesforce/label/c.FEC_Col_Name_VN';
import LABEL_COL_ORDER from '@salesforce/label/c.FEC_Col_Order';
import LABEL_COL_STATUS from '@salesforce/label/c.FEC_Col_Status';
import LABEL_COL_PROCESS_STATUS from '@salesforce/label/c.FEC_Col_Process_Status';
import LABEL_COL_ADDITIONAL_FIELD from '@salesforce/label/c.FEC_Col_Additional_Field';
import LABEL_COL_CHANNEL from '@salesforce/label/c.FEC_Col_Channel';
import LABEL_COL_APPLICABLE_ROLE from '@salesforce/label/c.FEC_Col_Applicable_Role';
import LABEL_COL_STAGE from '@salesforce/label/c.FEC_Col_Stage';
import LABEL_COL_INTEGRATION from '@salesforce/label/c.FEC_Col_Integration';
import LABEL_TOAST_REFRESH_SUCCESS from '@salesforce/label/c.FEC_Toast_Refresh_Success';
import LABEL_TOAST_REFRESH_ERROR from '@salesforce/label/c.FEC_Toast_Refresh_Error';
import LABEL_CONFIRM_SYNC from '@salesforce/label/c.FEC_Confirm_Sync_Question';
import LABEL_NOTIFY_SYNC_STARTED from '@salesforce/label/c.FEC_Notify_Sync_Started';
import LABEL_CONFIRM_PUSH from '@salesforce/label/c.FEC_Confirm_Push_Question';
import LABEL_NOTIFY_PUSH_STARTED from '@salesforce/label/c.FEC_Notify_Push_Started';
import LABEL_TOAST_ERROR from '@salesforce/label/c.FEC_Toast_Error';
import LABEL_NOC_PRODUCT from '@salesforce/label/c.FEC_NOC_Product_Type';
import LABEL_NOC_BP from '@salesforce/label/c.FEC_NOC_Business_Process';
import LABEL_NOC_CATEGORY from '@salesforce/label/c.FEC_NOC_Category';
import LABEL_NOC_SUB_CATEGORY from '@salesforce/label/c.FEC_NOC_Sub_Category';
import LABEL_NOC_SUB_CODE from '@salesforce/label/c.FEC_NOC_Sub_Code';
import LABEL_TYPE from '@salesforce/label/c.FEC_Label_Type';
import LABEL_BP from '@salesforce/label/c.FEC_Label_Business_Process';
import { FIELD_PRODUCT_TYPE_NAME, FIELD_BUSINESS_PROCESS_NAME, FIELD_CATEGORY_NAME, FIELD_SUB_CATEGORY_NAME, FIELD_SUB_CODE, FIELD_ORDER_GENERIC, FIELD_BUSINESS_PROCESS, TYPE_NUMBER, VARIANT_SUCCESS, VARIANT_ERROR, VARIANT_INFO, FIELD_ADDITIONAL_FIELD, FIELD_CHANNEL, FIELD_APPLICABLE_ROLE, FIELD_STAGE_NAME, FIELD_DATA_INTEGRATION_MAPPING, EVENT_REFRESH, EVENT_SYNC, EVENT_PUSH } from 'c/fecConstants';

export default class FecAllMasterData extends LightningElement {
    labelTitle = LABEL_TITLE;
    labelRefresh = LABEL_REFRESH;
    labelReset = LABEL_RESET_MDM;
    labelPush = LABEL_PUSH_MDM;
    labelTabProduct = LABEL_TAB_PRODUCT;
    labelTabBP = LABEL_TAB_BP;
    labelTabCategory = LABEL_TAB_CATEGORY;
    labelTabSubCategory = LABEL_TAB_SUB_CATEGORY;
    labelTabSubCode = LABEL_TAB_SUB_CODE;
    labelTabMasterSetting = LABEL_TAB_MASTER_SETTING;
    labelTabChannel = LABEL_TAB_CHANNEL;
    labelTabNOC = LABEL_TAB_NOC;
    labelTabAddField = LABEL_TAB_ADD_FIELD;
    labelTabAddFieldList = LABEL_TAB_ADD_FIELD_LIST;
    labelTabCaseStage = LABEL_TAB_CASE_STAGE;

    @track data = {};
    @track isSyncing = false;
    wiredDataResult; // Lưu kết quả wire để dùng refreshApex

    // Cột cho 5 Object lookup cơ bản
    columnsBasic = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_EXTERNALID, fieldName: FIELD_EXTERNAL_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_COL_ALIAS, fieldName: FIELD_ALIAS },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME_VN, fieldName: FIELD_NAME_VN },
        { label: LABEL_COL_ORDER, fieldName: FIELD_POS_ORDER },
        { label: LABEL_COL_STATUS, fieldName: FIELD_STATUS },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS }
    ];

    // Cột cho Master Setting
    columnsMsSetting = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_EXTERNALID, fieldName: FIELD_EXTERNAL_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_COL_ADDITIONAL_FIELD, fieldName: FIELD_ADDITIONAL_FIELD },
        { label: LABEL_COL_CHANNEL, fieldName: FIELD_CHANNEL },
        { label: LABEL_COL_APPLICABLE_ROLE, fieldName: FIELD_APPLICABLE_ROLE },
        { label: LABEL_COL_STAGE, fieldName: FIELD_STAGE_NAME },
        { label: LABEL_COL_INTEGRATION, fieldName: FIELD_DATA_INTEGRATION_MAPPING },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS }
    ];

    // Cột cho Master Setting (generic)
    columnsSetting = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_EXTERNALID, fieldName: FIELD_EXTERNAL_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS }
    ];

    // Cột cho Nature of Case (Lưu ý: Cần xử lý flatten data nếu muốn show Name của Lookup)
    columnsNOC = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_EXTERNALID, fieldName: FIELD_EXTERNAL_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_NOC_PRODUCT, fieldName: FIELD_PRODUCT_TYPE_NAME },
        { label: LABEL_NOC_BP, fieldName: FIELD_BUSINESS_PROCESS_NAME },
        { label: LABEL_NOC_CATEGORY, fieldName: FIELD_CATEGORY_NAME },
        { label: LABEL_NOC_SUB_CATEGORY, fieldName: FIELD_SUB_CATEGORY_NAME },
        { label: LABEL_NOC_SUB_CODE, fieldName: FIELD_SUB_CODE },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS }
    ];

    // Cột cho Additional Field
    columnsField = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_EXTERNALID, fieldName: FIELD_EXTERNAL_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_TYPE, fieldName: FIELD_FEC_TYPE },
        { label: LABEL_COL_NAME_VN, fieldName: FIELD_NAME_VN },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS }
    ];

    // Cột cho Case Stage
    columnsStage = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_EXTERNALID, fieldName: FIELD_EXTERNAL_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_BP, fieldName: FIELD_BUSINESS_PROCESS },
        { label: LABEL_COL_ORDER, fieldName: FIELD_ORDER_GENERIC, type: TYPE_NUMBER },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS }
    ];

    @wire(getAllMasterData)
    wiredData(result) {
        this.wiredDataResult = result;
        const { error, data } = result;
        if (data) {
            this.data = data;
        } else if (error) {
            console.error(error);
        }
    }

    // 3. Hàm xử lý khi nhấn nút Refresh
    async handleRefresh() {
        try {
            await refreshApex(this.wiredDataResult);
            this.showToast(LABEL_TOAST_REFRESH_SUCCESS, '', VARIANT_SUCCESS);
        } catch (error) {
            this.showToast(LABEL_TOAST_REFRESH_ERROR, '', VARIANT_ERROR);
        }
    }

    async handleSyncDataToMDM() {
        const confirmed = confirm(LABEL_CONFIRM_SYNC);
        if (!confirmed) return;

        this.isSyncing = true;
        try {
            await syncDataToMDM();
            this.showToast(LABEL_NOTIFY_SYNC_STARTED, '', VARIANT_INFO);
        } catch (error) {
            this.showToast(LABEL_TOAST_ERROR, error.body?.message || error.message, VARIANT_ERROR);
        } finally {
            this.isSyncing = false;
        }
    }

    async handlePushToLive() {
        const confirmed = confirm(LABEL_CONFIRM_PUSH);
        if (!confirmed) return;

        this.isSyncing = true;
        try {
            await pushMDMToLive();
            this.showToast(LABEL_NOTIFY_PUSH_STARTED, '', VARIANT_SUCCESS);
        } catch (error) {
            this.showToast(LABEL_TOAST_ERROR, error.body?.message || error.message, VARIANT_ERROR);
        } finally {
            this.isSyncing = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // expose events for parent components
    handleRefresh() { this.dispatchEvent(new CustomEvent(EVENT_REFRESH)); }
    handleSyncDataToMDM() { this.dispatchEvent(new CustomEvent(EVENT_SYNC)); }
    handlePushToLive() { this.dispatchEvent(new CustomEvent(EVENT_PUSH)); }
}