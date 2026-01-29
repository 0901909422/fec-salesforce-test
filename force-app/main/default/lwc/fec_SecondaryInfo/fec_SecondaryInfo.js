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
    @track email = 'N/A';
    @track workPhone = 'N/A';
    @track reference = [];

    /* ===== MASK STATE ===== */
    @track isWorkPhoneMasked = true;

    activeSections = ['selfService', 'contactList', 'reference'];

    ReferenceColumns = [
        { label: 'Full Name', fieldName: 'fullName', type: 'text' },
        { label: 'Relationship', fieldName: 'relationship', type: 'text' },
        { label: 'Phone Number', fieldName: 'phoneNumber', type: 'eye',
        eye: true },
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
                this.email            = res.email || 'N/A';
                this.workPhone        = res.workPhone || 'N/A';
                 this.reference       = res.references || [];
                this.hasData = true;
            })
            .catch(err => {
                this.error = err?.body?.message || err.message;
                this.hasData = false;
                console.error(err);
            });
    }

    /* ================= MASK CONFIG ================= */
    getMaskingConfig(key) {
        const configs = {
            workPhone: {
                section: 'Secondary Info',
                fieldLabel: 'Work Phone',
                fieldApi: 'FEC_Work_Phone__c'
            },
            referencePhone: {
                section: 'Reference',
                fieldLabel: 'Reference Phone Number'
            }
        };
        return configs[key];
    }

    /* ===== ICON ===== */
    get workPhoneIcon() {
        return this.isWorkPhoneMasked ? 'utility:preview':'utility:hide';
    }

    /* ===== DISPLAY VALUE ===== */
    get displayWorkPhone() {
        if (!this.workPhone || this.workPhone === 'N/A') {
            return this.workPhone;
        }

        if (!this.isWorkPhoneMasked) {
            return this.workPhone;
        }

        return this.maskWorkPhone(this.workPhone);
    }


    handleToggleWorkPhone() {
        const config = this.getMaskingConfig('workPhone');

        if (this.isWorkPhoneMasked) {
            logSensitiveFromSecondaryInfo({
                section: config.section,
                fieldLabel: config.fieldLabel,
                relatedCaseId: this.recordId
            }).catch(e => {
                console.error('Sensitive log failed', e);
            });
        }

        this.isWorkPhoneMasked = !this.isWorkPhoneMasked;
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