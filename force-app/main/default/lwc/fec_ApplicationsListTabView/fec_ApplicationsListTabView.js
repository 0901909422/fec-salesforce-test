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
export default class Fec_ApplicationsListTabView extends LightningElement {

    /* ================= STATE ================= */

    @track record = null;
    @track showNationalID = false;
    @track showPhone = false;

    applicationListId;
    isLoading = false;

    /* ================= FIELD CONFIG ================= */

    applicationFields = [
        { label: 'Application ID', fieldName: 'applicationId', fieldApiName: 'FEC_Application_ID__c' },
        { label: 'Last Status', fieldName: 'lastStatus', fieldApiName: 'FEC_Last_Status__c' },
        { label: 'National / Passport ID', fieldName: 'nationalPassportID', fieldApiName: 'FEC_National_Passport_ID__c', toggle: true },
        { label: 'Current Address', fieldName: 'currentAddress', fieldApiName: 'FEC_Current_Address__c' },
        { label: 'Account Number', fieldName: 'accountNumber', fieldApiName: 'FEC_Account_Number__c' },
        { label: 'Updated Date', fieldName: 'updateDate', fieldApiName: 'FEC_Updated_Date__c' },
        { label: 'Registration Phone', fieldName: 'registrationPhone', fieldApiName: 'FEC_Registration_Phone__c', toggle: true },
        { label: 'Permanent Address', fieldName: 'permanentAddress', fieldApiName: 'FEC_Permanent_Address__c' },
        { label: 'Contract Number', fieldName: 'contractNumber', fieldApiName: 'FEC_Contract_Number__c' },
        { label: 'Product Group', fieldName: 'productGroup', fieldApiName: 'FEC_Product_Group__c' },
        { label: 'Registration Email', fieldName: 'registrationEmail', fieldApiName: 'FEC_Registration_Email__c' },
        { label: 'Office Address', fieldName: 'officeAddress', fieldApiName: 'FEC_Office_Address__c' }
    ];

    salesFields = [
        { label: 'CC Code', fieldName: 'ccCode', fieldApiName: 'FEC_CC_Code__c' },
        { label: 'DSA Code', fieldName: 'dSACode', fieldApiName: 'FEC_DSA_Code__c' },
        { label: 'TSA Code', fieldName: 'tSACode', fieldApiName: 'FEC_TSA_Code__c'}, 
        { isSpacer: true },
        { label: 'CC Name', fieldName: 'ccName', fieldApiName: 'FEC_CC_Name__c' },
        { label: 'DSA Name', fieldName: 'dSAName', fieldApiName: 'FEC_DSA_Name__c' },
        { label: 'TSA Name', fieldName: 'tSAName', fieldApiName: 'FEC_TSA_Name__c' }
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
                    iconName = this.showNationalID ? 'utility:preview' : 'utility:hide';
                }

                if (cfg.fieldName === 'registrationPhone') {
                    value = this.showPhone ? value : maskValue(value);
                    iconName = this.showPhone ? 'utility:preview' : 'utility:hide';
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