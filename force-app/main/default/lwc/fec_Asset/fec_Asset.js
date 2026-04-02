import { LightningElement, api, track } from 'lwc';
import updateCaseAssets from '@salesforce/apex/FEC_GetAssetsList.updateCaseAssets';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { formatDate } from 'c/fec_CommonUtils';

import FEC_Asset_Label from '@salesforce/label/c.FEC_Asset_Label';
import FEC_Category_Code_Label from '@salesforce/label/c.FEC_Category_Code_Label';
import FEC_Asset_Type_Label from '@salesforce/label/c.FEC_Asset_Type_Label';
import FEC_Asset_Description_Label from '@salesforce/label/c.FEC_Asset_Description_Label';
import FEC_Additional_Info_Label from '@salesforce/label/c.FEC_Additional_Info_Label';
import FEC_Asset_Model_Label from '@salesforce/label/c.FEC_Asset_Model_Label';
import FEC_Asset_Color_Label from '@salesforce/label/c.FEC_Asset_Color_Label';
import FEC_Engine_No_Label from '@salesforce/label/c.FEC_Engine_No_Label';
import FEC_Chasis_No_Label from '@salesforce/label/c.FEC_Chasis_No_Label';
import FEC_Reg_No_Label from '@salesforce/label/c.FEC_Reg_No_Label';
import FEC_Supplier_Name_Label from '@salesforce/label/c.FEC_Supplier_Name_Label';
import FEC_Asset_Cost_Label from '@salesforce/label/c.FEC_Asset_Cost_Label';
import FEC_Amount_Pledged_Label from '@salesforce/label/c.FEC_Amount_Pledged_Label';
import FEC_Make_Date_Label from '@salesforce/label/c.FEC_Make_Date_Label';
import FEC_Bought_Date_Label from '@salesforce/label/c.FEC_Bought_Date_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';

const STATUS = {
    ERROR: 'ERROR',
    NONE: 'NONE',
    EMPTY: '-',
    ERROR_TITLE: 'Error',
    ERROR_VARIANT: 'error',
    UNKNOWN_ERROR: 'Unknown error'
};

const AssetFields = {
    CATEGORY_CODE: 'FEC_Category_Code__c',
    ASSET_TYPE: 'FEC_Asset_Type__c',
    ASSET_DESCRIPTION: 'FEC_Asset_Description__c',
    ADDITIONAL_INFO: 'FEC_Additional_Info__c',
    ASSET_MODEL: 'FEC_Asset_Model__c',
    ASSET_COLOR: 'FEC_Asset_Color__c',
    ENGINE_NO: 'FEC_Engine_No__c',
    CHASIS_NO: 'FEC_Chasis_No__c',
    REG_NO: 'FEC_Reg_No__c',
    SUPPLIER_NAME: 'FEC_Supplier_Name__c',
    ASSET_COST: 'FEC_Asset_Cost__c',
    AMOUNT_PLEDGED: 'FEC_Amount_Pledged__c',
    MAKE_DATE: 'FEC_Make_Date__c',
    BOUGHT_DATE: 'FEC_Bought_Date__c'
};

export default class Fec_Asset extends LightningElement {
    @api recordId;
    @track accountData;
    @track error;
    @track isLoading = false;

    @track activeSections = [FEC_Asset_Label];

    customLabel = {
        assetLabel: FEC_Asset_Label,
        categoryCodeLabel: FEC_Category_Code_Label,
        assetTypeLabel: FEC_Asset_Type_Label,
        assetDescriptionLabel: FEC_Asset_Description_Label,
        additionalInfoLabel: FEC_Additional_Info_Label,
        assetModelLabel: FEC_Asset_Model_Label,
        assetColorLabel: FEC_Asset_Color_Label,
        engineNoLabel: FEC_Engine_No_Label,
        chasisNoLabel: FEC_Chasis_No_Label,
        regNoLabel: FEC_Reg_No_Label,
        supplierNameLabel: FEC_Supplier_Name_Label,
        assetCostLabel: FEC_Asset_Cost_Label,
        amountPledgedLabel: FEC_Amount_Pledged_Label,
        makeDateLabel: FEC_Make_Date_Label,
        boughtDateLabel: FEC_Bought_Date_Label,
        msgErrorAPI: FEC_MSG_Error_API_Label
    };

    /* ================= LIFECYCLE ================= */
    connectedCallback() {
        this.loadData();
    }

    loadData() {
        if (!this.recordId) return;

        this.isLoading = true;

        updateCaseAssets({ caseId: this.recordId })
            .then(result => {
                this.accountData = result;
                this.error = undefined;
            })
            .catch(err => {
                this.handleError(err);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ================= UI HELPERS ================= */
    get hasData() {
        return Boolean(this.accountData && Object.keys(this.accountData).length > 0);
    }

    get assetFields() {
        if (!this.accountData && !this.error) return [];

        return [
            this.buildField(this.customLabel.categoryCodeLabel, this.accountData?.[AssetFields.CATEGORY_CODE], AssetFields.CATEGORY_CODE),
            this.buildField(this.customLabel.assetTypeLabel, this.accountData?.[AssetFields.ASSET_TYPE], AssetFields.ASSET_TYPE),
            this.buildField(this.customLabel.assetDescriptionLabel, this.accountData?.[AssetFields.ASSET_DESCRIPTION], AssetFields.ASSET_DESCRIPTION),
            this.buildField(this.customLabel.additionalInfoLabel, this.accountData?.[AssetFields.ADDITIONAL_INFO], AssetFields.ADDITIONAL_INFO),
            this.buildField(this.customLabel.assetModelLabel, this.accountData?.[AssetFields.ASSET_MODEL], AssetFields.ASSET_MODEL),
            this.buildField(this.customLabel.assetColorLabel, this.accountData?.[AssetFields.ASSET_COLOR], AssetFields.ASSET_COLOR),
            this.buildField(this.customLabel.engineNoLabel, this.accountData?.[AssetFields.ENGINE_NO], AssetFields.ENGINE_NO),
            this.buildField(this.customLabel.chasisNoLabel, this.accountData?.[AssetFields.CHASIS_NO], AssetFields.CHASIS_NO),
            this.buildField(this.customLabel.regNoLabel, this.accountData?.[AssetFields.REG_NO], AssetFields.REG_NO),
            this.buildField(this.customLabel.supplierNameLabel, this.accountData?.[AssetFields.SUPPLIER_NAME], AssetFields.SUPPLIER_NAME),
            // Currency field - just using standard standard formatting for now if it's rendered generically.
            this.buildField(this.customLabel.assetCostLabel, this.accountData?.[AssetFields.ASSET_COST], AssetFields.ASSET_COST),
            this.buildField(this.customLabel.amountPledgedLabel, formatDate(this.accountData?.[AssetFields.AMOUNT_PLEDGED]), AssetFields.AMOUNT_PLEDGED),
            this.buildField(this.customLabel.makeDateLabel, formatDate(this.accountData?.[AssetFields.MAKE_DATE]), AssetFields.MAKE_DATE),
            this.buildField(this.customLabel.boughtDateLabel, formatDate(this.accountData?.[AssetFields.BOUGHT_DATE]), AssetFields.BOUGHT_DATE)
        ];
    }

    buildField(label, value, fieldApiName) {
        return {
            label,
            value: value || STATUS.EMPTY,
            syncStatus: this.error ? STATUS.ERROR : STATUS.NONE,
            helpText: null,
            hasHelpText: false
        };
    }

    /* ================= ERROR + TOAST ================= */
    handleError(err) {
        this.error = err?.body?.message || err?.message || STATUS.UNKNOWN_ERROR;
        this.showToast(STATUS.ERROR_TITLE, this.error, STATUS.ERROR_VARIANT);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}