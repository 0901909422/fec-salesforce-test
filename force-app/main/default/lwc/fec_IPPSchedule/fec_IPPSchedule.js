import { LightningElement, api, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import FEC_IPP_NAVIGATION from '@salesforce/messageChannel/FEC_IPP_Navigation__c';
import getIPPScheduleData from '@salesforce/apex/FEC_IPPScheduleController.getIPPScheduleData';
import { formatCurrency, isNegative, autoHighlightNegativeCurrencyForRecords } from 'c/fec_currencyUtils';

export default class Fec_IPPSchedule extends LightningElement {
    @api recordId;
    
    // Message Context for LMS
    @wire(MessageContext)
    messageContext;
    subscription = null;
    
    scheduleData = [];
    formattedScheduleData = [];
    
    // Totals
    totalPaymentAmount = 0;
    totalMonthlyPrincipal = 0;
    totalMonthlyInterest = 0;
    
    // Active accordion section - open by default
    activeSections = ['ippSchedule'];
    
    // Loading state
    isLoading = false;
    
    // Error state
    hasError = false;
    
    // Updated time for CustomTablePaging
    updatedTime;
    
    // Page size for CustomTablePaging
    pageSize = 12;
    
    columns = [
        { label: 'IPP Payment No.', fieldName: 'FEC_IPP_Payment_No__c', type: 'number', typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 0 } },
        { 
            label: 'IPP Opening Balance', 
            fieldName: 'FEC_IPP_Opening_Balance__c', 
            type: 'currency',
            typeAttributes: { currencyCode: 'VND', minimumFractionDigits: 0, maximumFractionDigits: 0 },
            cellAttributes: { 
                class: { fieldName: 'FEC_IPP_Opening_Balance__cClass' },
                alignment: 'left'
            }
        },
        { 
            label: 'IPP Payment Amount', 
            fieldName: 'FEC_IPP_Payment_Amount__c', 
            type: 'currency',
            typeAttributes: { currencyCode: 'VND', minimumFractionDigits: 0, maximumFractionDigits: 0 },
            cellAttributes: { 
                class: { fieldName: 'FEC_IPP_Payment_Amount__cClass' },
                alignment: 'left'
            }
        },
        { 
            label: 'IPP Monthly Principal', 
            fieldName: 'FEC_IPP_Monthly_Principal__c', 
            type: 'currency',
            typeAttributes: { currencyCode: 'VND', minimumFractionDigits: 0, maximumFractionDigits: 0 },
            cellAttributes: { 
                class: { fieldName: 'FEC_IPP_Monthly_Principal__cClass' },
                alignment: 'left'
            }
        },
        { 
            label: 'IPP Monthly Interest', 
            fieldName: 'FEC_IPP_Monthly_Interest__c', 
            type: 'currency',
            typeAttributes: { currencyCode: 'VND', minimumFractionDigits: 0, maximumFractionDigits: 0 },
            cellAttributes: { 
                class: { fieldName: 'FEC_IPP_Monthly_Interest__cClass' },
                alignment: 'left'
            }
        }
    ];
    
    // ==========================================
    // LIFECYCLE HOOKS
    // ==========================================
    connectedCallback() {
        this.subscribeToMessageChannel();
        this.loadIPPScheduleData();
    }
    
    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }
    
    // ==========================================
    // MESSAGE CHANNEL SUBSCRIPTION
    // ==========================================
    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                FEC_IPP_NAVIGATION,
                (message) => this.handleMessage(message)
            );
        }
    }
    
    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }
    
    /**
     * Handle message từ IPP Details khi click vào IPP Plan hyperlink
     */
    handleMessage(message) {
        // Message handling nếu cần trong tương lai
    }
    
    // ==========================================
    // LOAD DATA (imperative – query DB, gọi API nếu trống rồi hiển thị)
    // ==========================================
    loadIPPScheduleData() {
        if (!this.recordId) {
            return;
        }
        this.isLoading = true;
        this.hasError = false;
        getIPPScheduleData({ ippId: this.recordId })
            .then((data) => {
                this.handleIPPScheduleResult(data);
            })
            .catch((error) => {
                this.handleIPPScheduleError(error);
            });
    }

    handleIPPScheduleResult(data) {
        console.log('IPP Schedule Data Received:', {
            scheduleCount: data?.schedules?.length || 0,
            totalPaymentAmount: data?.totalPaymentAmount,
            totalMonthlyPrincipal: data?.totalMonthlyPrincipal,
            totalMonthlyInterest: data?.totalMonthlyInterest
        });
        this.scheduleData = data?.schedules || [];
        this.totalPaymentAmount = data?.totalPaymentAmount ?? 0;
        this.totalMonthlyPrincipal = data?.totalMonthlyPrincipal ?? 0;
        this.totalMonthlyInterest = data?.totalMonthlyInterest ?? 0;
        this.formatScheduleData();
        this.updatedTime = new Date().getTime();
        this.hasError = false;
        this.isLoading = false;
    }

    handleIPPScheduleError(error) {
        console.error('Error loading IPP Schedule:', error);
        this.scheduleData = [];
        this.formattedScheduleData = [];
        this.totalPaymentAmount = 0;
        this.totalMonthlyPrincipal = 0;
        this.totalMonthlyInterest = 0;
        this.hasError = true;
        this.isLoading = false;
    }
    
    /**
     * Format schedule data: highlight negative currency values
     * Giữ original number values để CustomTablePaging sort đúng và format currency
     */
    formatScheduleData() {
        if (!this.scheduleData || this.scheduleData.length === 0) {
            console.log('No schedule data to format');
            this.formattedScheduleData = [];
            return;
        }
        
        console.log('Formatting ' + this.scheduleData.length + ' schedule records');
        console.log('Raw schedule data sample:', this.scheduleData[0]);
        
        // Sử dụng autoHighlightNegativeCurrencyForRecords để tự động highlight negative values
        this.formattedScheduleData = autoHighlightNegativeCurrencyForRecords(this.scheduleData, [
            'Id', 'Name', 'CreatedDate', 'FEC_IPP_Payment_No__c'
        ]);
        
        // Đảm bảo mỗi record có Id (CustomTablePaging cần Id)
        this.formattedScheduleData = this.formattedScheduleData.map((rec, index) => {
            if (!rec.Id && !rec.id) {
                rec.Id = rec.Id || rec.id || `schedule-${index}`;
            }
            return rec;
        });
        
        console.log('Formatted Schedule Data:', {
            count: this.formattedScheduleData.length,
            firstRecord: this.formattedScheduleData[0],
            firstRecordKeys: Object.keys(this.formattedScheduleData[0] || {}),
            columns: this.columns.map(col => col.fieldName)
        });
        
        // Validate: Kiểm tra xem có đủ các trường cần thiết không
        if (this.formattedScheduleData.length > 0) {
            const firstRec = this.formattedScheduleData[0];
            const requiredFields = ['FEC_IPP_Payment_No__c', 'FEC_IPP_Opening_Balance__c', 
                                   'FEC_IPP_Payment_Amount__c', 'FEC_IPP_Monthly_Principal__c', 
                                   'FEC_IPP_Monthly_Interest__c'];
            const missingFields = requiredFields.filter(field => firstRec[field] === undefined);
            if (missingFields.length > 0) {
                console.warn('⚠️ Missing fields in formatted data:', missingFields);
            }
        }
    }
    
    @api
    refreshData() {
        this.loadIPPScheduleData();
    }
    
    // Formatted currency values for summary (với 0 decimal places)
    get formattedTotalPaymentAmount() {
        return 'VND ' + formatCurrency(this.totalPaymentAmount, 0);
    }
    
    get isTotalPaymentAmountNegative() {
        return isNegative(this.totalPaymentAmount);
    }
    
    get formattedTotalMonthlyPrincipal() {
        return 'VND ' + formatCurrency(this.totalMonthlyPrincipal, 0);
    }
    
    get isTotalMonthlyPrincipalNegative() {
        return isNegative(this.totalMonthlyPrincipal);
    }
    
    get formattedTotalMonthlyInterest() {
        return 'VND ' + formatCurrency(this.totalMonthlyInterest, 0);
    }
    
    get isTotalMonthlyInterestNegative() {
        return isNegative(this.totalMonthlyInterest);
    }
}
