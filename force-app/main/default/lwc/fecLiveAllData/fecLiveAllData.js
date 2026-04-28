import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllLiveMasterData from '@salesforce/apex/FEC_LiveDataViewController.getAllLiveMasterData';

import LABEL_TITLE from '@salesforce/label/c.FEC_AllMasterData_Title';
import LABEL_REFRESH from '@salesforce/label/c.FEC_Refresh_Data';
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
import LABEL_TAB_ACTION_BUTTON from '@salesforce/label/c.FEC_Tab_Action_Button';
import LABEL_TAB_STAGE_CHANGE from '@salesforce/label/c.FEC_Tab_Stage_Change';
import LABEL_TOAST_REFRESH_SUCCESS from '@salesforce/label/c.FEC_Toast_Refresh_Success';
import LABEL_TOAST_REFRESH_ERROR from '@salesforce/label/c.FEC_Toast_Refresh_Error';
import LABEL_BP from '@salesforce/label/c.FEC_Label_Business_Process';
import LABEL_COL_ID from '@salesforce/label/c.FEC_Col_ID';
import LABEL_COL_EXTERNALID from '@salesforce/label/c.FEC_Col_ExternalID';
import LABEL_COL_NAME from '@salesforce/label/c.FEC_Col_Name';
import LABEL_COL_ALIAS from '@salesforce/label/c.FEC_Col_Alias';
import LABEL_COL_CODE from '@salesforce/label/c.FEC_Col_Code';
import LABEL_COL_NAME_VN from '@salesforce/label/c.FEC_Col_Name_VN';
import LABEL_COL_ORDER from '@salesforce/label/c.FEC_Col_Order';
import LABEL_COL_STATUS from '@salesforce/label/c.FEC_Col_Status';
import LABEL_COL_PREVIOUS_STAGE from '@salesforce/label/c.FEC_Col_Previous_Stage';
import LABEL_COL_NEXT_STAGE from '@salesforce/label/c.FEC_Col_Next_Stage';
import LABEL_COL_ACTION_BUTTON from '@salesforce/label/c.FEC_Col_Action_Button';
import LABEL_COL_NEXT_QUEUE from '@salesforce/label/c.FEC_Col_Next_Queue';
import LABEL_COL_TEAM_USER_GROUP from '@salesforce/label/c.FEC_Col_Team_User_Group';
import LABEL_TYPE from '@salesforce/label/c.FEC_Label_Type';
import LABEL_NOC_PRODUCT from '@salesforce/label/c.FEC_NOC_Product_Type';
import LABEL_NOC_BP from '@salesforce/label/c.FEC_NOC_Business_Process';
import LABEL_NOC_CATEGORY from '@salesforce/label/c.FEC_NOC_Category';
import LABEL_NOC_SUB_CATEGORY from '@salesforce/label/c.FEC_NOC_Sub_Category';
import LABEL_NOC_SUB_CODE from '@salesforce/label/c.FEC_NOC_Sub_Code';

import {
    FIELD_ID, FIELD_NAME, FIELD_ALIAS, FIELD_CODE, FIELD_NAME_VN,
    FIELD_POS_ORDER, FIELD_STATUS, FIELD_FEC_TYPE, FIELD_ORDER,
    FIELD_FEC_PRODUCT_TYPE_NAME, FIELD_FEC_BUSINESS_PROCESS_NAME,
    FIELD_FEC_CATEGORY_NAME, FIELD_FEC_SUB_CATEGORY_NAME, FIELD_FEC_SUB_CODE,
    TYPE_NUMBER, VARIANT_SUCCESS, VARIANT_ERROR
} from 'c/fecConstants';

export default class FecLiveAllData extends LightningElement {
    labelTitle = LABEL_TITLE;
    labelRefresh = LABEL_REFRESH;
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

    @track data = {};
    isLoading = true;

    // Columns for 5 basic lookup objects (Product Type, BP, Category, Sub Category, Sub Code)
    columnsBasic = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_COL_ALIAS, fieldName: FIELD_ALIAS },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME_VN, fieldName: FIELD_NAME_VN },
        { label: LABEL_COL_STATUS, fieldName: FIELD_STATUS },
        { label: 'Active', fieldName: 'FEC_Active__c', type: 'boolean' }
    ];

    // Columns for Master Setting
    columnsMsSetting = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: 'FEC_Nature_Of_Case__c', fieldName: 'FEC_Nature_Of_Case__c' },
        { label: 'FEC_Stage_Name__c', fieldName: 'FEC_Stage_Name__c' },
        { label: 'FEC_Channel__c', fieldName: 'FEC_Channel__c' }
    ];

    // Columns for Channel
    columnsSetting = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME }
    ];

    // Columns for Nature of Case (mapped to NatureOfCaseWrapper)
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

    // Columns for Additional Field
    columnsField = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_TYPE, fieldName: FIELD_FEC_TYPE },
        { label: LABEL_COL_NAME_VN, fieldName: FIELD_NAME_VN }
    ];

    // Columns for Case Stage
    columnsStage = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_BP, fieldName: 'FEC_Business_Process__c' },
        { label: LABEL_COL_ORDER, fieldName: FIELD_ORDER, type: TYPE_NUMBER }
    ];

    // Columns for Action Button
    columnsActionButton = [
        { label: LABEL_COL_ID, fieldName: FIELD_ID },
        { label: LABEL_COL_CODE, fieldName: FIELD_CODE },
        { label: LABEL_COL_NAME, fieldName: FIELD_NAME },
        { label: LABEL_TYPE, fieldName: 'FEC_Type__c' },
        { label: 'Apex Class', fieldName: 'FEC_Apex_Class__c' },
        { label: 'Flow ID', fieldName: 'FEC_FlowID__c' },
        { label: 'Active', fieldName: 'FEC_Active__c', type: 'boolean' }
    ];

    // Columns for Stage Change (mapped to StageChangeWrapper)
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

    get hasData() {
        return this.data && Object.keys(this.data).length > 0;
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isLoading = true;
        getAllLiveMasterData()
            .then(result => {
                this.data = result || {};
            })
            .catch(error => {
                this.data = {};
                this.showErrorToast(error.body?.message || error.message || 'Error loading live master data');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRefresh() {
        this.loadData();
        this.showToast(LABEL_TOAST_REFRESH_SUCCESS, '', VARIANT_SUCCESS);
    }

    showErrorToast(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: message,
            variant: VARIANT_ERROR
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}