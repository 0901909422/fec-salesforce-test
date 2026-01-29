import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { publish, MessageContext } from 'lightning/messageService';
import FEC_IPP_NAVIGATION from '@salesforce/messageChannel/FEC_IPP_Navigation__c';
import getIPPRecords from '@salesforce/apex/FEC_IPPController.getIPPRecords';
import { formatCurrency, isNegative, autoHighlightNegativeCurrency } from 'c/fec_currencyUtils';

// Error message constant
const ERROR_MESSAGE = 'Tải dữ liệu không thành công';

// Helper function to format date to dd/mm/yyyy
function formatDate(dateValue) {
    if (!dateValue) return '';
    
    try {
        const date = new Date(dateValue);
        if (isNaN(date.getTime())) return '';
        
        const day = String(date.getDate()).padStart(2, '0');
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const year = date.getFullYear();
        
        return `${day}/${month}/${year}`;
    } catch (e) {
        return '';
    }
}

export default class Fec_IPPDetails extends NavigationMixin(LightningElement) {
    @api recordId;
    
    // Expose ERROR_MESSAGE for template
    ERROR_MESSAGE = ERROR_MESSAGE;
    
    // Hide row number in table
    hideRowNumber = true;
    
    // Message Context for LMS
    @wire(MessageContext)
    messageContext;
    
    ippData = [];
    
    // IPP Totals calculated from API data
    totalIPPBalance = 0;
    totalIPPCurrentBalance = 0;
    
    // Active accordion section - open by default
    activeSections = ['ippDetails'];
    
    // Loading state
    isLoading = false;
    wrapText = true;
    
    // Updated time for display
    updatedTime;
    
    // Storage key for accordion state
    get storageKey() {
        return `ippDetails_accordion_${this.recordId}`;
    }
    
    // Error state - Mặc định báo lỗi cho đến khi có dữ liệu
    hasError = true;
    
    columns = [
        { label: 'IPP Record No.', fieldName: 'recordNo', type: 'text' },
        { 
            label: 'IPP Plan', 
            fieldName: 'planNumber', 
            type: 'link', 
            recordIdField: 'Id',
            hoverTitle: 'IPP Schedule & Sales Info',
            hoverFields: [
                // IPP Schedule
                { label: 'Total IPP Payment Amount', fieldName: 'totalIPPPaymentAmountFormatted' },
                { label: 'Total IPP Monthly Principal', fieldName: 'totalIPPMonthlyPrincipalFormatted' },
                { label: 'Total IPP Monthly Interest', fieldName: 'totalIPPMonthlyInterestFormatted' },
                // Sales Info
                { label: 'CC Code', fieldName: 'ccCode' },
                { label: 'CC Name', fieldName: 'ccName' },
                { label: 'DSA Code', fieldName: 'dsaCode' },
                { label: 'DSA Name', fieldName: 'dsaName' },
                { label: 'TSA Code', fieldName: 'tsaCode' },
                { label: 'TSA Name', fieldName: 'tsaName' },
                { label: 'Application ID', fieldName: 'applicationId' },
                { label: 'Origination Channel', fieldName: 'originationChannel' },
                { label: 'Disbursement Channel', fieldName: 'disbursementChannel' }
            ]
        },
        { label: 'IPP Open Date', fieldName: 'openDateFormatted', type: 'text' },
        { label: 'IPP First Due Date', fieldName: 'firstDueDateFormatted', type: 'text' },
        { label: 'IPP Mature Date', fieldName: 'matureDateFormatted', type: 'text' },
        { 
            label: 'IPP Balance', 
            fieldName: 'ippBalanceFormatted', 
            type: 'text',
            cellAttributes: { 
                class: { fieldName: 'ippBalanceClass' },
                alignment: 'right'
            }
        },
        { 
            label: 'IPP Current Balance', 
            fieldName: 'currentBalanceFormatted', 
            type: 'text',
            cellAttributes: { 
                class: { fieldName: 'currentBalanceClass' },
                alignment: 'right'
            }
        },
        { label: 'IPP Interest Rate', fieldName: 'interestRateFormatted', type: 'text' },
        { 
            label: 'IPP Term', 
            fieldName: 'ippTermFormatted', 
            type: 'text',
            cellAttributes: { 
                alignment: 'right'
            }
        },
        { 
            label: 'IPP Current Term', 
            fieldName: 'currentTermFormatted', 
            type: 'number',
            cellAttributes: { 
                alignment: 'right'
            }
        }
        
    ];
    
    // Field mapping từ Database sang UI
    // PlanNumber → IPP Plan (hyperlink to Sales Info)
    // PlanOpenDate → IPP Open Date  
    // PlanCurrentBalance → IPP Balance
    // Các trường còn lại sẽ null
    
    // Computed property for sorted field name
    get sortedBy() {
        return this.sortField;
    }
    
    // Computed property for hasData - giống Card Info
    get hasData() {
        return !this.hasError;
    }

    // Handle accordion toggle - IPP Details
    handleIPPDetailsToggle() {
        const index = this.activeSections.indexOf('ippDetails');
        if (index > -1) {
            this.activeSections = this.activeSections.filter(s => s !== 'ippDetails');
        } else {
            this.activeSections = [...this.activeSections, 'ippDetails'];
        }
        this.saveAccordionState();
    }

    // Save accordion state to localStorage
    saveAccordionState() {
        try {
            localStorage.setItem(this.storageKey, JSON.stringify(this.activeSections));
        } catch (e) {
        }
    }

    // Check if section is open
    get isIPPDetailsOpen() {
        return this.activeSections.includes('ippDetails');
    }

    // Icon name for accordion chevron
    get ippDetailsIconName() {
        return this.isIPPDetailsOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // Section class for custom accordion
    get sectionClass() {
        let classes = 'slds-accordion__section';
        if (this.isIPPDetailsOpen) {
            classes += ' slds-is-open';
        }
        return classes;
    }

    // Content class for accordion content
    get ippDetailsContentClass() {
        return this.isIPPDetailsOpen 
            ? 'slds-accordion__content' 
            : 'slds-accordion__content slds-hide';
    }

    
    connectedCallback() {
        // Khôi phục trạng thái accordion từ localStorage
        this.restoreAccordionState();
        this.loadIPPData();
    }

    
    restoreAccordionState() {
        try {
            const savedState = localStorage.getItem(this.storageKey);
            if (savedState) {
                this.activeSections = JSON.parse(savedState);
            } else {
                // Mặc định mở section ippDetails
                this.activeSections = ['ippDetails'];
            }
        } catch (e) {
            // Silent error - localStorage might not be available
            this.activeSections = ['ippDetails'];
        }
    }
    
    
    loadIPPData() {
        this.isLoading = true;
        this.hasError = true;
        
        // Query dữ liệu từ Database (FEC_IPP__c)
        getIPPRecords({ caseId: this.recordId })
            .then(records => {
                if (!records || records.length === 0) {
                    this.hasError = true;
                    this.ippData = [];
                    this.totalIPPBalance = 0;
                    this.totalIPPCurrentBalance = 0;
                    this.isLoading = false;
                    return;
                }
                // Map database records sang format datatable
                // Map các trường IPPStartDate, IPPMatureDate, IPPCurrentBalance vào đúng field UI
                this.ippData = records.map((record, index) => {
                    // IPP Record No. = số thứ tự bản ghi (1, 2, 3, ..., 36)
                    // API luôn trả về tối đa 36 bản ghi, IPP Record No. hiển thị thứ tự
                    const recordNo = index + 1;
                    
                    const ippBalance = record.FEC_IPP_Balance__c || 0;
                    // Map các trường API sang UI:
                    // FEC_IPP_First_Due_Date__c ← IPPStartDate
                    // FEC_IPP_Mature_Date__c ← IPPMatureDate
                    // FEC_IPP_Current_Balance__c ← IPPCurrentBalance
                    const firstDueDate = record.FEC_IPP_First_Due_Date__c || null;
                    const matureDate = record.FEC_IPP_Mature_Date__c || null;
                    const currentBalance = record.FEC_IPP_Current_Balance__c || 0;
                    const currentTerm = record.FEC_IPP_Current_Term__c || null;
                    const ippTerm = record.FEC_IPP_Term__c || null;
                    
                    // IPP Schedule totals
                    const totalIPPPaymentAmount = record.FEC_Total_IPP_Payment_Amount__c || 0;
                    const totalIPPMonthlyPrincipal = record.FEC_Total_IPP_Monthly_Principal__c || 0;
                    const totalIPPMonthlyInterest = record.FEC_Total_IPP_Monthly_Interest__c || 0;
                    
                    const recordData = {
                        Id: record.Id,
                        recordNo: recordNo,
                        planNumber: record.FEC_IPP_Plan__c || '',
                        openDate: record.FEC_IPP_Open_Date__c,
                        openDateFormatted: formatDate(record.FEC_IPP_Open_Date__c),
                        firstDueDate: firstDueDate, // IPPStartDate
                        firstDueDateFormatted: formatDate(firstDueDate),
                        matureDate: matureDate,     // IPPMatureDate
                        matureDateFormatted: formatDate(matureDate),
                        ippBalance: ippBalance,
                        currentBalance: currentBalance, // IPPCurrentBalance
                        interestRate: record.FEC_IPP_Interest_Rate__c || null,
                        interestRateFormatted: record.FEC_IPP_Interest_Rate__c != null ? record.FEC_IPP_Interest_Rate__c + '%' : '',
                        currentTerm: currentTerm,
                        ippTerm: ippTerm,
                        currentTermFormatted: currentTerm != null ? formatCurrency(currentTerm, 0) : '',
                        ippTermFormatted: ippTerm != null ? formatCurrency(ippTerm, 0) + ' months' : '',
                        // IPP Schedule totals for tooltip
                        totalIPPPaymentAmountFormatted: 'VND ' + formatCurrency(totalIPPPaymentAmount, 0),
                        totalIPPMonthlyPrincipalFormatted: 'VND ' + formatCurrency(totalIPPMonthlyPrincipal, 0),
                        totalIPPMonthlyInterestFormatted: 'VND ' + formatCurrency(totalIPPMonthlyInterest, 0),
                        // Sales Info for tooltip
                        ccCode: record.FEC_CC_Code__c || '-',
                        ccName: record.FEC_CC_Name__c || '-',
                        dsaCode: record.FEC_DSA_Code__c || '-',
                        dsaName: record.FEC_DSA_Name__c || '-',
                        tsaCode: record.FEC_TSA_Code__c || '-',
                        tsaName: record.FEC_TSA_Name__c || '-',
                        applicationId: record.FEC_Application_ID__c || '-',
                        originationChannel: record.FEC_Origination_Channel__c || '-',
                        disbursementChannel: record.FEC_Disbursement_Channel__c || '-'
                    };
                    // Tự động quét và highlight các giá trị tiền tệ âm
                    const processedRecord = autoHighlightNegativeCurrency(recordData, ['interestRate']);
                    const nonBreakingSpace = '\u00A0';
                    processedRecord.ippBalanceFormatted = 'VND' + nonBreakingSpace + formatCurrency(ippBalance, 0);
                    processedRecord.currentBalanceFormatted = 'VND' + nonBreakingSpace + formatCurrency(currentBalance, 0);
                    
                    // Map class 'currency-negative' sang 'slds-text-color_error' để component con support
                    processedRecord.ippBalanceClass = processedRecord.ippBalanceClass === 'currency-negative' 
                        ? 'slds-text-color_error' 
                        : (processedRecord.ippBalanceClass || '');
                    processedRecord.currentBalanceClass = processedRecord.currentBalanceClass === 'currency-negative' 
                        ? 'slds-text-color_error' 
                        : (processedRecord.currentBalanceClass || '');
                    
                    return processedRecord;
                });
                this.totalIPPBalance = this.ippData.reduce((sum, plan) => sum + (plan.ippBalance || 0), 0);
                this.totalIPPCurrentBalance = this.ippData.reduce((sum, plan) => sum + (plan.currentBalance || 0), 0);
                this.hasError = false;
                this.updatedTime = new Date();
                this.isLoading = false;
            })
            .catch(() => {
                this.hasError = true;
                this.ippData = [];
                this.totalIPPBalance = 0;
                this.totalIPPCurrentBalance = 0;
                this.isLoading = false;
            });
    }
    
    @api
    refreshData() {
        this.loadIPPData();
    }
    
    /**
     * Handle row select từ datatable (click vào IPP Plan hyperlink)
     * Navigate đến IPP Record page để xem Sales Info section
     */
    handleRowSelect(event) {
        const recordId = event.detail.recordId;
        
        if (recordId) {
            // Navigate đến IPP Record page
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'FEC_IPP__c',
                    actionName: 'view'
                }
            });
            
            // Tìm row data để publish LMS message
            const row = this.ippData.find(r => r.Id === recordId);
            if (row) {
                const payload = {
                    action: 'viewSalesInfo',
                    planNumber: row.planNumber,
                    ippRecordId: recordId,
                    recordData: JSON.stringify(row)
                };
                
                publish(this.messageContext, FEC_IPP_NAVIGATION, payload);
            }
        }
    }
    
    // Formatted currency values for summary (với 0 decimal places và prefix VND)
    get formattedTotalIPPBalance() {
        return 'VND ' + formatCurrency(this.totalIPPBalance, 0);
    }
    
    get isTotalIPPBalanceNegative() {
        return isNegative(this.totalIPPBalance);
    }
    
    get formattedTotalIPPCurrentBalance() {
        return 'VND ' + formatCurrency(this.totalIPPCurrentBalance, 0);
    }
    
    get isTotalIPPCurrentBalanceNegative() {
        return isNegative(this.totalIPPCurrentBalance);
    }
    
    // CSS class cho summary totals để highlight màu đỏ nếu âm
    get totalIPPBalanceClass() {
        const baseClass = 'slds-p-left_medium';
        return isNegative(this.totalIPPBalance) 
            ? `${baseClass} currency-negative` 
            : baseClass;
    }
    
    get totalIPPCurrentBalanceClass() {
        const baseClass = 'slds-p-left_medium';
        return isNegative(this.totalIPPCurrentBalance) 
            ? `${baseClass} currency-negative` 
            : baseClass;
    }
}