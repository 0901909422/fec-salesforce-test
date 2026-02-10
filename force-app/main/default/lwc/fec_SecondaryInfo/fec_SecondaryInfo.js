/****************************************************************************************
 * File Name    : Fec_SecondaryInfo.js
 * Author       : Quangdv7
 * Date         : 2025-01-13
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import loadSecondaryInfo from '@salesforce/apex/FEC_SecondaryController.loadSecondaryInfo';
import logSensitiveFromSecondaryInfo from '@salesforce/apex/FEC_SecondaryController.logSensitiveFromSecondaryInfo';

export default class Fec_SecondaryInfo extends LightningElement {

    @api recordId;

    @track hasData = false;
    @track error;

    @track zaloFollower = 'N/A';
    @track websiteAccount = 'N/A';
    @track mobileAppAccount = 'N/A';
    @track reference = [];
    @track contactList = [];
    @track helpTexts = {};

    /* ===== MASK STATE ===== */
    @track isWorkPhoneMasked = true;

    activeSections = [ 'contactList'];

    ReferenceColumns = [
        { label: 'Full Name', fieldName: 'fullName', type: 'text' },
        { label: 'Relationship', fieldName: 'relationship', type: 'text' },
        { label: 'Phone Number', fieldName: 'phoneNumber', type: 'eye', eye: true },
    ];

   contactListColumns = [
        { label: 'Channel', fieldName: 'channel', type: 'text' },
        { label: 'Communication Type', fieldName: 'communicationType', type: 'text' },
        { label: 'Contact String', fieldName: 'contactString', type: 'eye',
        eyeCondition: row => row.channel?.toLowerCase() === 'phone' },
    ];

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        loadSecondaryInfo({ caseId: this.recordId })
            .then(res => {
                this.zaloFollower     = res.zaloFollower || 'N/A';
                this.websiteAccount   = res.websiteAccount || 'N/A';
                this.mobileAppAccount = res.mobileAppAccount || 'N/A';
                this.reference        = res.references || [];
                this.contactList = res.contactList || [];
                this.helpTexts        = res.helpTexts || {};
                this.hasData = true;
            })
            .catch(err => {
                this.error = err?.body?.message || err.message;
                this.hasData = false;
                console.error(err);
            });
    }

    get contactListColumnsFiltered() {
        const hasPhone = this.contactList.some(
            row => row.channel?.toLowerCase() === 'phone'
        );

        if (!hasPhone) {
            
            return this.contactListColumns.map(col => {
                if (col.fieldName === 'contactString') {
                    return { ...col, type: 'text' };
                }
                return col;
            });
        }

        return this.contactListColumns;
    }

    /* ================= HELP TEXT ================= */

    get helpTextMap() {
        return this.helpTexts || {};
    }

    getHelpText(fieldApiName) {
        return fieldApiName
            ? this.helpTextMap[fieldApiName.toLowerCase()]
            : null;
    }

    /* ================= MASK CONFIG ================= */
    getMaskingConfig(key) {
        const configs = {
            contactString: {
                section: 'Contact List',
                fieldLabel: 'Contact String'
            },
            referencePhone: {
                section: 'Reference',
                fieldLabel: 'Reference Phone Number'
            }
        };
        return configs[key];
    }
  /* ================= CONTACTSTRING ================= */
    handleContactStringView() {
        const config = this.getMaskingConfig('contactString');

        logSensitiveFromSecondaryInfo({
            section: config.section,
            fieldLabel: config.fieldLabel,
            relatedCaseId: this.recordId
        }).catch(e => {
            console.error('Sensitive log failed', e);
        });
    }

    /* ================= REFERENCE PHONE ================= */
    handleReferencePhoneView() {
        const config = this.getMaskingConfig('referencePhone');

        logSensitiveFromSecondaryInfo({
            section: config.section,
            fieldLabel: config.fieldLabel,
            relatedCaseId: this.recordId
        }).catch(e => {
            console.error('Sensitive log failed', e);
        });
    }

    /* ===== MASK LOGIC ===== */
    maskWorkPhone(phone) {
        if (phone.length < 7) {
            return phone;
        }

        let first = phone.substring(0, 4);
        let last  = phone.substring(phone.length - 3);

        return first + '***' + last;
    }
}
