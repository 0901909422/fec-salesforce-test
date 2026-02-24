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
        { label: 'Application ID', fieldName: 'applicationId', fieldApiName: 'fec_application_id__c' },
        { label: 'Last Status', fieldName: 'lastStatus', fieldApiName: 'fec_last_status__c' },
        { label: 'National / Passport ID', fieldName: 'nationalPassportID', fieldApiName: 'fec_national_passport_id__c', toggle: true },
        { label: 'Current Address', fieldName: 'currentAddress', fieldApiName: 'fec_current_address__c' },
        { label: 'Account Number', fieldName: 'accountNumber', fieldApiName: 'fec_account_number__c' },
        { label: 'Updated Date', fieldName: 'updateDate', fieldApiName: 'fec_updated_date__c' },
        { label: 'Registration Phone', fieldName: 'registrationPhone', fieldApiName: 'fec_registration_phone__c', toggle: true },
        { label: 'Permanent Address', fieldName: 'permanentAddress', fieldApiName: 'fec_permanent_address__c' },
        { label: 'Contract Number', fieldName: 'contractNumber', fieldApiName: 'fec_contract_number__c' },
        { label: 'Product Group', fieldName: 'productGroup', fieldApiName: 'fec_product_group__c' },
        { label: 'Registration Email', fieldName: 'registrationEmail', fieldApiName: 'fec_registration_email__c' },
        { label: 'Office Address', fieldName: 'officeAddress', fieldApiName: 'fec_office_address__c' }
    ];

    salesFields = [
        { label: 'CC Code', fieldName: 'ccCode', fieldApiName: 'fec_cc_code__c' },
        { label: 'DSA Code', fieldName: 'dSACode', fieldApiName: 'fec_dsa_code__c' },
        { label: 'TSA Code', fieldName: 'tSACode', fieldApiName: 'fec_tsa_code__c'}, 
        { isSpacer: true },
        { label: 'CC Name', fieldName: 'ccName', fieldApiName: 'fec_cc_name__c' },
        { label: 'DSA Name', fieldName: 'dSAName', fieldApiName: 'fec_dsa_name__c' },
        { label: 'TSA Name', fieldName: 'tSAName', fieldApiName: 'fec_tsa_name__c' }
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
            })
            .catch(err => {
                console.error('Load application detail failed', err);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ================= SET TABNAME ================= */
    connectedCallback() {
        setConsoleTab('ApplicationsList Detail', 'standard:record');
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

            const apiName = cfg.fieldApiName?.toLowerCase();
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