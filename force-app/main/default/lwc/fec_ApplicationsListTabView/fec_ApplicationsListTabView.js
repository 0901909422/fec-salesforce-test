/****************************************************************************************
 * File Name    : Fec_ApplicationsListTabView.js
 * Author       : Quangdv7
 * Date         : 2025-02-13
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-02-13    Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { formatDateVNI, maskValue,setConsoleTab } from 'c/fec_CommonUtils';

import loadApplicationDetail from '@salesforce/apex/FEC_ApplicationsListController.loadApplicationDetail';
import logSensitiveFromMainInfo from '@salesforce/apex/FEC_ApplicationsListController.logSensitiveFromMainInfo';

import FEC_CC_Code_Label from '@salesforce/label/c.FEC_CC_Code_Label';
import FEC_DSA_Code_Label from '@salesforce/label/c.FEC_DSA_Code_Label';
import FEC_TSA_Code_Label from '@salesforce/label/c.FEC_TSA_Code_Label';
import FEC_CC_Name_Label from '@salesforce/label/c.FEC_CC_Name_Label';
import FEC_DSA_Name_Label from '@salesforce/label/c.FEC_DSA_Name_Label';
import FEC_TSA_Name_Label from '@salesforce/label/c.FEC_TSA_Name_Label';
import LBL_ApplicationID from '@salesforce/label/c.LBL_ApplicationID';
import LBL_AccountNumber from '@salesforce/label/c.LBL_AccountNumber';
import LBL_ContractNumber from '@salesforce/label/c.LBL_ContractNumber';
import FEC_Last_Status from '@salesforce/label/c.FEC_Last_Status';
import FEC_National_Passport_ID from '@salesforce/label/c.FEC_National_Passport_ID';
import FEC_Current_Address from '@salesforce/label/c.FEC_Current_Address';
import FEC_Updated_Date from '@salesforce/label/c.FEC_Updated_Date';
import FEC_Registration_Phone from '@salesforce/label/c.FEC_Registration_Phone';
import FEC_Permanent_Address from '@salesforce/label/c.FEC_Permanent_Address';
import FEC_Product_Group from '@salesforce/label/c.FEC_Product_Group';
import FEC_Registration_Email from '@salesforce/label/c.FEC_Registration_Email';
import FEC_Office_Address from '@salesforce/label/c.FEC_Office_Address';

import { ICON_PREVIEW, ICON_HIDE } from "c/fec_CommonConst";

export default class Fec_ApplicationsListTabView extends LightningElement {

    /* ================= STATE ================= */

    @track record = null;
    @track showNationalID = false;
    @track showPhone = false;

    applicationListId;
    isLoading = false;

    customLabel = {
        ccCodeLabel: FEC_CC_Code_Label,
        dsaCodeLabel: FEC_DSA_Code_Label,
        tsaCodeLabel: FEC_TSA_Code_Label,
        ccNameLabel: FEC_CC_Name_Label,
        dsaNameLabel: FEC_DSA_Name_Label,
        tsaNameLabel: FEC_TSA_Name_Label,
        applicationIdLabel: LBL_ApplicationID,
        lastStatusLabel: FEC_Last_Status,
        nationalPassportIdLabel: FEC_National_Passport_ID,
        currentAddressLabel: FEC_Current_Address,
        accountNumberLabel: LBL_AccountNumber,
        updatedDateLabel: FEC_Updated_Date,
        registrationPhoneLabel: FEC_Registration_Phone,
        permanentAddressLabel: FEC_Permanent_Address,
        contractNumberLabel: LBL_ContractNumber,
        productGroupLabel: FEC_Product_Group,
        registrationEmailLabel: FEC_Registration_Email,
        officeAddressLabel: FEC_Office_Address
    }

    /* ================= FIELD CONFIG ================= */

    applicationFields = [
        { label: this.customLabel.applicationIdLabel, fieldName: 'applicationId', fieldApiName: 'FEC_Application_ID__c' },
        { label: this.customLabel.lastStatusLabel, fieldName: 'lastStatus', fieldApiName: 'FEC_Last_Status__c' },
        { label: this.customLabel.nationalPassportIdLabel, fieldName: 'nationalPassportID', fieldApiName: 'FEC_National_Passport_ID__c', toggle: true },
        { label: this.customLabel.currentAddressLabel, fieldName: 'currentAddress', fieldApiName: 'FEC_Current_Address__c' },
        { label: this.customLabel.accountNumberLabel, fieldName: 'accountNumber', fieldApiName: 'FEC_Account_Number__c' },
        { label: this.customLabel.updatedDateLabel, fieldName: 'updateDate', fieldApiName: 'FEC_Updated_Date__c' },
        { label: this.customLabel.registrationPhoneLabel, fieldName: 'registrationPhone', fieldApiName: 'FEC_Registration_Phone__c', toggle: true },
        { label: this.customLabel.permanentAddressLabel, fieldName: 'permanentAddress', fieldApiName: 'FEC_Permanent_Address__c' },
        { label: this.customLabel.contractNumberLabel, fieldName: 'contractNumber', fieldApiName: 'FEC_Contract_Number__c' },
        { label: this.customLabel.productGroupLabel, fieldName: 'productGroup', fieldApiName: 'FEC_Product_Group__c' },
        { label: this.customLabel.registrationEmailLabel, fieldName: 'registrationEmail', fieldApiName: 'FEC_Registration_Email__c' },
        { label: this.customLabel.officeAddressLabel, fieldName: 'officeAddress', fieldApiName: 'FEC_Office_Address__c' }
    ];

    salesFields = [
        { label: this.customLabel.ccCodeLabel, fieldName: 'ccCode', fieldApiName: 'FEC_CC_Code__c' },
        { label: this.customLabel.dsaCodeLabel, fieldName: 'dSACode', fieldApiName: 'FEC_DSA_Code__c' },
        { label: this.customLabel.tsaCodeLabel, fieldName: 'tSACode', fieldApiName: 'FEC_TSA_Code__c'}, 
        { isSpacer: true },
        { label: this.customLabel.ccNameLabel, fieldName: 'ccName', fieldApiName: 'FEC_CC_Name__c' },
        { label: this.customLabel.dsaNameLabel, fieldName: 'dSAName', fieldApiName: 'FEC_DSA_Name__c' },
        { label: this.customLabel.tsaNameLabel, fieldName: 'tSAName', fieldApiName: 'FEC_TSA_Name__c' }
    ];

    /* ================= NAV ================= */

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        const listId = pageRef?.state?.c__ApplicationList;
        if (listId && listId !== this.applicationListId) {
            this.applicationListId = listId;
            this.loadDetail();
        }
    }

    /* ================= LOAD DATA ================= */

    loadDetail() {
        if (!this.applicationListId) return;

        this.isLoading = true;
        this.record = null;
        this.showNationalID = false;
        this.showPhone = false;

        loadApplicationDetail({ applicationListId: this.applicationListId })
            .then(res => {
                this.record = res;
                setConsoleTab(
                    'ApplicationsList Detail',
                    'standard:record'
                );
            })
            .catch(err => {
                console.error('Load application detail failed', err);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ================= SECTIONS ================= */

    get sections() {
        if (!this.record) return null;

        return [
            {
                name: 'registration',
                label: 'Registration Info',
                fields: this.buildFields(this.applicationFields)
            },
            {
                name: 'sales',
                label: 'Sales',
                fields: this.buildFields(this.salesFields)
            }
        ];
    }

    /* ================= FIELD BUILDER ================= */
    buildFields(configs) {
        if (!this.record) return [];

        return configs.map((cfg, index) => {

            if (cfg.isSpacer) {
                return {
                    fieldName: `empty-${index}`,
                    isEmpty: true
                };
            }

            const rawValue = this.record?.[cfg.fieldName];

            let value;

            if (rawValue === '') {
                value = '';
            } else if (rawValue === null || rawValue === undefined) {
                value = '-';
            } else {
                value = rawValue;
            }

            if (cfg.fieldName === 'updateDate' && value !== '-' && value !== '') {
                value = formatDateVNI(value);
            }

            let iconName;

            if (cfg.toggle === true && value && value !== '-') {

                if (cfg.fieldName === 'nationalPassportID') {
                    value = this.showNationalID ? value : maskValue(value);
                    iconName = this.showNationalID ? ICON_PREVIEW : ICON_HIDE;
                }

                if (cfg.fieldName === 'registrationPhone') {
                    value = this.showPhone ? value : maskValue(value);
                    iconName = this.showPhone ? ICON_PREVIEW : ICON_HIDE;
                }
            }

            const apiName = cfg.fieldApiName;
            const helpText = apiName
                ? this.record?.helpTexts?.[apiName]
                : null;

            return {
                label: cfg.label,
                value,
                fieldName: cfg.fieldName,
                toggle: cfg.toggle === true,
                iconName,
                helpText,
                hasHelpText: !!helpText,
                isEmpty: false
            };
        });
    }

    /* ================= TOGGLE HANDLER ================= */

    handleToggle(event) {
        const { fieldName, sectionName } = event.detail;

        // ===== NATIONAL ID =====
        if (fieldName === 'nationalPassportID') {
            this.showNationalID = !this.showNationalID;
            if (this.showNationalID) {
                this.logSensitive(sectionName, 'National / Passport ID');
            }
            return;
        }

        // ===== PHONE =====
        if (fieldName === 'registrationPhone') {
            this.showPhone = !this.showPhone;
            if (this.showPhone) {
                this.logSensitive(sectionName, 'Registration Phone');
            }
        }
    }
    
    /* ================= LOG SENSITIVE ================= */

    logSensitive(section, fieldLabel) {
        logSensitiveFromMainInfo({
            section,
            fieldLabel,
            relatedCaseId: this.record?.caseId
        }).catch(err => {
            console.error('Log sensitive access failed', err);
        });
    }
}