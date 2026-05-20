import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { showLog } from 'c/fecMDMUtils';
import getAllMasterData from '@salesforce/apex/FEC_CleanUpMasterDataController.getAllMasterData';
import syncDataToMDM from '@salesforce/apex/FEC_CleanUpMasterDataController.syncDataToMDM';
import pushMDMToLive from '@salesforce/apex/FEC_CleanUpMasterDataController.pushMDMToLive';

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
import LABEL_BP from '@salesforce/label/c.FEC_Label_Business_Process';
import LABEL_TAB_ACTION_BUTTON from '@salesforce/label/c.FEC_Tab_Action_Button';
import LABEL_TAB_STAGE_CHANGE from '@salesforce/label/c.FEC_Tab_Stage_Change';
import LABEL_COL_PREVIOUS_STAGE from '@salesforce/label/c.FEC_Col_Previous_Stage';
import LABEL_COL_NEXT_STAGE from '@salesforce/label/c.FEC_Col_Next_Stage';
import LABEL_COL_ACTION_BUTTON from '@salesforce/label/c.FEC_Col_Action_Button';
import LABEL_COL_NEXT_QUEUE from '@salesforce/label/c.FEC_Col_Next_Queue';
import LABEL_COL_TEAM_USER_GROUP from '@salesforce/label/c.FEC_Col_Team_User_Group';
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
import LABEL_SEARCH_ALL from '@salesforce/label/c.FEC_Search_All_Columns';
import LABEL_NO_DATA from '@salesforce/label/c.FEC_No_Data_Found';

import {
    FIELD_ID, FIELD_EXTERNAL_ID, FIELD_NAME, FIELD_ALIAS, FIELD_CODE, FIELD_NAME_VN,
    FIELD_POS_ORDER, FIELD_STATUS, FIELD_PROCESS_STATUS, FIELD_ADDITIONAL_FIELD,
    FIELD_CHANNEL, FIELD_APPLICABLE_ROLE, FIELD_STAGE_NAME, FIELD_DATA_INTEGRATION_MAPPING,
    FIELD_FEC_TYPE, FIELD_ORDER_GENERIC, FIELD_FEC_PRODUCT_TYPE_NAME,
    FIELD_FEC_BUSINESS_PROCESS_NAME, FIELD_FEC_CATEGORY_NAME, FIELD_FEC_SUB_CATEGORY_NAME,
    FIELD_FEC_SUB_CODE, TYPE_NUMBER, VARIANT_SUCCESS, VARIANT_ERROR, VARIANT_INFO
} from 'c/fecConstants';

const PAGE_SIZE = 20;

// Tab keys mapping to data property names
const TAB_KEYS = [
    'ProductType', 'BusinessProcess', 'Category', 'SubCategory', 'SubCode',
    'MasterSetting', 'Channel', 'NatureOfCase', 'AdditionalField',
    'AdditionalFieldList', 'CaseStage', 'ActionButton', 'StageChange'
];

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
    labelTabActionButton = LABEL_TAB_ACTION_BUTTON;
    labelTabStageChange = LABEL_TAB_STAGE_CHANGE;
    labelSearchAll = LABEL_SEARCH_ALL;
    labelNoData = LABEL_NO_DATA;

    @track data = {};
    @track isSyncing = false;
    wiredDataResult;

    // Search & pagination state per tab
    @track searchTerms = {};
    @track currentPages = {};
    pageSize = PAGE_SIZE;

    columnsBasic = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_EXTERNALID, fieldName: FIELD_EXTERNAL_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_COL_ALIAS, fieldName: FIELD_ALIAS },
        { label: LABEL_COL_NAME_VN, fieldName: FIELD_NAME_VN },
        { label: LABEL_COL_ORDER, fieldName: FIELD_POS_ORDER },
        { label: LABEL_COL_STATUS, fieldName: FIELD_STATUS },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS },
        { label: 'Active', fieldName: 'FEC_Active__c', type: 'boolean' }
    ];

    columnsMsSetting = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_EXTERNALID, fieldName: FIELD_EXTERNAL_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_COL_ADDITIONAL_FIELD, fieldName: FIELD_ADDITIONAL_FIELD },
        { label: 'FEC_Nature_Of_Case__c', fieldName: 'FEC_Nature_Of_Case__c' },
        { label: LABEL_COL_CHANNEL, fieldName: FIELD_CHANNEL },
        { label: LABEL_COL_APPLICABLE_ROLE, fieldName: FIELD_APPLICABLE_ROLE },
        { label: LABEL_COL_STAGE, fieldName: FIELD_STAGE_NAME },
        { label: LABEL_COL_INTEGRATION, fieldName: FIELD_DATA_INTEGRATION_MAPPING },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS }
    ];

    columnsSetting = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: 'FEC_Additional_Field__c', fieldName: 'FEC_Additional_Field__c' },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS }
    ];

    columnsNOC = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_NOC_PRODUCT, fieldName: FIELD_FEC_PRODUCT_TYPE_NAME },
        { label: LABEL_NOC_BP, fieldName: FIELD_FEC_BUSINESS_PROCESS_NAME },
        { label: LABEL_NOC_CATEGORY, fieldName: FIELD_FEC_CATEGORY_NAME },
        { label: LABEL_NOC_SUB_CATEGORY, fieldName: FIELD_FEC_SUB_CATEGORY_NAME },
        { label: LABEL_NOC_SUB_CODE, fieldName: FIELD_FEC_SUB_CODE }
    ];

    columnsField = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_EXTERNALID, fieldName: FIELD_EXTERNAL_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_TYPE, fieldName: FIELD_FEC_TYPE },
        { label: LABEL_COL_NAME_VN, fieldName: FIELD_NAME_VN },
        { label: LABEL_COL_PROCESS_STATUS, fieldName: FIELD_PROCESS_STATUS }
    ];

    columnsStage = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_BP, fieldName: 'FEC_Business_Process__c' },
        { label: LABEL_COL_ORDER, fieldName: FIELD_ORDER_GENERIC, type: TYPE_NUMBER }
    ];

    columnsActionButton = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_TYPE, fieldName: 'FEC_Type__c' },
        { label: 'Apex Class', fieldName: 'FEC_Apex_Class__c' },
        { label: 'Flow ID', fieldName: 'FEC_FlowID__c' },
        { label: 'Active', fieldName: 'FEC_Active__c', type: 'boolean' }
    ];

    columnsStageChange = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: 'Code' },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_COL_PREVIOUS_STAGE, fieldName: 'FEC_Previous_Stage_Name' },
        { label: LABEL_COL_ACTION_BUTTON, fieldName: 'FEC_Action_Button_Name' },
        { label: LABEL_COL_NEXT_STAGE, fieldName: 'FEC_Next_Stage_Name' },
        { label: LABEL_COL_NEXT_QUEUE, fieldName: 'FEC_Next_Queue' },
        { label: LABEL_COL_TEAM_USER_GROUP, fieldName: 'FEC_Team_User_Group' },
        { label: 'Active', fieldName: 'FEC_Active', type: 'boolean' }
    ];

    // Column map per tab key for search filtering
    get _columnMap() {
        return {
            ProductType: this.columnsBasic,
            BusinessProcess: this.columnsBasic,
            Category: this.columnsBasic,
            SubCategory: this.columnsBasic,
            SubCode: this.columnsBasic,
            MasterSetting: this.columnsMsSetting,
            Channel: this.columnsSetting,
            NatureOfCase: this.columnsNOC,
            AdditionalField: this.columnsField,
            AdditionalFieldList: this.columnsSetting,
            CaseStage: this.columnsStage,
            ActionButton: this.columnsActionButton,
            StageChange: this.columnsStageChange
        };
    }

    @wire(getAllMasterData)
    wiredData(result) {
        this.wiredDataResult = result;
        const { error, data } = result;
        if (data) {
            this.data = data;
            // Reset pagination when data refreshes
            this._resetAllPages();
            showLog('getAllMasterData data', data);
        } else if (error) {
            showLog('getAllMasterData error', error);
            console.error(error);
        }
    }

    // --- Search & Pagination helpers ---

    _getFilteredData(tabKey) {
        const allRows = this.data[tabKey] || [];
        const term = (this.searchTerms[tabKey] || '').toLowerCase().trim();
        if (!term) return allRows;

        const columns = this._columnMap[tabKey] || [];
        const fieldNames = columns.map(c => c.fieldName);

        return allRows.filter(row =>
            fieldNames.some(field => {
                const val = row[field];
                if (val == null) return false;
                return String(val).toLowerCase().includes(term);
            })
        );
    }

    _getPagedData(tabKey) {
        const filtered = this._getFilteredData(tabKey);
        const page = this.currentPages[tabKey] || 1;
        const start = (page - 1) * this.pageSize;
        return filtered.slice(start, start + this.pageSize);
    }

    _getTotalPages(tabKey) {
        const filtered = this._getFilteredData(tabKey);
        return Math.max(1, Math.ceil(filtered.length / this.pageSize));
    }

    _getTotalRecords(tabKey) {
        return this._getFilteredData(tabKey).length;
    }

    _resetAllPages() {
        const pages = {};
        TAB_KEYS.forEach(k => { pages[k] = 1; });
        this.currentPages = pages;
    }

    // --- Event handlers ---

    handleSearch(event) {
        const tabKey = event.target.dataset.tab;
        const value = event.target.value;
        this.searchTerms = { ...this.searchTerms, [tabKey]: value };
        this.currentPages = { ...this.currentPages, [tabKey]: 1 };
    }

    // --- Paged data getters per tab ---

    get pagedProductType() { return this._getPagedData('ProductType'); }
    get pagedBusinessProcess() { return this._getPagedData('BusinessProcess'); }
    get pagedCategory() { return this._getPagedData('Category'); }
    get pagedSubCategory() { return this._getPagedData('SubCategory'); }
    get pagedSubCode() { return this._getPagedData('SubCode'); }
    get pagedMasterSetting() { return this._getPagedData('MasterSetting'); }
    get pagedChannel() { return this._getPagedData('Channel'); }
    get pagedNatureOfCase() { return this._getPagedData('NatureOfCase'); }
    get pagedAdditionalField() { return this._getPagedData('AdditionalField'); }
    get pagedAdditionalFieldList() { return this._getPagedData('AdditionalFieldList'); }
    get pagedCaseStage() { return this._getPagedData('CaseStage'); }
    get pagedActionButton() { return this._getPagedData('ActionButton'); }
    get pagedStageChange() { return this._getPagedData('StageChange'); }

    // --- Per-tab current page getters ---
    get currentPageProductType() { return this.currentPages.ProductType || 1; }
    get currentPageBusinessProcess() { return this.currentPages.BusinessProcess || 1; }
    get currentPageCategory() { return this.currentPages.Category || 1; }
    get currentPageSubCategory() { return this.currentPages.SubCategory || 1; }
    get currentPageSubCode() { return this.currentPages.SubCode || 1; }
    get currentPageMasterSetting() { return this.currentPages.MasterSetting || 1; }
    get currentPageChannel() { return this.currentPages.Channel || 1; }
    get currentPageNatureOfCase() { return this.currentPages.NatureOfCase || 1; }
    get currentPageAdditionalField() { return this.currentPages.AdditionalField || 1; }
    get currentPageAdditionalFieldList() { return this.currentPages.AdditionalFieldList || 1; }
    get currentPageCaseStage() { return this.currentPages.CaseStage || 1; }
    get currentPageActionButton() { return this.currentPages.ActionButton || 1; }
    get currentPageStageChange() { return this.currentPages.StageChange || 1; }

    // --- Per-tab total records getters ---
    get totalRecordsProductType() { return this._getTotalRecords('ProductType'); }
    get totalRecordsBusinessProcess() { return this._getTotalRecords('BusinessProcess'); }
    get totalRecordsCategory() { return this._getTotalRecords('Category'); }
    get totalRecordsSubCategory() { return this._getTotalRecords('SubCategory'); }
    get totalRecordsSubCode() { return this._getTotalRecords('SubCode'); }
    get totalRecordsMasterSetting() { return this._getTotalRecords('MasterSetting'); }
    get totalRecordsChannel() { return this._getTotalRecords('Channel'); }
    get totalRecordsNatureOfCase() { return this._getTotalRecords('NatureOfCase'); }
    get totalRecordsAdditionalField() { return this._getTotalRecords('AdditionalField'); }
    get totalRecordsAdditionalFieldList() { return this._getTotalRecords('AdditionalFieldList'); }
    get totalRecordsCaseStage() { return this._getTotalRecords('CaseStage'); }
    get totalRecordsActionButton() { return this._getTotalRecords('ActionButton'); }
    get totalRecordsStageChange() { return this._getTotalRecords('StageChange'); }

    // --- Pagination event handlers ---
    handleTabPageChange(event) {
        const tabKey = event.target.dataset.tab;
        this.currentPages = { ...this.currentPages, [tabKey]: event.detail.page };
    }

    handleTabPageSizeChange(event) {
        this.pageSize = event.detail.pageSize;
        this._resetAllPages();
    }

    // --- Original action handlers ---

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
            await refreshApex(this.wiredDataResult);
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
            await refreshApex(this.wiredDataResult);
        } catch (error) {
            this.showToast(LABEL_TOAST_ERROR, error.body?.message || error.message, VARIANT_ERROR);
        } finally {
            this.isSyncing = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}