/****************************************************************************************
 * File Name    : Fec_StatementsAccount.js
 * Author       : Quangdv7
 * Date         : 2025-01-15
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getLatestStatementId from '@salesforce/apex/FEC_StatementsAccountController.getLatestStatementId';
import syncStatementFromAPI from '@salesforce/apex/FEC_StatementsAccountController.syncStatementFromAPI';
import loadGeneralStatementInfo from '@salesforce/apex/FEC_StatementsAccountController.loadGeneralStatementInfo';
import loadStatementDetails from '@salesforce/apex/FEC_StatementsAccountController.loadStatementDetails';

import FEC_Billing_Cycle from '@salesforce/label/c.FEC_Billing_Cycle';
import FEC_Total_Payment_Due from '@salesforce/label/c.FEC_Total_Payment_Due';
import FEC_Last_Statement_Date from '@salesforce/label/c.FEC_Last_Statement_Date';
import FEC_Payment_Due_Date from '@salesforce/label/c.FEC_Payment_Due_Date';
import FEC_Minimum_Payment_Due from '@salesforce/label/c.FEC_Minimum_Payment_Due';
import FEC_Next_Statement_Date from '@salesforce/label/c.FEC_Next_Statement_Date';

export default class Fec_StatementsAccount extends NavigationMixin(LightningElement) {

    /* ================= API ================= */
    @api recordId;

    /* ================= UI STATE ================= */
    activeSections = [
        'General Statement Info',
        'Statement Details'
    ];

    isLoading = false;
    error;

    /* ================= DATA ================= */
    generalStatementInfoFields = [];
    statementDetails = [];
    helpTexts = {}; // 

    /* ================= TABLE COLUMNS ================= */
    statementDetailsColumns = [
        {
            label: 'Statement Date',
            fieldName: 'statementDate',
            type: 'link',
            recordIdField: 'Id',
            hoverTitle: 'Statement Details',
            cellAlign: 'center',
            hoverFields: [
                { label: 'Statement Date', fieldName: 'statementDate' },
                { label: 'Beginning Balance', fieldName: 'beginningBalance' },
                { label: 'Total Payment Due', fieldName: 'totalPaymentDue' },
                { label: 'End Balance', fieldName: 'endBalance' },
                { label: 'Minimum Payment Due', fieldName: 'minimumPaymentDue' },
                { label: 'Total Interest', fieldName: 'totalInterest' },
                { label: 'Payment Due Date', fieldName: 'paymentDueDate' },
                { label: 'IPP Principal', fieldName: 'iPPPrincipal' },
                { label: 'Current Payment Due', fieldName: 'currentPaymentDue' },
                { label: 'IPP Interest', fieldName: 'iPPInterest' },
                { label: 'Total Past Due', fieldName: 'totalPastDue' }
            ]
        },
        {
            label: 'Total Payment Due',
            fieldName: 'totalPaymentDue',
            type: 'text',
            cellAlign: 'right'
        },
        {
            label: 'Minimum Payment Due',
            fieldName: 'minimumPaymentDue',
            type: 'text',
            cellAlign: 'right'
        },
        {
            label: 'Payment Due Date',
            fieldName: 'paymentDueDate',
            type: 'text',
            cellAlign: 'center'
        }
    ];

    customLabel = {
        billingCycleLabel: FEC_Billing_Cycle,
        totalPaymentDueLabel: FEC_Total_Payment_Due,
        lastStatementDateLabel: FEC_Last_Statement_Date,
        paymentDueDateLabel: FEC_Payment_Due_Date,
        minimumPaymentDueLabel: FEC_Minimum_Payment_Due,
        nextStatementDateLabel: FEC_Next_Statement_Date
    }

    /* ================= LIFECYCLE ================= */
    connectedCallback() {
        this.loadData();
    }

    /* ================= LOAD DATA ================= */
    async loadData() {
        if (!this.recordId) return;

        this.isLoading = true;

        try {
            await syncStatementFromAPI({ caseId: this.recordId });

            const statementId = await getLatestStatementId({
                caseId: this.recordId
            });

            if (!statementId) {
                this.generalStatementInfoFields = [];
                this.statementDetails = [];
                return;
            }

            const [general, details] = await Promise.all([
                loadGeneralStatementInfo({ statementId }),
                loadStatementDetails({ statementId })
            ]);

            this.helpTexts = general?.helpTexts || {};
            this.mapGeneralStatementInfo(general);
            this.mapStatementDetails(details);

            this.error = undefined;
        } catch (err) {
            console.error(err);
            this.error = err?.body?.message || err.message;
        } finally {
            this.isLoading = false;
        }
    }

    /* ================= MAP GENERAL INFO ================= */
    mapGeneralStatementInfo(dto) {
        if (!dto) {
            this.generalStatementInfoFields = [];
            return;
        }

        this.generalStatementInfoFields = [
            this.buildField(this.customLabel.billingCycleLabel, dto.billingCycle, 'FEC_Billing_Cycle__c'),
            this.buildField(this.customLabel.totalPaymentDueLabel, this.formatNumber(dto.totalPaymentDue), 'FEC_Total_Payment_Due__c'),
            this.buildField(this.customLabel.lastStatementDateLabel, this.formatDate(dto.lastStatementDate), 'FEC_Last_Statement_Date__c'),
            this.buildField(this.customLabel.paymentDueDateLabel, this.formatDate(dto.paymentDueDate), 'FEC_Payment_Due_Date__c'),
            this.buildField(this.customLabel.minimumPaymentDueLabel, this.formatNumber(dto.minimumPaymentDue), 'FEC_Minimum_Payment_Due__c'),
            this.buildField(this.customLabel.nextStatementDateLabel, this.formatDate(dto.nextStatementDate), 'FEC_Next_Statement_Date__c')
        ];
    }

    /* ================= MAP STATEMENT DETAILS ================= */
    mapStatementDetails(data = []) {
        this.statementDetails = data.map(row => ({
            Id: row.statementId,

            statementDate: this.formatDate(row.statementDate),
            paymentDueDate: this.formatDate(row.paymentDueDate),

            totalPaymentDue: this.formatNumber(row.totalPaymentDue),
            minimumPaymentDue: this.formatNumber(row.minimumPaymentDue),

            currentPaymentDue: this.formatNumber(row.currentPaymentDue),
            totalPastDue: this.formatNumber(row.totalPastDue),

            beginningBalance: this.formatNumber(row.beginningBalance),
            endBalance: this.formatNumber(row.endBalance),

            totalInterest: this.formatNumber(row.totalInterest),
            iPPPrincipal: this.formatNumber(row.iPPPrincipal),
            iPPInterest: this.formatNumber(row.iPPInterest)
        }));
    }

    /* ================= FIELD BUILDER ================= */
    buildField(label, value, fieldApiName) {
        const helpText = this.helpTexts?.[fieldApiName];

        return {
            label,
            value: value ?? '-',
            helpText,
            hasHelpText: Boolean(helpText)
        };
    }

    /* ================= LINK CLICK ================= */
    handleStatementSelect(event) {
        const statementId = event.detail.recordId;
        if (!statementId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'FEC_Statements' },
            state: { c__statementId: statementId }
        });
    }

    /* ================= FORMATTERS ================= */
    formatDate(value) {
        if (!value) return '-';
        const d = new Date(value);
        if (isNaN(d)) return '-';
        return `${String(d.getDate()).padStart(2, '0')}/${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`;
    }

    formatNumber(value) {
        if (value === null || value === undefined) return '-';
        return new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 }).format(value);
    }
}