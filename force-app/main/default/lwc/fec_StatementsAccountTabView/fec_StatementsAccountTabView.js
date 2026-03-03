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

import FEC_Statement from '@salesforce/label/c.FEC_Statement';
import FEC_Billed_Transactions from '@salesforce/label/c.FEC_Billed_Transactions';
import FEC_MSG_No_statement_selected from '@salesforce/label/c.FEC_MSG_No_statement_selected';
import FEC_Total_Payment_Due from '@salesforce/label/c.FEC_Total_Payment_Due';
import FEC_Payment_Due_Date from '@salesforce/label/c.FEC_Payment_Due_Date';
import FEC_Minimum_Payment_Due from '@salesforce/label/c.FEC_Minimum_Payment_Due';
import FEC_Statement_Date from '@salesforce/label/c.FEC_Statement_Date';
import FEC_Total_Interest from '@salesforce/label/c.FEC_Total_Interest';
import FEC_Beginning_Balance from '@salesforce/label/c.FEC_Beginning_Balance';
import FEC_IPP_Principal from '@salesforce/label/c.FEC_IPP_Principal';
import FEC_End_Balance from '@salesforce/label/c.FEC_End_Balance';
import FEC_Total_Past_Due from '@salesforce/label/c.FEC_Total_Past_Due';
import FEC_Current_Payment_Due from '@salesforce/label/c.FEC_Current_Payment_Due';
import FEC_IPP_Interest from '@salesforce/label/c.FEC_IPP_Interest';
import FEC_Statement_Details from '@salesforce/label/c.FEC_Statement_Details';

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

    customLabel = {
        statementLabel: FEC_Statement,
        billedTransactionsLabel: FEC_Billed_Transactions,
        msgNoStatementSelected: FEC_MSG_No_statement_selected,
        totalPaymentDueLabel: FEC_Total_Payment_Due,
        paymentDueDateLabel: FEC_Payment_Due_Date,
        minimumPaymentDueLabel: FEC_Minimum_Payment_Due,
        statementDateLabel: FEC_Statement_Date,
        totalInterestLabel: FEC_Total_Interest,
        beginningBalanceLabel: FEC_Beginning_Balance,
        ippPrincipalLabel: FEC_IPP_Principal,
        endBalanceLabel: FEC_End_Balance,
        totalPastDueLabel: FEC_Total_Past_Due,
        currentPaymentDueLabel: FEC_Current_Payment_Due,
        ippInterestLabel: FEC_IPP_Interest,
        statementDetailsLabel: FEC_Statement_Details
    }

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
            setConsoleTab('Statements Detail', 'standard:record');

        } catch (error) {
            console.error('Load data error:', error);
            this.statement = null;
            this.billedTransactions = [];
        } finally {
            this.isLoading = false;
        }
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
            { label: this.customLabel.statementDateLabel, value: this.formatDate(this.statement.statementDate), apiName: 'FEC_Statement_Date__c' },
            { label: this.customLabel.totalPaymentDueLabel, value: this.formatNumber(this.statement.totalPaymentDue), apiName: 'FEC_Total_Payment_Due__c' },
            { label: this.customLabel.totalInterestLabel, value: this.formatNumber(this.statement.FEC_Total_Interest__c), apiName: 'FEC_Total_Interest__c' },
            { label: this.customLabel.beginningBalanceLabel, value: this.formatNumber(this.statement.beginningBalance), apiName: 'FEC_Beginning_Balance__c' },
            { label: this.customLabel.paymentDueDateLabel, value: this.formatDate(this.statement.paymentDueDate), apiName: 'FEC_Payment_Due_Date__c' },
            { label: this.customLabel.minimumPaymentDueLabel, value: this.formatNumber(this.statement.minimumPaymentDue), apiName: 'FEC_Minimum_Payment_Due__c' },
            { label: this.customLabel.ippPrincipalLabel, value: this.formatNumber(this.statement.FEC_IPP_Principal__c), apiName: 'FEC_IPP_Principal__c' },
            { label: this.customLabel.endBalanceLabel, value: this.formatNumber(this.statement.endBalance), apiName: 'FEC_End_Balance__c' },
            { label: this.customLabel.totalPastDueLabel, value: this.formatNumber(this.statement.FEC_Total_Past_Due__c), apiName: 'FEC_Total_Past_Due__c' },
            { label: this.customLabel.currentPaymentDueLabel, value: this.formatNumber(this.statement.currentPaymentDue), apiName: 'FEC_Current_Payment_Due__c' },
            { label: this.customLabel.ippInterestLabel, value: this.formatNumber(this.statement.FEC_IPP_Interest__c), apiName: 'FEC_IPP_Interest__c' }
        ];
        return [
            {
                name: 'statementDetail',
                columns: 4,
                label: this.customLabel.statementDetailsLabel,
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
