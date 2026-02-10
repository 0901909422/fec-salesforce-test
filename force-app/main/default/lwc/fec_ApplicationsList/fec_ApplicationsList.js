/****************************************************************************************
 * File Name    : Fec_ApplicationsList.js
 * Author       : Quangdv7
 * Date         : 2025-01-17
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-17     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { NavigationMixin } from 'lightning/navigation';

import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';

import refreshApplications
    from '@salesforce/apex/FEC_ApplicationsListController.loadApplicationInfo';
import getApplications
    from '@salesforce/apex/FEC_ApplicationsListController.getApplicationsForUI';

export default class Fec_ApplicationsList extends NavigationMixin(LightningElement) {

    @api recordId;

    @track registration = [];
    @track hasData = false;
    @track error;
    isLoading = false;
    activeSections = ['registration'];
    registrationColumns = [
        {
            label: 'Application ID',
            fieldName: 'applicationId',
            type: 'link',
            recordIdField: 'Id',
            hoverFields: [
                {
                      section: 'Registration Info',
                      items: [
                            { label: 'Application ID', fieldName: 'applicationId' },
                            { label: 'National/ Passport ID', fieldName: 'nationalPassportIDMasked' },
                            { label: 'Account Number', fieldName: 'accountNumber' },
                            { label: 'Registration Phone', fieldName: 'registrationPhoneMasked' },
                            { label: 'Contract Number', fieldName: 'contractNumber' }, 
                            { label: 'Registration Email', fieldName: 'registrationEmail' },
                            { label: 'Last Status', fieldName: 'lastStatus' },
                            { label: 'Current Address', fieldName: 'currentAddress' },
                            { label: 'Updated Date', fieldName: 'updateDate' },
                            { label: 'Permanent Address', fieldName: 'permanentAddress' },
                            { label: 'Product Group', fieldName: 'productGroup' },
                            { label: 'Office Address', fieldName: 'officeAddress' },
                      ]
                },
               {
                  section: 'Sales',
                    items: [
                        { label: 'CC Code', fieldName: 'ccCode' },
                        { label: 'CC Name', fieldName: 'ccName' },
                        { label: 'DSA Code', fieldName: 'dSACode' },
                        { label: 'DSA Name', fieldName: 'dSAName' },
                        { label: 'TSA Code', fieldName: 'tSACode' },
                        { label: 'TSA Name', fieldName: 'tSAName' }
                    ]
               },
            ]
        },
        { label: 'Account Number', fieldName: 'accountNumber' },
        { label: 'Contract Number', fieldName: 'contractNumber' },
        { label: 'Last Status', fieldName: 'lastStatus' },
        { label: 'Update Date', fieldName: 'updateDate',cellAlign: 'center' }
    ];

    connectedCallback() {
        loadStyle(this, COMMON_STYLES)
            .then(() => {
                if (this.recordId) {
                    this.loadData();
                }
            })
            .catch(console.error);
    }

    async loadData() {
        this.isLoading = true;
        this.error = null;

        try {
            await refreshApplications({ caseId: this.recordId });

            const data = await getApplications({ caseId: this.recordId });

            this.registration = (data || []).map(row => ({
                Id: row.id,
                applicationId: row.applicationId,
                accountNumber: row.accountNumber,
                contractNumber: row.contractNumber,
                lastStatus: row.lastStatus,
                updateDate: this.formatDateDDMMYYYY(row.updateDate),
                productGroup: row.productGroup,
                nationalPassportID: row.nationalPassportID,
                registrationPhone: row.registrationPhone,
                // ====== MASKED (dùng để hiển thị)
                nationalPassportIDMasked: this.maskValue(row.nationalPassportID, false),
                registrationPhoneMasked: this.maskValue(row.registrationPhone, false),
                registrationEmail: row.registrationEmail,
                currentAddress: row.currentAddress,
                permanentAddress: row.permanentAddress,
                officeAddress: row.officeAddress,
                ccCode: row.ccCode,
                ccName: row.ccName,
                dSACode: row.dSACode,
                dSAName: row.dSAName,
                tSACode: row.tSACode,
                tSAName: row.tSAName

            }));

            this.hasData = this.registration.length > 0;

        } catch (err) {
            this.error = err?.body?.message || err.message;
            this.registration = [];
            this.hasData = false;
        } finally {
            this.isLoading = false;
        }
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

    formatDateDDMMYYYY(value) {
        if (!value) return '-';

        // Expect yyyy-mm-dd
        const parts = value.split('-');
        if (parts.length !== 3) return value;

        const [yyyy, mm, dd] = parts;
        return `${dd}/${mm}/${yyyy}`;
    }

    handleRegistrationSelect(event) {
        const applicationListId = event.detail.recordId;
        if (!applicationListId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'ApplicationList'
            },
            state: {
                c__ApplicationList: applicationListId
            }
        });
    }
}