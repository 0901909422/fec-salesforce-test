/****************************************************************************************
 * File Name    : Fec_BancaTabView.js
 * Author       : Quangdv7
 * Date         : 2025-01-17
 * Description  : Handle Insurance(Banca) Information
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 1.0      2025-01-17                         Create
****************************************************************************************/

import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import {
    formatDateVNI,
    maskValue,
    setConsoleTab
} from 'c/fec_CommonUtils';

import loadInsuranceDetail from '@salesforce/apex/FEC_BancaController.loadInsuranceDetail';

import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Insurance_Info_Error from '@salesforce/label/c.FEC_Insurance_Info_Error';

import FEC_User_ID from '@salesforce/label/c.FEC_User_ID';
import FEC_Buyer_Name from '@salesforce/label/c.FEC_Buyer_Name';
import FEC_Buyer_DOB from '@salesforce/label/c.FEC_Buyer_DOB';
import FEC_Buyer_NID from '@salesforce/label/c.FEC_Buyer_NID';
import FEC_Product_Name from '@salesforce/label/c.FEC_Product_Name';
import FEC_Label_Status from '@salesforce/label/c.FEC_Label_Status';

import FEC_Gender_Label from '@salesforce/label/c.FEC_Gender_Label';
import FEC_Sales_Channel from '@salesforce/label/c.FEC_Sales_Channel';
import FEC_Insurance_Company from '@salesforce/label/c.FEC_Insurance_Company';
import FEC_Sub_Channel from '@salesforce/label/c.FEC_Sub_Channel';

import FEC_Policy_Number from '@salesforce/label/c.FEC_Policy_Number';
import FEC_Agent_Code from '@salesforce/label/c.FEC_Agent_Code';
import FEC_Phone_Number from '@salesforce/label/c.FEC_Phone_Number';
import FEC_Agent_Name from '@salesforce/label/c.FEC_Agent_Name';

import FEC_Expiry_Date from '@salesforce/label/c.FEC_Expiry_Date';
import FEC_Payment_ID from '@salesforce/label/c.FEC_Payment_ID';
import FEC_Cancel_Date from '@salesforce/label/c.FEC_Cancel_Date';
import FEC_Effective_Date from '@salesforce/label/c.FEC_Effective_Date';
import FEC_Premium_Free from '@salesforce/label/c.FEC_Premium_Free';

import { ICON_PREVIEW, ICON_HIDE } from 'c/fec_CommonConst';

export default class Fec_BancaTabView extends LightningElement {

    /* ================= STATE ================= */

    @track record = null;
    @track showNationalID = false;
    @track showPhone = false;

    insuranceId;
    userId;

    isLoading = false;

    /* ================= LABEL ================= */

    customLabel = {
        msgErrorApiLabel: FEC_MSG_Error_API_Label,
        insuranceInfoLabel: FEC_Insurance_Info_Error,

        userIdLabel: FEC_User_ID,
        buyerNameLabel: FEC_Buyer_Name,
        buyerDOBLabel: FEC_Buyer_DOB,
        buyerNIDLabel: FEC_Buyer_NID,
        productNameLabel: FEC_Product_Name,
        statusLabel: FEC_Label_Status,

        genderLabel: FEC_Gender_Label,
        salesChannelLabel: FEC_Sales_Channel,
        insuranceCompanyLabel: FEC_Insurance_Company,
        subChannelLabel: FEC_Sub_Channel,

        policyNumberLabel: FEC_Policy_Number,
        agentCodeLabel: FEC_Agent_Code,
        phoneNumberLabel: FEC_Phone_Number,
        agentNameLabel: FEC_Agent_Name,

        expiryDateLabel: FEC_Expiry_Date,
        paymentIdLabel: FEC_Payment_ID,
        cancelDateLabel: FEC_Cancel_Date,
        effectiveDateLabel: FEC_Effective_Date,
        premiumFree: FEC_Premium_Free
    };

    /* ================= FIELD CONFIG ================= */

    insuranceFields = [

        {
            label: this.customLabel.userIdLabel,
            fieldName: 'userId',
            fieldApiName: 'FEC_User_ID__c'
        },

         {
            label: this.customLabel.buyerDOBLabel,
            fieldName: 'dateofBirth',
            fieldApiName: 'FEC_Buyer_DOB__c',
            isDate: true
        },

        {
            label: this.customLabel.productNameLabel,
            fieldName: 'productName',
            fieldApiName: 'FEC_Product_Name__c'
        },

        {
            label: this.customLabel.statusLabel,
            fieldName: 'status',
            fieldApiName: 'FEC_Status__c'
        },

        {
            label: this.customLabel.buyerNameLabel,
            fieldName: 'buyerName',
            fieldApiName: 'FEC_Buyer_Name__c'
        },
       
        {
            label: this.customLabel.buyerNIDLabel,
            fieldName: 'buyerNID',
            fieldApiName: 'FEC_Buyer_NID__c',
            toggle: true
        },

        {
            label: this.customLabel.premiumFree,
            fieldName: 'premiumFree',
            fieldApiName: 'FEC_Premium_Fee__c',
        },

        {
            label: this.customLabel.agentNameLabel,
            fieldName: 'agentName',
            fieldApiName: 'FEC_Agent_Name__c'
        },

        {
            label: this.customLabel.genderLabel,
            fieldName: 'gender',
            fieldApiName: 'FEC_Buyer_Gender__c'
        },

        {
            label: this.customLabel.phoneNumberLabel,
            fieldName: 'phoneNumber',
            fieldApiName: 'FEC_Phone_Number__c',
            toggle: true
        },

        {
            label: this.customLabel.salesChannelLabel,
            fieldName: 'salesChannel',
            fieldApiName: 'FEC_Sale_Channel__c'
        },

        {
            label: this.customLabel.paymentIdLabel,
            fieldName: 'paymentID',
            fieldApiName: 'FEC_Payment_ID__c'
        },

        {
            label: this.customLabel.insuranceCompanyLabel,
            fieldName: 'insuranceCompany',
            fieldApiName: 'FEC_Insurer_Company__c'
        },

        {
            label: this.customLabel.expiryDateLabel,
            fieldName: 'expiryDate',
            fieldApiName: 'FEC_Expiry_Date__c',
            isDate: true
        },

        {
            label: this.customLabel.subChannelLabel,
            fieldName: 'subChannel',
            fieldApiName: 'FEC_Sub_Channel__c'
        },

        {
            label: this.customLabel.effectiveDateLabel,
            fieldName: 'effectiveDate',
            fieldApiName: 'FEC_Effective_Date__c',
            isDate: true
        },

        {
            label: this.customLabel.policyNumberLabel,
            fieldName: 'policyNumber',
            fieldApiName: 'FEC_Policy_Number__c'
        },

        {
            label: this.customLabel.cancelDateLabel,
            fieldName: 'cancelDate',
            fieldApiName: 'FEC_Cancel_Date__c',
            isDate: true
        },

        {
            label: this.customLabel.agentCodeLabel,
            fieldName: 'agentCode',
            fieldApiName: 'FEC_Agent_Code__c'
        },
    ];

    /* ================= NAV ================= */

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {

        const insuranceId = pageRef?.state?.c__insuranceId;
        const userId = pageRef?.state?.c__userId;

        if (insuranceId) {

            this.insuranceId = insuranceId;
            this.userId = userId;

            this.loadDetail();
        }
    }

    /* ================= LOAD DATA ================= */

    loadDetail() {

        if (!this.insuranceId) {
            return;
        }

        this.isLoading = true;

        loadInsuranceDetail({
            insuranceId: this.insuranceId
        })
            .then(res => {

                this.record = res;

                setConsoleTab(
                    `Insurance ${this.userId}`,
                    'standard:orders'
                );
            })
            .catch(err => {

                console.error(
                    'Load insurance detail failed',
                    err
                );
            })
            .finally(() => {

                this.isLoading = false;
            });
    }

    /* ================= SECTION ================= */

    get sections() {

        if (!this.record) {
            return null;
        }

        return [
            {
                name: 'detail',
                label: 'Details',
                fields: this.buildFields(this.insuranceFields)
            }
        ];
    }

    /* ================= FIELD BUILDER ================= */

    buildFields(configs) {

        if (!this.record) {
            return [];
        }

        return configs.map(cfg => {

            let value = this.record?.[cfg.fieldName];

            if (value === null || value === undefined || value === '') {
                value = '-';
            }

            if (cfg.isDate && value !== '-') {
                value = formatDateVNI(value);
            }

            let iconName;

            if (cfg.toggle === true && value !== '-') {

                if (cfg.fieldName === 'buyerNID') {

                    value = this.showNationalID
                        ? value
                        : maskValue(value);

                    iconName = this.showNationalID
                        ? ICON_PREVIEW
                        : ICON_HIDE;
                }

                if (cfg.fieldName === 'phoneNumber') {

                    value = this.showPhone
                        ? value
                        : maskValue(value);

                    iconName = this.showPhone
                        ? ICON_PREVIEW
                        : ICON_HIDE;
                }
            }

            return {
                label: cfg.label,
                value,
                fieldName: cfg.fieldName,
                toggle: cfg.toggle === true,
                iconName
            };
        });
    }

    /* ================= TOGGLE ================= */

    handleToggle(event) {

        const fieldName = event.detail.fieldName;

        if (fieldName === 'buyerNID') {
            this.showNationalID = !this.showNationalID;
        }

        if (fieldName === 'phoneNumber') {
            this.showPhone = !this.showPhone;
        }
    }
}