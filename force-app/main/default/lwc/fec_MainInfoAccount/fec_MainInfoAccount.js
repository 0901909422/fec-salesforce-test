/****************************************************************************************
 * File Name    : FEC_MainInfoAccount.js
 * Author       : Quangdv7
 * Date         : 2025-01-12
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import loadAccountInfo from '@salesforce/apex/FEC_MainInfoAccountController.loadAccountInfo';
import refreshAccountInfo from '@salesforce/apex/FEC_MainInfoAccountController.refreshAccountInfo';
import checkRewardEligibility from '@salesforce/apex/FEC_MainInfoAccountController.checkRewardEligibility';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { MSG_UNKNOWN_ERROR } from 'c/fec_CommonConst';
import FEC_Account_Label from '@salesforce/label/c.FEC_Account_Label';
import FEC_Account_Status_Label from '@salesforce/label/c.FEC_Account_Status_Label';
import FEC_Card_Label from '@salesforce/label/c.FEC_Card_Label';
import FEC_Card_Status_Label from '@salesforce/label/c.FEC_Card_Status_Label';
import FEC_Debt_Sale_Label from '@salesforce/label/c.FEC_Debt_Sale_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';

export default class FEC_MainInfoAccount extends LightningElement {
    /* ================= INPUT ================= */
    @api recordId;

    /* ================= STATE ================= */
    @track accountData;
    @track error;
    @track isLoading = false;
    @track isProcessing = false;

    refreshStatusMap = {
        Account: 'NONE',
        'Account Status': 'NONE',
        'Card Status': 'NONE',
        'Debt Sale': 'NONE'
    };

    activeSections = ['Account', 'Account Status', 'Card Status', 'Debt Sale','Card'];
    customLabel = {
        accountLabel: FEC_Account_Label,
        accountStatusLabel: FEC_Account_Status_Label,
        cardLabel: FEC_Card_Label,
        cardStatusLabel: FEC_Card_Status_Label,
        debtSaleLabel: FEC_Debt_Sale_Label,
        msgErrorAPI: FEC_MSG_Error_API_Label,
    }

    /* ================= LIFECYCLE ================= */

    connectedCallback() {
        this.loadData();
    }

    /* ================= LOAD LOCAL DATA ================= */

    loadData() {
        if (!this.recordId) return;

        this.isLoading = true;

        loadAccountInfo({ caseId: this.recordId })
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

    /* ================= SECTION REFRESH ================= */

    handleRefresh(event) {
        const section = event.detail?.section;

        if (!section) return;
        this.refreshStatusMap[section] = 'NONE';
        this.isLoading = true;

        if (section === 'Account' || section === 'Account Status' || section === 'Card Status') {
            refreshAccountInfo({ caseId: this.recordId })
                .then(result => {
                    this.accountData = result;
                    this.refreshStatusMap[section] = 'SUCCESS';
                    this.showToast(
                        'Success',
                        `Refresh ${section} successfully`,
                        'success'
                    );
                })
                .catch(err => {
                    this.refreshStatusMap[section] = 'ERROR';
                    this.handleError(err);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else {
            this.refreshStatusMap[section] = 'SUCCESS';
            this.isLoading = false;
        }
    }

    handleButtonClick(event) {
        const buttonName = event.detail?.buttonName;
        
        if (buttonName === 'rewardsEligibility') {
            this.handleRewardEligibility();
        }
    }

    handleRewardEligibility() {
        this.isProcessing = true;
        
        checkRewardEligibility({ caseId: this.recordId })
            .then(result => {
                this.isProcessing = false;
                
                this.accountData = {
                    ...this.accountData,
                    availablePoints: result.availablePoints,
                    remark: result.remark
                };
                
                if (result.isEligible) {
                    this.showToast('Success', result.message, 'success');
                } else {
                    this.showToast('Error', result.message, 'error');
                }
            })
            .catch(error => {
                this.isProcessing = false;
                this.showToast('Error', error.body?.message || 'Error checking eligibility', 'error');
            });
    }

    /* ================= UI HELPERS ================= */

    get hasData() {
        return this.accountData && Object.keys(this.accountData).length > 0;
    }

    get accountFields() {
        const status = this.refreshStatusMap['Account'];

        if (!this.accountData && status !== 'ERROR') return [];

        return [
            this.buildField('Account Number', this.accountData?.accountNumber, status,'FEC_Account_Number__c'),
            this.buildField('Credit Limit', this.accountData?.creditLimit, status,'FEC_Credit_Limit__c'),
            this.buildMoneyField('Current Balance', this.accountData?.currentBalance, status,'FEC_Current_Balance__c'),
            this.buildField('Contract Number', this.accountData?.contractNumber, status,'FEC_Contract_Number__c'),
            this.buildMoneyField('OTB', this.accountData?.otb, status,'FEC_OTB__c'),
            this.buildMoneyField('Total Balance', this.accountData?.totalBalance, status,'FEC_Total_Balance__c'),
            this.buildField('Account Status', this.accountData?.accountStatus, status,'FEC_Account_Status__c'),
            this.buildField('Hold Amount', this.accountData?.holdAmount, status,'FEC_Hold_Amount__c'),
            this.buildField('Application ID', this.accountData?.applicationId, status,'FEC_Application_ID__c'),
            this.buildField('Account Open Date', this.accountData?.accountOpenDate, status,'FEC_Account_Open_Date__c'),
        ];
    }

    get accountStatusFields() {
        const status = this.refreshStatusMap?.['Account Status'];
        if (!this.accountData && status !== 'ERROR') return [];

        return [
            this.buildField('Block Code 1',this.accountData?.blockCode1,status,'FEC_Block_Code_1__c'),
            this.buildField('Block Code 2',this.accountData?.blockCode2,status,'FEC_Block_Code_2__c'),
            this.buildField('Warning Code',this.accountData?.warningCode,status,'FEC_Warning_Code__c'),
            this.buildField('Block Date 1',this.accountData?.blockDate1,status,'FEC_Block_Date_1__c'),
            this.buildField('Block Date 2',this.accountData?.blockDate2,status,'FEC_Block_Date_2__c'),
            this.buildField('Days Past Due',this.accountData?.daysPastDue,status,'FEC_Days_Past_Due__c'),      
            this.buildField('Reason 1',this.accountData?.reason1,status,'FEC_Reason_1__c'),
            this.buildField('Reason 2',this.accountData?.reason2,status,'FEC_Reason_2__c')
        ];
    }

     get cardFields() {
        const status = this.refreshStatusMap['Card'];

        if (!this.accountData && status !== 'ERROR') return [];

        return [
            this.buildField('Card Number', this.accountData?.cardNumber, status,'FEC_Card_Number__c'),
            this.buildField('Expiry Date', this.accountData?.expiryDate, status,'FEC_Expiry_Date__c'),
            this.buildField('Scheme ID', this.accountData?.schemeID, status,'FEC_Scheme_ID__c'),
            this.buildField('Card Type', this.accountData?.cardType, status,'FEC_Card_Type__c'),
            this.buildField('Insurance Flag', this.accountData?.insuranceFlag, status,'FEC_Insurance_Flag__c'),
            this.buildField('Scheme Desc', this.accountData?.schemeDesc, status,'FEC_Scheme_Desc__c'),
            this.buildField('Plastic ID', this.accountData?.plasticID, status,'FEC_Plastic_ID__c'),
            this.buildField('Product Association', this.accountData?.productAssociation, status,'FEC_Product_Association__c'),
            this.buildMoneyField('Customer Segment', this.accountData?.customerSegment, status,'FEC_Customer_Segment__c'),
        ];
    }

    get cardStatusFields() {
        const status = this.refreshStatusMap?.['Card Status'];
        if (!this.accountData && status !== 'ERROR') {
            return [];
        }

        return [
            this.buildField('Block Code',this.accountData?.cardBlockCode,status,'FEC_Block_Code__c'),
            this.buildField('Card Activation Status',this.accountData?.cardActivationStatus,status,'FEC_Card_Activation_Status__c'),
            this.buildField('Local Use',this.formatLocalUse(this.accountData?.localUse),status,'FEC_Local_Use__c'),
            this.buildField('Block Date',this.accountData?.cardBlockDate,status,'FEC_Block_Date__c'),
            this.buildField('Card Activation Date',this.accountData?.cardActivationDate,status,'FEC_Card_Activation_Date__c'),
            this.buildMoneyField('Available Points',this.accountData?.availablePoints,status,'FEC_Available_Points__c'),
            this.buildField('Blocked By',this.accountData?.blockedBy,status,'FEC_Blocked_By__c'),
            this.buildField('E-Commerce Status',this.accountData?.eCommerceStatus,status,'FEC_E_Commerce_Status__c'),
            this.buildField('Remark',this.accountData?.remark,status,'FEC_Remark__c'),
            { type: 'button',
                align: 'right',
                buttons: [
                    { 
                        label: 'Rewards Eligibility', 
                        variant: 'brand',
                        
                        name: 'rewardsEligibility'
                    }
                ]
            },
        ];
    }

    get debtSaleFields() {
        const status = this.refreshStatusMap?.['Debt Sale'];
        if (!this.accountData && status !== 'ERROR') {
            return [];
        }

        return [
            this.buildField('Debt Sale Type',this.accountData?.debtSaleType,status,'FEC_Debt_Sale_Type__c'),
            this.buildField('Sold Date',this.accountData?.debtSoldDate,status,'FEC_Sold_Date__c'),
            this.buildMoneyField('Principal Sold',this.accountData?.principalSold,status,'FEC_Principal_Sold__c'),
            this.buildField('Company Name',this.accountData?.debtSaleCompanyName,status,'FEC_Company_Name__c'),
            this.buildField('Sold Note',this.accountData?.soldNote,status,'FEC_Sold_Note__c'),
            this.buildMoneyField('Interest Sold',this.accountData?.interestSold,status,'FEC_Interest_Sold__c'),
        ];
    }

    buildField(label, value, status, fieldApiName) {
        const helpText =
            fieldApiName
                ? this.accountData?.helpTexts?.[fieldApiName.toLowerCase()]
                : null;

        return {
            label,
            value: value || '-',
            syncStatus: status,
            helpText,
            hasHelpText: !!helpText
        };
    }

    buildMoneyField(label, value, status, fieldApiName) {
        const helpText =
            fieldApiName
                ? this.accountData?.helpTexts?.[fieldApiName.toLowerCase()]
                : null;

        return {
            label,
            value: value || '-',
            type: this.isNegative(value) ? 'negative' : 'regular',
            syncStatus: status,
            helpText,
            hasHelpText: !!helpText
        };
    }

    formatLocalUse(value) {
        if (value === '1' || value === 1) {
            return 'Block';
        }
        if (value === '0' || value === 0) {
            return 'Not block';
        }
        return '-';
    }

    isNegative(value) {
        return value && value.toString().startsWith('-');
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