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
import { maskValue,formatDate } from 'c/fec_CommonUtils';

import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';

import refreshApplications from '@salesforce/apex/FEC_ApplicationsListController.loadApplicationInfo';
import getApplications from '@salesforce/apex/FEC_ApplicationsListController.getApplicationsForUI';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Registration_Info_Label from '@salesforce/label/c.FEC_Registration_Info_Label';

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

    customLabel = {
        msgErrorApiLabel: FEC_MSG_Error_API_Label,
        registrationInfoLabel: FEC_Registration_Info_Label
    }

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
                updateDate: formatDate(row.updateDate),
                productGroup: row.productGroup,
                nationalPassportID: row.nationalPassportID,
                registrationPhone: row.registrationPhone,
                nationalPassportIDMasked: maskValue(row.nationalPassportID, false),
                registrationPhoneMasked: maskValue(row.registrationPhone, false),
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