import { LightningElement, api, track } from 'lwc';
import { maskWorkPhone } from 'c/fec_CommonUtils';
import loadSecondaryInfo from '@salesforce/apex/FEC_SecondaryController.loadSecondaryInfo';
import logSensitiveFromSecondaryInfo from '@salesforce/apex/FEC_SecondaryController.logSensitiveFromSecondaryInfo';

import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Self_Service_Channel_Label from '@salesforce/label/c.FEC_Self_Service_Channel_Label';
import FEC_Contact_List_Label from '@salesforce/label/c.FEC_Contact_List_Label';
import FEC_Reference_Info_Label from '@salesforce/label/c.FEC_Reference_Info_Label';
import FEC_Zalo_Follower_Label from '@salesforce/label/c.FEC_Zalo_Follower_Label';
import FEC_Mobile_App_Account_Label from '@salesforce/label/c.FEC_Mobile_App_Account_Label';
import FEC_Website_Account_Label from '@salesforce/label/c.FEC_Website_Account_Label';
import FEC_Email_Label from '@salesforce/label/c.FEC_Email_Label';
import FEC_Work_Phone_Label from '@salesforce/label/c.FEC_Work_Phone_Label';

import { STR_NA } from 'c/fec_CommonConst';

export default class Fec_SecondaryInfo extends LightningElement {

    @api recordId;

    @track hasData = false;
    @track error;

    @track zaloFollower = STR_NA;
    @track websiteAccount = STR_NA;
    @track mobileAppAccount = STR_NA;
    @track email = STR_NA;
    @track workPhone = STR_NA;
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

    customLabel = {
        msgErrorApiLabel: FEC_MSG_Error_API_Label,
        selfServiceChannelLabel: FEC_Self_Service_Channel_Label,
        contactListLabel: FEC_Contact_List_Label,
        referenceInfoLabel: FEC_Reference_Info_Label,
        zaloFollowerLabel: FEC_Zalo_Follower_Label,
        mobileAppAccountLabel: FEC_Mobile_App_Account_Label,
        websiteAccountLabel: FEC_Website_Account_Label,
        emailLabel: FEC_Email_Label,
        workPhoneLabel: FEC_Work_Phone_Label
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        loadSecondaryInfo({ caseId: this.recordId })
            .then(res => {
                this.zaloFollower     = res.zaloFollower || STR_NA;
                this.websiteAccount   = res.websiteAccount || STR_NA;
                this.mobileAppAccount = res.mobileAppAccount || STR_NA;
                this.email            = res.email || STR_NA;
                this.workPhone        = res.workPhone || STR_NA;
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
        if (!this.workPhone || this.workPhone === STR_NA) {
            return this.workPhone;
        }

        if (!this.isWorkPhoneMasked) {
            return this.workPhone;
        }

        return maskWorkPhone(this.workPhone);
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
    
}