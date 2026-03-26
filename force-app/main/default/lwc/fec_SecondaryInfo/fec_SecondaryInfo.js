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

import loadSecondaryInfo from '@salesforce/apex/FEC_SecondaryController.loadSecondaryInfo';
import logSensitiveFromSecondaryInfo from '@salesforce/apex/FEC_SecondaryController.logSensitiveFromSecondaryInfo';

export default class Fec_SecondaryInfo extends LightningElement {

    @api recordId;

    @track hasData = false;
    @track error;

    @track zaloFollower = STR_NA;
    @track websiteAccount = STR_NA;
    @track mobileAppAccount = STR_NA;
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

                this.zaloFollower = res.zaloFollower || STR_NA;
                this.websiteAccount = res.websiteAccount || STR_NA;
                this.mobileAppAccount = res.mobileAppAccount || STR_NA;
                const contactList = res.contactList || [];
                this.contactList = [...contactList].sort((a, b) => {
                    const x = (a.channel || '').trim().toLowerCase();
                    const y = (b.channel || '').trim().toLowerCase();
                    return x.localeCompare(y);
                });

                const references = res.references || [];
                this.reference = [...references].sort((a, b) => {
                    const x = (a.fullName || '').trim().toLowerCase();
                    const y = (b.fullName || '').trim().toLowerCase();
                    return y.localeCompare(x);
                });
                this.helpTexts = res.helpTexts || {};
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
}
