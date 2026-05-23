/****************************************************************************************
 * File Name    : Fec_Banca.js
 * Author       : Quangdv7
 * Date         : 2025-01-17
 * Description  : Handle Insurance(Banca) Information
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
 * 1.0      2025-01-17                         Create
****************************************************************************************/

import { LightningElement, api, track } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { NavigationMixin } from 'lightning/navigation';
import { maskValue, formatDateVNI } from 'c/fec_CommonUtils';
import { getFocusedTabInfo, openSubtab } from 'lightning/platformWorkspaceApi';

import COMMON_STYLES from '@salesforce/resourceUrl/FEC_CommonCss';

import loadataInsurance from '@salesforce/apex/FEC_BancaController.loadataInsurance';

import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Insurance_Info_Error from '@salesforce/label/c.FEC_Insurance_Info_Error';

export default class Fec_Banca extends NavigationMixin(LightningElement) {

    @api recordId;

    @track insuranceInfo = [];
    @track hasData = false;
    @track error;

    isLoading = false;

    activeSections = ['Insurance Info'];

    insuranceColumns = [
        {
            label: 'User ID',
            fieldName: 'userId',
            type: 'link',
            recordIdField: 'Id',

            hoverTitle: 'User ID',

            hoverFields: [
                { label: 'Gender', fieldName: 'gender' },
                { label: 'Sales Channel', fieldName: 'salesChannel' },
                { label: 'Insurance Company', fieldName: 'insuranceCompany' },
                { label: 'Sub Channel', fieldName: 'subChannel' },
                { label: 'Policy Number', fieldName: 'policyNumber' },
                { label: 'Agent Code', fieldName: 'agentCode' },
                { label: 'Phone Number', fieldName: 'phoneNumber' },
                { label: 'Agent Name', fieldName: 'agentName' },
                { label: 'Expiry Date', fieldName: 'expiryDate' },
                { label: 'Payment ID', fieldName: 'paymentID' },
                { label: 'Cancel Date', fieldName: 'cancelDate' },
                { label: 'Effective Date', fieldName: 'effectiveDate' }
            ]
        },

        { label: 'Buyer Name', fieldName: 'buyerName' },
        { label: 'Date of Birth', fieldName: 'dateofBirth', cellAlign: 'center'},
        { label: 'Buyer NID', fieldName: 'buyerNID', cellAlign: 'center',  type: 'eye'},
        { label: 'Product Name', fieldName: 'productName' },
        { label: 'Premium Free', fieldName: 'premiumFree', cellAlign: 'right' },
        { label: 'Status', fieldName: 'status' }
    ];

    customLabel = {
        msgErrorApiLabel: FEC_MSG_Error_API_Label,
        insuranceInfoLabel: FEC_Insurance_Info_Error
    };

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

            const data = await loadataInsurance({
                caseId: this.recordId
            });

            this.insuranceInfo = (data || []).map(row => ({

                Id: row.Id,

                userId: row.userId,
                buyerName: row.buyerName,

                dateofBirth: row.dateofBirth
                    ? formatDateVNI(row.dateofBirth)
                    : '',

                buyerNID: row.buyerNID,

                productName: row.productName,
                premiumFree: row.premiumFree,
                status: row.status,

                gender: row.gender,
                salesChannel: row.salesChannel,
                insuranceCompany: row.insuranceCompany,
                subChannel: row.subChannel,
                policyNumber: row.policyNumber,
                agentCode: row.agentCode,
                phoneNumber: row.phoneNumber,
                agentName: row.agentName,

                expiryDate: row.expiryDate
                    ? formatDateVNI(row.expiryDate)
                    : '',

                paymentID: row.paymentID,

                cancelDate: row.cancelDate
                    ? formatDateVNI(row.cancelDate)
                    : '',

                effectiveDate: row.effectiveDate
                    ? formatDateVNI(row.effectiveDate)
                    : ''
            }));

            this.hasData = this.insuranceInfo.length > 0;

        } catch (err) {

            this.error = err?.body?.message || err.message;

            this.insuranceInfo = [];
            this.hasData = false;

            // console.error('Load Insurance Error:', this.error);
            console.error('Load Insurance Error:', JSON.stringify(err));

        } finally {

            this.isLoading = false;
        }
    }

    async handleInsuranceSelect(event) {

        const recordId = event.detail.recordId;

        const row = this.insuranceInfo.find(
            r => r.Id === recordId
        );

        if (!row) {
            console.error('Insurance not found:', recordId);
            return;
        }

        const tabInfo = await getFocusedTabInfo();

        const parentTabId = tabInfo.isSubtab
            ? tabInfo.parentTabId
            : tabInfo.tabId;

        await openSubtab(parentTabId, {

            pageReference: {
                type: 'standard__navItemPage',

                attributes: {
                    apiName: 'FEC_BancaTabView'
                },

                state: {
                    c__insuranceId: row.Id,
                    c__userId: row.userId,
                    uid: row.userId
                }
            },

            focus: true,
            label: `Insurance ${row.userId}`
        });
    }
}