/****************************************************************************************
 * File Name    : Fec_RelatedListAddressesPaging.js
 * Author       : Quangdv7
 * Date         : 2025-01-10
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-01-10     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import syncPaymentHistory from '@salesforce/apex/FEC_PaymentHistoryController.syncPaymentHistory';
import syncRealtimePayment from '@salesforce/apex/FEC_PaymentHistoryController.syncRealtimePayment';
import loadPaymentHistory from '@salesforce/apex/FEC_PaymentHistoryController.loadPaymentHistory';
import loadRealtimePayment from '@salesforce/apex/FEC_PaymentHistoryController.loadRealtimePayment';

export default class Fec_PaymentHistoryAccount extends LightningElement {

    /* ================= STATE ================= */
    _recordId;
    initialized = false;

    isLoading = false;
    isRealtimeLoading = false;

    paymentHistory = [];
    totalPaymentAmount = null;
    realtimePayments = [];

    activeSections = ['paymentHistory', 'realtimePayment'];

    /* ================= COLUMNS FOR CUSTOM COMPONENT ================= */
    paymentHistoryColumns = [
        { label: 'Payment No.', fieldName: 'paymentNo', type: 'text'},
        { label: 'Payment Date', fieldName: 'paymentDate', type: 'text',cellAlign: 'center' },
        { label: 'Booking Date', fieldName: 'bookingDate', type: 'text', cellAlign: 'center'},
        {
            label: 'Payment Amount',
            fieldName: 'paymentAmountDisplay',
            type: 'text',
            cellAlign: 'right',
            cellAttributes: { 
                alignment: 'right',
                class: { fieldName: 'amountColorClass' }
            }
        },
        { label: 'Particulars', fieldName: 'particulars', type: 'text',width: '250px'}
    ];

    realtimePaymentColumns = [
        { label: 'Payment Date', fieldName: 'paymentDate', type: 'text',cellAlign: 'center' },
        {
            label: 'Payment Amount',
            fieldName: 'paymentAmountDisplay',
            type: 'text',
            cellAlign: 'right',
            cellAttributes: { 
                alignment: 'right',
                class: { fieldName: 'amountColorClass' }
            }
        },
        { label: 'Payment Channel', fieldName: 'paymentChannel', type: 'text' }
    ];

    /* ================= RECORD ID ================= */
    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        if (value && value !== this._recordId) {
            this._recordId = value;
            this.initialized = false;
            this.init();
        }
    }

    /* =====================================================
       INIT DATA
       ===================================================== */
    async init() {
        if (this.initialized || !this._recordId) return;
        this.initialized = true;

        this.isLoading = true;
        this.isRealtimeLoading = true;

        try {
            await syncPaymentHistory({ caseId: this._recordId });
        } catch (e) {
            console.warn('Billing API failed', e);
        }

        try {
            await syncRealtimePayment({ caseId: this._recordId });
        } catch (e) {
            console.warn('Realtime API failed', e);
        }

        await Promise.all([
            this.loadBilling(),
            this.loadRealtime()
        ]);

        this.isLoading = false;
        this.isRealtimeLoading = false;
    }

    /* =====================================================
       LOAD BILLING
       ===================================================== */
    async loadBilling() {
        try {
            const data = await loadPaymentHistory({
                caseId: this._recordId
            });

            this.paymentHistory = (data || []).map((row, index) => {
                return {
                    paymentNo: index + 1,
                    ...this.transformRow(row)
                   
                };
            });

            this.totalPaymentAmount = this.paymentHistory.reduce(
                (sum, row) => sum + (Number(row.paymentAmount) || 0),
                0
            );
        } catch (e) {
            this.paymentHistory = [];
            this.totalPaymentAmount = null;
        }
    }

    /* =====================================================
       LOAD REALTIME
       ===================================================== */
    async loadRealtime() {
        try {
            const data = await loadRealtimePayment({
                caseId: this._recordId
            });

            this.realtimePayments = (data || []).map(row => 
                this.transformRow(row)
            );

        } catch (e) {
            this.realtimePayments = [];
        }
    }

    /* =====================================================
       REFRESH BUTTON
       ===================================================== */
    async handleRefreshData() {
        this.isRealtimeLoading = true;

        try {
            await syncPaymentHistory({ caseId: this._recordId });
            await syncRealtimePayment({ caseId: this._recordId });
        } catch (e) {
            console.warn('Refresh failed', e);
        }

        await Promise.all([
            this.loadBilling(),
            this.loadRealtime()
        ]);

        this.isRealtimeLoading = false;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Payment data refreshed successfully',
                variant: 'success'
            })
        );
    }

    /* =====================================================
       TRANSFORM ROW - Format dates & amounts + color class
       ===================================================== */
    transformRow(row) {
        const amount = Number(row.paymentAmount) || 0;
        const absAmount = Math.abs(amount);
        const formattedAmount = absAmount.toLocaleString('en-US');

        const displayAmount = amount < 0 
            ? `-${formattedAmount}` 
            : formattedAmount;

        const colorClass = amount < 0 
            ? 'slds-text-color_error slds-text-title_bold' 
            : '';

        return {
            ...row,
            paymentDate: this.formatDate(row.paymentDate),
            bookingDate: this.formatDate(row.bookingDate),
            paymentAmountDisplay: displayAmount,
            amountColorClass: colorClass
        };
    }

    /* =====================================================
       FORMAT DATE - dd/MM/yyyy
       ===================================================== */
    formatDate(value) {
        if (!value) return '';
        
        try {
            const d = new Date(value);
            if (isNaN(d.getTime())) return '';
            
            const day = String(d.getDate()).padStart(2, '0');
            const month = String(d.getMonth() + 1).padStart(2, '0');
            const year = d.getFullYear();
            
            return `${day}/${month}/${year}`;
        } catch (e) {
            return '';
        }
    }

    /* =====================================================
       FORMAT TOTAL AMOUNT
       ===================================================== */
    get formattedTotalAmount() {
        if (this.totalPaymentAmount === null || this.totalPaymentAmount === undefined) {
            return '';
        }

        const amount = Number(this.totalPaymentAmount) || 0;
        const absAmount = Math.abs(amount);
        const formatted = absAmount.toLocaleString('en-US');

        return amount < 0 ? `-${formatted}` : formatted;
    }

}