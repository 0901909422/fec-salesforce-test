/****************************************************************************************
 * File Name    : Fec_MainInfo.js
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import loadMainInfo from '@salesforce/apex/FEC_MainInfoController.loadMainInfo';
import logSensitiveFromMainInfo from '@salesforce/apex/FEC_MainInfoController.logSensitiveFromMainInfo';
import { loadStyle } from 'lightning/platformResourceLoader';

import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';

export default class Fec_MainInfo extends LightningElement {

    /* ================= INPUT ================= */
    @api recordId;

    /* ================= STATE ================= */
    @track data;
    @track error;
    @track isLoading = true;

    @track primaryPhone = false;
    @track nationalIDPassportID = false;
    @track activeSections = ['demographic', 'customerNumber', 'addresses'];

    addressColumns = [
        { label: 'Address Type', fieldName: 'addressType' },
        { label: 'Address', fieldName: 'address' },
        { label: 'Mailing Address', fieldName: 'mailingAddress' }
    ];

    /* ================= LIFECYCLE ================= */

    connectedCallback() {

        loadStyle(this, COMMON_STYLES)
            .then(() => {
                console.log("Common styles loaded successfully");
            })
            .catch((error) => {
                console.error("Error loading common styles", error);
            });
        this.fetchData();
    }

    /* ================= DATA ================= */

    fetchData() {
        this.isLoading = true;

        loadMainInfo({ caseId: this.recordId })
            .then(res => {
                this.data = res;
                this.error = undefined;
            })
            .catch(err => {
                this.error = err?.body?.message || err;
                this.data = undefined;
            })
            .finally(() => {
                this.isLoading = false;
            });
    }



    /* ================= GETTERS ================= */

    get hasData() {
        return this.data && Object.keys(this.data).length > 0;
    }

    get fullName() { return this.data?.fullName || ''; }
    get lastName() { return this.data?.lastName || ''; }
    get middleName() { return this.data?.middleName || ''; }
    get firstName() { return this.data?.firstName || ''; }
    get gender() { return this.data?.gender || ''; }
    get maritalStatus() { return this.data?.maritalStatus || ''; }
    get cifNumber() { return this.data?.cifNumber || ''; }
    get nationalIDPassportID() { return this.data?.nationalIDPassportID || ''; }
    get dateOfIssue() { return this.data?.dateOfIssue || ''; }
    get placeOfIssue() { return this.data?.placeOfIssue || ''; }

    get dateOfBirth() {
        return this.formatDate(this.data?.birthDate);
    }

    /* ================= HELP TEXT ================= */
    get helpTextMap() {
        return this.data?.helpTexts || {};
    }

    /**
     * Generic help text getter
     * @param {String} fieldApiName ex: FEC_First_Name__c
     */
    getHelpText(fieldApiName) {
        return fieldApiName
            ? this.helpTextMap[fieldApiName.toLowerCase()]
            : null;
    }
    
    getMaskingConfig(key) {
        const configs = {
            phone: {
                state: 'primaryPhone',
                section: 'Demographic',
                objectApi: 'Case',
                fieldLabel: 'Primary Phone',
                fieldApi: 'fec_primary_phone__c'
            },
            nationalId: {
                state: 'nationalIDPassportID',
                section: 'Demographic',
                objectApi: 'Case',
                fieldLabel: 'National ID / Passport ID',
                fieldApi: 'fec_national_id__passport_id__c'
            }
        };

        return configs[key];
    }
    toggleMasking(key) {
        const config = this.getMaskingConfig(key);
        if (!config) return;

        const stateName = config.state;

        if (!this[stateName]) {
            logSensitiveFromMainInfo({
                section: config.section,
                fieldLabel: config.fieldLabel,
                relatedCaseId: this.recordId
            }).catch(e => {
                console.error('Sensitive log failed', e);
            });
        }

        this[stateName] = !this[stateName];
    }

    maskValue(value, showFull) {
        if (!value) return '';
        if (showFull) return value;

        const v = value.trim();

        /* =====================
        * PASSPORT ID (bắt đầu bằng chữ)
        * Hiển thị: 2 ký tự đầu + 3 ký tự cuối
        * ===================== */
        if (/^[A-Za-z]/.test(v)) {
            if (v.length <= 5) return v;
            return (
                v.substring(0, 2) +
                '*'.repeat(v.length - 5) +
                v.slice(-3)
            );
        }

        /* =====================
        * PHONE NUMBER: 84xxxxxxxxx
        * Hiển thị: 5 số đầu + 3 số cuối
        * Ví dụ: 84901***678
        * ===================== */
        if (/^84\d{9}$/.test(v)) {
            return (
                v.substring(0, 5) +
                '*'.repeat(v.length - 8) +
                v.slice(-3)
            );
        }

        /* =====================
        * PHONE NUMBER (10 số)
        * Hiển thị: 4 số đầu + 3 số cuối
        * Ví dụ: 0906***678
        * ===================== */
        if (/^\d{10}$/.test(v)) {
            return (
                v.substring(0, 4) +
                '*'.repeat(v.length - 7) +
                v.slice(-3)
            );
        }

        /* =====================
        * CCCD (toàn số, > 6)
        * Hiển thị: 3 số đầu + 3 số cuối
        * ===================== */
        if (/^\d+$/.test(v)) {
            if (v.length <= 6) return v;
            return (
                v.substring(0, 3) +
                '*'.repeat(v.length - 6) +
                v.slice(-3)
            );
        }

        return v;
    }

    get maskedPhone() {
        return this.maskValue(
            this.data?.primaryPhone,
            this.primaryPhone
        );
    }

    get maskedNationalIDPassportID() {
        return this.maskValue(
            this.data?.nationalIDPassportID,
            this.nationalIDPassportID
        );
    }


    get phoneEyeIcon() {
        return this.primaryPhone ? 'utility:preview' : 'utility:hide';
    }

    get nationalIDEyeIcon() {
        return this.nationalIDPassportID ? 'utility:preview' : 'utility:hide';
    }

    get addresses() {
        return this.data?.addresses || [];
    }

    get helpTextMap() {
        return this.data?.helpTexts || {};
    }

    /* ================= ACTION ================= */

    handleTogglePhone() {
        this.toggleMasking('phone');
    }

    handleToggleNationalIDPassportID() {
        this.toggleMasking('nationalId');
    }


    formatDate(d) {
        if (!d) return '';
        const date = new Date(d);
        return `${date.getDate().toString().padStart(2, '0')}/${(date.getMonth() + 1).toString().padStart(2, '0')
            }/${date.getFullYear()}`;
    }
}