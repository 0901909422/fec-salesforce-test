/****************************************************************************************
 * File Name    : Fec_SecondaryInfoAccount.js
 * Author       : Quangdv7
 * Date         : 2025-01-14
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import loadSecondaryAccount from '@salesforce/apex/FEC_SecondaryInfoAccountController.loadSecondaryAccount';
import refreshSecondaryAccount from '@salesforce/apex/FEC_SecondaryInfoAccountController.refreshSecondaryAccount';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { MSG_UNKNOWN_ERROR } from 'c/fec_CommonConst';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Limit_Label from '@salesforce/label/c.FEC_Limit_Label';
import FEC_Main_Card_Label from '@salesforce/label/c.FEC_Main_Card_Label';
import FEC_Collections_Info_Label from '@salesforce/label/c.FEC_Collections_Info_Label';
import FEC_Sales_Info_Label from '@salesforce/label/c.FEC_Sales_Info_Label';
import FEC_Success_Title from '@salesforce/label/c.FEC_Success_Title';
import FEC_Error_Title from '@salesforce/label/c.FEC_Error_Title';
import FEC_MSG_Section_Refresh_Success from '@salesforce/label/c.FEC_MSG_Section_Refresh_Success';
import FEC_MSG_Section_Refresh_Fail from '@salesforce/label/c.FEC_MSG_Section_Refresh_Fail';
import FEC_CC_Code_Label from '@salesforce/label/c.FEC_CC_Code_Label';
import FEC_DSA_Code_Label from '@salesforce/label/c.FEC_DSA_Code_Label';
import FEC_TSA_Code_Label from '@salesforce/label/c.FEC_TSA_Code_Label';
import FEC_CC_Name_Label from '@salesforce/label/c.FEC_CC_Name_Label';
import FEC_DSA_Name_Label from '@salesforce/label/c.FEC_DSA_Name_Label';
import FEC_TSA_Name_Label from '@salesforce/label/c.FEC_TSA_Name_Label';
import FEC_Daily_Retail_Limit from '@salesforce/label/c.FEC_Daily_Retail_Limit';
import FEC_Daily_Cash_Limit from '@salesforce/label/c.FEC_Daily_Cash_Limit';
import FEC_Last_Credit_Limit from '@salesforce/label/c.FEC_Last_Credit_Limit';
import FEC_Daily_Retail_Number from '@salesforce/label/c.FEC_Daily_Retail_Number';
import FEC_Daily_Cash_Number from '@salesforce/label/c.FEC_Daily_Cash_Number';
import FEC_Last_Credit_Limit_Date from '@salesforce/label/c.FEC_Last_Credit_Limit_Date';
import FEC_Embossing_Name from '@salesforce/label/c.FEC_Embossing_Name';
import FEC_Statement_Notification_Type from '@salesforce/label/c.FEC_Statement_Notification_Type';
import FEC_Responsible_Unit from '@salesforce/label/c.FEC_Responsible_Unit';
import FEC_Date_Assigned from '@salesforce/label/c.FEC_Date_Assigned';
import FEC_Responsible_Person from '@salesforce/label/c.FEC_Responsible_Person';
import FEC_Delinquency_Date from '@salesforce/label/c.FEC_Delinquency_Date';

export default class Fec_SecondaryInfoAccount extends LightningElement {

    /* ================= INPUT ================= */
    @api recordId;

    /* ================= STATE ================= */
    @track limitFields = [];
    @track mainCardFields = [];
    @track collectionsInfoFields = [];
    @track salesInfoFields = [];
    @track dto;

    isLoading = false;
    error;

    activeSections = [
        'Limit',
        'Main Card'
    ];

    refreshStatusMap = {
        'Limit': 'NONE',
        'Collections Info': 'NONE',
        'Sales Info': 'NONE'
    };

    customLabel = {
        msgErrorAPI: FEC_MSG_Error_API_Label,
        limitLabel: FEC_Limit_Label,
        mainCardLabel: FEC_Main_Card_Label,
        collectionsInfoLabel: FEC_Collections_Info_Label,
        salesInfoLabel: FEC_Sales_Info_Label,
        successTitle: FEC_Success_Title,
        errorTitle: FEC_Error_Title,
        msgSectionRefreshSuccess: FEC_MSG_Section_Refresh_Success,
        msgSectionRefreshFail: FEC_MSG_Section_Refresh_Fail,
        ccCodeLabel: FEC_CC_Code_Label,
        dsaCodeLabel: FEC_DSA_Code_Label,
        tsaCodeLabel: FEC_TSA_Code_Label,
        ccNameLabel: FEC_CC_Name_Label,
        dsaNameLabel: FEC_DSA_Name_Label,
        tsaNameLabel: FEC_TSA_Name_Label,
        dailyRetailLimitLabel: FEC_Daily_Retail_Limit,
        dailyCashLimitLabel: FEC_Daily_Cash_Limit,
        lastCreditLimitLabel: FEC_Last_Credit_Limit,
        dailyRetailNumberLabel: FEC_Daily_Retail_Number,
        dailyCashNumberLabel: FEC_Daily_Cash_Number,
        lastCreditLimitDateLabel: FEC_Last_Credit_Limit_Date,
        embossingNameLabel: FEC_Embossing_Name,
        statementNotificationTypeLabel: FEC_Statement_Notification_Type,
        responsibleUnitLabel: FEC_Responsible_Unit,
        dateAssignedLabel: FEC_Date_Assigned,
        responsiblePersonLabel: FEC_Responsible_Person,
        delinquencyDateLabel: FEC_Delinquency_Date,
    }

    /* ================= LIFECYCLE ================= */

    connectedCallback() {
        if (this.recordId) {
            this.loadData();
        }
    }

    /* ================= LOAD ================= */

    loadData() {
        this.isLoading = true;

        loadSecondaryAccount({ caseId: this.recordId })
            .then(dto => {
                this.dto = dto;
                this.mapLimitSection(dto, 'NONE');
                this.mapMainCardSection(dto, 'NONE');
                this.mapCollectionsInfoSection(dto, 'NONE');
                this.mapSalesInfoSection(dto, 'NONE');
                this.error = undefined;
            })
            .catch(err => {
                console.error('SecondaryInfo load error', err)
            })
            .catch(err => {
                console.error('SecondaryInfo load error', err);
                this.error = err;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    get hasData() {
        return this.dto && Object.keys(this.dto).length > 0;
    }

    /* ================= REFRESH ================= */

    setRefreshStatus(section, status) {
        this.refreshStatusMap = {
            ...this.refreshStatusMap,
            [section]: status
        };
    }

    handleRefresh(event) {
        event.stopPropagation();

        const section = event.detail?.section;
        if (!section || !this.recordId) return;

        this.setRefreshStatus(section, 'NONE');
        this.isLoading = true;

        refreshSecondaryAccount({ caseId: this.recordId })
            .then(dto => {

                if (section === 'Collections Info') {
                    this.mapCollectionsInfoSection(dto, 'SUCCESS');
                }

                this.setRefreshStatus(section, 'SUCCESS');
                this.showToast(
                    this.customLabel.successTitle,
                    this.customLabel.msgSectionRefreshSuccess.replace('{0}', section),
                    'success'
                );
            })
            .catch(err => {
                console.error('Refresh SecondaryInfo error', err);
                this.setRefreshStatus(section, 'ERROR');
                this.showToast(
                    this.customLabel.errorTitle,
                    this.customLabel.msgSectionRefreshFail.replace('{0}', section),
                    'error'
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ================= MAP UI ================= */

    mapLimitSection(dto, status) {
        this.limitFields = [
            this.buildField(this.customLabel.dailyRetailLimitLabel, dto.dailyRetailLimit, status, 'FEC_Daily_Retail_Limit__c'),
            this.buildField(this.customLabel.dailyCashLimitLabel, dto.dailyCashLimit, status, 'FEC_Daily_Cash_Limit__c'),
            this.buildField(this.customLabel.lastCreditLimitLabel, dto.lastCreditLimit, status, 'FEC_Last_Credit_Limit__c'),
            this.buildField(this.customLabel.dailyRetailNumberLabel, dto.dailyRetailNumber, status, 'FEC_Daily_Retail_Number__c'),
            this.buildField(this.customLabel.dailyCashNumberLabel, dto.dailyCashNumber, status, 'FEC_Daily_Cash_Number__c'),
            this.buildField(this.customLabel.lastCreditLimitDateLabel, dto.lastCreditLimitDate, status, 'FEC_Last_Credit_Limit_Date__c')
        ];
    }

    mapMainCardSection(dto, status = 'NONE') {
        this.mainCardFields = [
            this.buildField(this.customLabel.embossingNameLabel, dto.embossingName, status, 'FEC_Embossing_Name__c'),
            this.buildField(this.customLabel.statementNotificationTypeLabel, dto.statementNotificationType, status, 'FEC_Statement_Notification_Type__c')
        ];
    }

    mapCollectionsInfoSection(dto, status) {
        this.collectionsInfoFields = [
            this.buildField(this.customLabel.responsibleUnitLabel, dto.responsibleUnit, status, 'FEC_Responsible_Unit__c'),
            this.buildField(this.customLabel.dateAssignedLabel, dto.dateAssigned, status, 'FEC_Date_Assigned__c'),
            this.buildField(this.customLabel.responsiblePersonLabel, dto.responsiblePerson, status, 'FEC_Responsible_Person__c'),
            this.buildField(this.customLabel.delinquencyDateLabel, dto.delinquencyDate, status, 'FEC_Delinquency_Date__c')
        ];
    }
    mapSalesInfoSection(dto, status) {
        this.salesInfoFields = [
            this.buildField(this.customLabel.ccCodeLabel, dto.ccCode, status,'FEC_CC_Code__c'),
            this.buildField(this.customLabel.dsaCodeLabel, dto.dsaCode, status,'FEC_DSA_Code__c'),
            this.buildField(this.customLabel.tsaCodeLabel, dto.tsaCode, status,'FEC_TSA_Code__c'),
            this.buildField(this.customLabel.ccNameLabel, dto.ccName, status,'FEC_CC_Name__c'),
            this.buildField(this.customLabel.dsaNameLabel, dto.dsaName, status,'FEC_DSA_Name__c'),
            this.buildField(this.customLabel.tsaNameLabel, dto.tsaName, status,'FEC_TSA_Name__c')
        ];
    }
    /* ================= FIELD BUILDER ================= */

    buildField(label, value, status,fieldApiName) {
       const helpText =
        fieldApiName
            ? this.dto?.helpTexts?.[fieldApiName]
            : null;
           
        return {
            label,
            value: value || '-',
            syncStatus: status,
            helpText,
            hasHelpText: !!helpText
        };
    }

    /* ================= ERROR + TOAST ================= */

    handleError(err) {
        this.error = err?.body?.message || err?.message || MSG_UNKNOWN_ERROR;
        this.showToast('Error', this.error, 'error');
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