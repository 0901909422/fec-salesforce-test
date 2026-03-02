/****************************************************************************************
 * File Name    : Fec_StatementsAccountTabView.js
 * Author       : Quangdv7
 * Date         : 2025-01-15
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, wire, track } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { NavigationMixin } from 'lightning/navigation';
import { setConsoleTab } from 'c/fec_CommonUtils';

import loadStatementDetails from '@salesforce/apex/FEC_StatementsAccountController.loadStatementDetails';
import getBilledTransactions from '@salesforce/apex/FEC_StatementsAccountController.getBilledTransactions';

export default class Fec_StatementsAccountTabView extends NavigationMixin(LightningElement) {

    // ==============================
    // STATE
    // ==============================
    @track statement;
    @track billedTransactions = [];
    @track isLoading = false;

    statementId;
    activeSections = ['statementDetail', 'billedTx'];

    // ==============================
    // COLUMNS
    // ==============================
    billedTransactionsColumns = [
        {
            label: 'Transaction Code',
            fieldName: 'transactionCode',
            type: 'link',
            recordIdField: 'Id',
            hoverTitle: 'Billed Transactions',
            cellAlign: 'center',
            hoverFields: [
                { label: 'Effective Date', fieldName: 'effectiveDate' },
                { label: 'Post Date', fieldName: 'postDate' },
                { label: 'Transaction Amount', fieldName: 'transactionAmount' },
                { label: 'Merchant Description', fieldName: 'merchantDescription' },
                { label: 'Credit Debit Flag', fieldName: 'creditDebitFlag' },
                { label: 'Transaction Plan', fieldName: 'transactionPlan' },
                { label: 'Transaction Code', fieldName: 'transactionCode' },
                { label: 'Authorization Code', fieldName: 'authorizationCode' },
                { label: 'Merchant Category Code', fieldName: 'merchantCategoryCode' },
                { label: 'Currency Code', fieldName: 'currencyCode' },
                { label: 'OTP Sent', fieldName: 'otpSent' }

            ]
        },
        { label: 'Effective Date', fieldName: 'effectiveDate', type: 'text', cellAlign: 'center' },
        { label: 'Post Date', fieldName: 'postDate', type: 'text', cellAlign: 'center' },
        { label: 'Transaction Amount', fieldName: 'transactionAmount', type: 'text', cellAlign: 'right' },
        { label: 'Merchant Description', fieldName: 'merchantDescription', type: 'text' },
        { label: 'Credit Debit Flag', fieldName: 'creditDebitFlag', type: 'text', cellAlign: 'center' }
    ];

    // ==============================
    // PAGE STATE
    // ==============================
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        const idFromTab = pageRef?.state?.c__statementId;
        if (!idFromTab || idFromTab === this.statementId) return;

        this.statementId = idFromTab;
        this.loadData();
    }

    // ==============================
    // LOAD DATA
    // ==============================
    async loadData() {
        if (!this.statementId) return;

        this.isLoading = true;

        try {
            const [statementRes, billedTxRes] = await Promise.all([
                loadStatementDetails({ statementId: this.statementId }),
                getBilledTransactions({ statementId: this.statementId })
            ]);

            this.statement =
                Array.isArray(statementRes) && statementRes.length
                    ? statementRes[0]
                    : null;

            this.billedTransactions = this.formatBilledTransactions(billedTxRes);

        } catch (error) {
            console.error('Load data error:', error);
            this.statement = null;
            this.billedTransactions = [];
        } finally {
            this.isLoading = false;
        }
    }

    /* ================= SET TABNAME ================= */
    connectedCallback() {
        setConsoleTab('Statements Detail', 'standard:record');
    }

    // ==============================
    // COMPUTED
    // ==============================
    get hasStatement() {
        return !!this.statement;
    }

    get statementSubTitle() {
        return this.formatDate(this.statement?.statementDate);
    }

    // ==============================
    // DETAIL SECTIONS 
    // ==============================
    get detailSections() {
        if (!this.statement) return [];

        const fields = [
            { label: 'Statement Date', value: this.formatDate(this.statement.statementDate), apiName: 'FEC_Statement_Date__c' },
            { label: 'Total Payment Due', value: this.formatNumber(this.statement.totalPaymentDue), apiName: 'FEC_Total_Payment_Due__c' },
            { label: 'Total Interest', value: this.formatNumber(this.statement.FEC_Total_Interest__c), apiName: 'FEC_Total_Interest__c' },
            { label: 'Beginning Balance', value: this.formatNumber(this.statement.beginningBalance), apiName: 'FEC_Beginning_Balance__c' },
            { label: 'Payment Due Date', value: this.formatDate(this.statement.paymentDueDate), apiName: 'FEC_Payment_Due_Date__c' },
            { label: 'Minimum Payment Due', value: this.formatNumber(this.statement.minimumPaymentDue), apiName: 'FEC_Minimum_Payment_Due__c' },
            { label: 'IPP Principal', value: this.formatNumber(this.statement.FEC_IPP_Principal__c), apiName: 'FEC_IPP_Principal__c' },
            { label: 'End Balance', value: this.formatNumber(this.statement.endBalance), apiName: 'FEC_End_Balance__c' },
            { label: 'Total Past Due', value: this.formatNumber(this.statement.FEC_Total_Past_Due__c), apiName: 'FEC_Total_Past_Due__c' },
            { label: 'Current Payment Due', value: this.formatNumber(this.statement.currentPaymentDue), apiName: 'FEC_Current_Payment_Due__c' },
            { label: 'IPP Interest', value: this.formatNumber(this.statement.FEC_IPP_Interest__c), apiName: 'FEC_IPP_Interest__c' }
        ];
        return [
            {
                name: 'statementDetail',
                columns: 4,
                label: 'Statement Details',
                fields: this.addHelpTextToFields(fields)
            }
        ];
    }

    // ==============================
    // FORMAT BILLED TX 
    // ==============================
    formatBilledTransactions(records) {
        if (!Array.isArray(records)) return [];

        return records.map(tx => ({
            ...tx,
            effectiveDate: this.formatDate(tx.effectiveDate),
            postDate: this.formatDate(tx.postDate),
            transactionAmount: this.formatNumber(tx.transactionAmount)
        }));
    }

    // ==============================
    // FORMAT HELPERS
    // ==============================
    formatDate(value) {
        if (!value) return '';
        const d = new Date(value);
        if (isNaN(d)) return value;

        return new Intl.DateTimeFormat('vi-VN', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
        }).format(d);
    }

    formatNumber(value) {
        if (value === null || value === undefined || value === '') return '';
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        }).format(value);
    }

    addHelpTextToFields(fields) {
        if (!this.statement || !this.statement.helpTexts) {
            return fields;
        }

        const helpTexts = this.statement.helpTexts;

        return fields.map(f => {
            const apiName = f.apiName;
            const helpText =
                apiName
                    ? helpTexts[apiName] || helpTexts[apiName.toLowerCase()]
                    : null;

            return {
                ...f,
                helpText,
                hasHelpText: !!helpText
            };
        });
    }

    // ==============================
    // NAVIGATION
    // ==============================
    handleTransactionSelect(event) {
        const transactionId = event.detail.recordId;
        if (!transactionId) return;

        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'FEC_Transactions'
            },
            state: {
                c__transactionId: transactionId,
                c__sectionType: 'billed'
            }
        });
    }
}
