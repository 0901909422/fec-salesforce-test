import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';

import loadApplicationDetail
    from '@salesforce/apex/FEC_ApplicationsListController.loadApplicationDetail';

import logSensitiveFromMainInfo
    from '@salesforce/apex/FEC_ApplicationsListController.logSensitiveFromMainInfo';

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
                columns: 3,
                fields: this.buildFields(this.salesFields)
            }
        ];
    }

    /* ================= FIELD BUILDER ================= */
    buildFields(configs) {
        if (!this.record) return [];

        return configs.map(cfg => {
            const rawValue = this.record?.[cfg.fieldName];

            let value =
                rawValue === null || rawValue === undefined
                    ? '-'
                    : rawValue;

            if (cfg.fieldName === 'updateDate' && value !== '-' && value !== '') {
                value = this.formatDateDDMMYYYY(value);
            }

            let iconName;

            if (cfg.toggle === true && value && value !== '-') {
                if (cfg.fieldName === 'nationalPassportID') {
                    value = this.showNationalID
                        ? value
                        : this.maskValue(value);
                    iconName = this.showNationalID
                        ? 'utility:preview'
                        : 'utility:hide';
                }

                if (cfg.fieldName === 'registrationPhone') {
                    value = this.showPhone
                        ? value
                        : this.maskValue(value);
                    iconName = this.showPhone
                        ? 'utility:preview'
                        : 'utility:hide';
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
                hasHelpText: !!helpText
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

    /* ================= MASKING ================= */

    maskValue(value) {
        if (!value) return '';

        const v = value.toString().trim();

        // Passport (bắt đầu bằng chữ)
        if (/^[A-Za-z]/.test(v)) {
            return v.length <= 5
                ? v
                : v.substring(0, 2) +
                '*'.repeat(v.length - 5) +
                v.slice(-3);
        }

        // Phone (10 số)
        if (/^\d{10}$/.test(v)) {
            return (
                v.substring(0, 4) +
                '*'.repeat(v.length - 7) +
                v.slice(-3)
            );
        }

        // CCCD / ID number
        if (/^\d+$/.test(v)) {
            return v.length <= 6
                ? v
                : v.substring(0, 3) +
                '*'.repeat(v.length - 6) +
                v.slice(-3);
        }

        return v;
    }

    formatDateDDMMYYYY(value) {
        if (!value) return '-';

        // Expect yyyy-mm-dd
        const parts = value.split('-');
        if (parts.length !== 3) return value;

        const [yyyy, mm, dd] = parts;
        return `${dd}/${mm}/${yyyy}`;
    }
}