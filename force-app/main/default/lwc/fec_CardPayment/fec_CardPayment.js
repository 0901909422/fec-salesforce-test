import { LightningElement, api } from 'lwc';
import getCardPaymentRecords from '@salesforce/apex/FEC_CardPaymentController.getCardPaymentRecords';
import getCardPaymentTotals from '@salesforce/apex/FEC_CardPaymentController.getCardPaymentTotals';
import { formatCurrency, isNegative, autoHighlightNegativeCurrency } from 'c/fec_currencyUtils';
import FEC_Card_Payment_Label from '@salesforce/label/c.FEC_Card_Payment_Label';
import FEC_Full_Payment_Amount_Label from '@salesforce/label/c.FEC_Full_Payment_Amount_Label';
import FEC_Loan_Balance_Label from '@salesforce/label/c.FEC_Loan_Balance_Label';
import FEC_Full_Payment_Without_IPP_Label from '@salesforce/label/c.FEC_Full_Payment_Without_IPP_Label';
import FEC_Full_IPP_Payment_Amount_Label from '@salesforce/label/c.FEC_Full_IPP_Payment_Amount_Label';
import FEC_Total_Current_Balance_Label from '@salesforce/label/c.FEC_Total_Current_Balance_Label';
import FEC_Total_Accrued_Interest_Label from '@salesforce/label/c.FEC_Total_Accrued_Interest_Label';
import FEC_Total_Per_Diem_Label from '@salesforce/label/c.FEC_Total_Per_Diem_Label';
import FEC_Total_Close_Fee_Amount_Label from '@salesforce/label/c.FEC_Total_Close_Fee_Amount_Label';
import FEC_Total_IPP_Accrued_Interest_Label from '@salesforce/label/c.FEC_Total_IPP_Accrued_Interest_Label';
import FEC_Total_Deferred_Interest_Label from '@salesforce/label/c.FEC_Total_Deferred_Interest_Label';
import FEC_Total_Plan_Payment_Amount_Label from '@salesforce/label/c.FEC_Total_Plan_Payment_Amount_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import { formatDate } from 'c/fec_CommonUtils';


export default class Fec_CardPayment extends LightningElement {
    _recordId;
    
    // Custom labels từ CustomLabels.labels-meta.xml (Account Info)
    ERROR_MESSAGE = FEC_MSG_Error_API_Label;
    
    // Help text map from Apex
    helpTextMap = {};
    
    // Custom labels for template (khớp với customLabel.xxx trong HTML)
    customLabel = {
        cardPaymentLabel: FEC_Card_Payment_Label,
        fullPaymentAmountLabel: FEC_Full_Payment_Amount_Label,
        loanBalanceLabel: FEC_Loan_Balance_Label,
        fullPaymentWithoutIPPLabel: FEC_Full_Payment_Without_IPP_Label,
        fullIPPPaymentAmountLabel: FEC_Full_IPP_Payment_Amount_Label,
        totalCurrentBalanceLabel: FEC_Total_Current_Balance_Label,
        totalAccruedInterestLabel: FEC_Total_Accrued_Interest_Label,
        totalPerDiemLabel: FEC_Total_Per_Diem_Label,
        totalCloseFeeAmountLabel: FEC_Total_Close_Fee_Amount_Label,
        totalIPPAccruedInterestLabel: FEC_Total_IPP_Accrued_Interest_Label,
        totalDeferredInterestLabel: FEC_Total_Deferred_Interest_Label,
        totalPlanPaymentAmountLabel: FEC_Total_Plan_Payment_Amount_Label
    };
    
    // Page size for table pagination
    pageSize = 10;
    
    @api 
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        // Gọi loadTotals và loadCardPaymentData khi recordId thay đổi
        if (value) {
            this.loadTotals();
            this.loadCardPaymentData();
        }
    }
    
    // Format dữ liệu percent: chia cho 100 và thêm ký hiệu %
    // Và thêm CSS class để highlight số âm màu đỏ
    formatPercentData(records) {
        if (!records || records.length === 0) return records;

        return records.map(record => {
            const formattedRecord = { ...record };

            // Base Rate - format với 2 chữ số thập phân + %
            if (formattedRecord.FEC_Base_Rate__c != null && formattedRecord.FEC_Base_Rate__c !== undefined) {
                const value = Number(formattedRecord.FEC_Base_Rate__c);
                formattedRecord.FEC_Base_Rate_Formatted__c = value.toFixed(2) + '%';
            }

            // IPP Interest - format với 2 chữ số thập phân + %
            if (formattedRecord.FEC_IPP_Interest__c != null && formattedRecord.FEC_IPP_Interest__c !== undefined) {
                const value = Number(formattedRecord.FEC_IPP_Interest__c);
                formattedRecord.FEC_IPP_Interest_Formatted__c = value.toFixed(2) + '%';
            }

            // Close Fee - format với 2 chữ số thập phân + %
            if (formattedRecord.FEC_Close_Fee__c != null && formattedRecord.FEC_Close_Fee__c !== undefined) {
                const value = Number(formattedRecord.FEC_Close_Fee__c);
                formattedRecord.FEC_Close_Fee_Formatted__c = value.toFixed(2) + '%';
            }
            
            // Format các trường số với dấu phẩy - Number(18,0) - không có số thập phân
            const currencyFields = [
                'FEC_Current_Balance__c',
                'FEC_Close_Fee_Amount__c',
                'FEC_Plan_Payment_Amount__c',
                'FEC_Accrued_Interest__c',
                'FEC_Per_Diem__c',
                'FEC_Deferred_Interest__c',
                'FEC_IPP_Accrued_Interest__c'
            ];
            
            currencyFields.forEach(field => {
                if (formattedRecord[field] != null && formattedRecord[field] !== undefined) {
                    const value = Number(formattedRecord[field]);
                    // Thay __c bằng _Formatted__c để tạo tên field đúng
                    const formattedFieldName = field.replace('__c', '_Formatted__c');
                    formattedRecord[formattedFieldName] = formatCurrency(value, 0);
                }
            });
            
            // Format các trường date sang dd/mm/yyyy
            const dateFields = ['FEC_Open_Date__c', 'FEC_Begin_Date__c'];
            dateFields.forEach(field => {
                if (formattedRecord[field]) {
                    const formattedFieldName = field.replace('__c', '_Formatted__c');
                    formattedRecord[formattedFieldName] = formatDate(formattedRecord[field]);
                }
            });
            
            const processedRecord = autoHighlightNegativeCurrency(formattedRecord);
            
            const fieldClassMapping = {
                // Map từ tên field class được tạo bởi autoHighlightNegativeCurrency
                // autoHighlightNegativeCurrency tạo class từ field GỐC (có __c), VÍ DỤ: FEC_Current_Balance__c -> FEC_Current_Balance__cClass
                'FEC_Current_Balance__cClass': 'currentBalanceClass',
                'FEC_Accrued_Interest__cClass': 'accruedInterestClass',
                'FEC_Per_Diem__cClass': 'perDiemClass',
                'FEC_Deferred_Interest__cClass': 'deferredInterestClass',
                'FEC_IPP_Accrued_Interest__cClass': 'ippAccruedInterestClass',
                'FEC_Close_Fee_Amount__cClass': 'closeFeeAmountClass',
                'FEC_Plan_Payment_Amount__cClass': 'planPaymentAmountClass',
                'FEC_Base_Rate__cClass': 'baseRateClass',
                'FEC_IPP_Interest__cClass': 'ippInterestClass',
                'FEC_Close_Fee__cClass': 'closeFeeClass'
            };
            
            // Map các class sang tên ngắn gọn và chuyển sang slds-text-color_error
            Object.keys(fieldClassMapping).forEach(fullFieldName => {
                if (processedRecord[fullFieldName]) {
                    const className = processedRecord[fullFieldName];
                    // Map 'currency-negative' sang 'slds-text-color_error' để component con support
                    formattedRecord[fieldClassMapping[fullFieldName]] = className === 'currency-negative' 
                        ? 'slds-text-color_error' 
                        : className;
                }
            });

            return formattedRecord;
        });
    }
    
    // Load Card Payment data - sử dụng getCardPaymentRecords() (tự động query DB trước, chỉ gọi API nếu chưa có dữ liệu)
    loadCardPaymentData() {
        if (!this.recordId) return;
        
        this.isLoading = true;
        
        getCardPaymentRecords({ caseId: this.recordId })
            .then(data => {
                // Format dữ liệu percent trước khi hiển thị
                this.cardPaymentData = this.formatPercentData(data || []);
                
                // Calculate totals from card payment data
                this.calculateTotalsFromData();
                
                this.hasError = false;
                this.isLoading = false;
            })
            .catch(error => {
                this.hasError = true;
                this.cardPaymentData = [];
                this.isLoading = false;
            });
    }
    
    // Calculate totals from card payment data
    calculateTotalsFromData() {
        if (!this.cardPaymentData || this.cardPaymentData.length === 0) {
            // Reset totals if no data
            this.totalCurrentBalance = 0;
            this.totalAccruedInterest = 0;
            this.totalIPPAccruedInterest = 0;
            this.totalPerDiem = 0;
            this.totalDeferredInterest = 0;
            this.totalCloseFeeAmount = 0;
            this.totalPlanPaymentAmount = 0;
            return;
        }
        
        // Calculate sums from raw field values (not formatted ones)
        this.totalCurrentBalance = this.cardPaymentData.reduce((sum, record) => 
            sum + (Number(record.FEC_Current_Balance__c) || 0), 0);
            
        this.totalAccruedInterest = this.cardPaymentData.reduce((sum, record) => 
            sum + (Number(record.FEC_Accrued_Interest__c) || 0), 0);
            
        this.totalIPPAccruedInterest = this.cardPaymentData.reduce((sum, record) => 
            sum + (Number(record.FEC_IPP_Accrued_Interest__c) || 0), 0);
            
        this.totalPerDiem = this.cardPaymentData.reduce((sum, record) => 
            sum + (Number(record.FEC_Per_Diem__c) || 0), 0);
            
        this.totalDeferredInterest = this.cardPaymentData.reduce((sum, record) => 
            sum + (Number(record.FEC_Deferred_Interest__c) || 0), 0);
            
        this.totalCloseFeeAmount = this.cardPaymentData.reduce((sum, record) => 
            sum + (Number(record.FEC_Close_Fee_Amount__c) || 0), 0);
            
        this.totalPlanPaymentAmount = this.cardPaymentData.reduce((sum, record) => 
            sum + (Number(record.FEC_Plan_Payment_Amount__c) || 0), 0);
    }
    
    cardPaymentData = [];
    
    // Card Payment Totals from Customer History
    fullPaymentAmount = 0;
    loanBalance = 0;
    fullPaymentWithoutIPP = 0;
    fullIPPPaymentAmount = 0;
    totalCurrentBalance = 0;
    totalAccruedInterest = 0;
    totalIPPAccruedInterest = 0;
    totalPerDiem = 0;
    totalDeferredInterest = 0;
    totalCloseFeeAmount = 0;
    totalPlanPaymentAmount = 0;
    
    // Active accordion section - open by default
    activeSections = ['cardPayment'];
    
    // Loading state
    isLoading = false;

    // Restore accordion state when component mounts
    connectedCallback() {
        this.restoreAccordionState();
    }
    
    // Error state - Mặc định không báo lỗi, chỉ báo khi có lỗi thực sự
    hasError = false;
    
    // Separate error state for totals (summary section)
    hasTotalsError = false;
    
    // Loading state for totals
    isTotalsLoading = true;
    
    columns = [
        { label: 'Rec', fieldName: 'FEC_Rec__c', type: 'text', width: '44px', minWidth: '44px', cellAlign: 'center' },
        { label: 'REF Number', fieldName: 'FEC_REF_Number__c', type: 'text', width: '130px', minWidth: '120px' },
        { label: 'Current Balance', fieldName: 'FEC_Current_Balance_Formatted__c', type: 'text', cellAlign: 'right', width: '130px', minWidth: '120px', cellAttributes: { class: { fieldName: 'currentBalanceClass' } } },
        { label: 'Open Date', fieldName: 'FEC_Open_Date_Formatted__c', type: 'text', width: '100px', minWidth: '90px', cellAlign: 'center' },
        { label: 'Plan', fieldName: 'FEC_Plan__c', type: 'text', width: '70px', minWidth: '60px', cellAlign: 'center' },
        { label: 'Base Rate', fieldName: 'FEC_Base_Rate_Formatted__c', type: 'text', cellAlign: 'right', width: '95px', minWidth: '85px', cellAttributes: { class: { fieldName: 'baseRateClass' } } },
        { label: 'Begin Date', fieldName: 'FEC_Begin_Date_Formatted__c', type: 'text', width: '100px', minWidth: '90px', cellAlign: 'center' },
        { label: 'Accrued Interest', fieldName: 'FEC_Accrued_Interest_Formatted__c', type: 'text', cellAlign: 'right', width: '135px', minWidth: '120px', cellAttributes: { class: { fieldName: 'accruedInterestClass' } } },
        { label: 'Per Diem', fieldName: 'FEC_Per_Diem_Formatted__c', type: 'text', cellAlign: 'right', width: '95px', minWidth: '85px', cellAttributes: { class: { fieldName: 'perDiemClass' } } },
        { label: 'Deferred Interest', fieldName: 'FEC_Deferred_Interest_Formatted__c', type: 'text', cellAlign: 'right', width: '140px', minWidth: '125px', cellAttributes: { class: { fieldName: 'deferredInterestClass' } } },
        { label: 'IPP Interest', fieldName: 'FEC_IPP_Interest_Formatted__c', type: 'text', cellAlign: 'right', width: '110px', minWidth: '95px', cellAttributes: { class: { fieldName: 'ippInterestClass' } } },
        { label: 'IPP Accrued Interest', fieldName: 'FEC_IPP_Accrued_Interest_Formatted__c', type: 'text', cellAlign: 'right', width: '155px', minWidth: '140px', cellAttributes: { class: { fieldName: 'ippAccruedInterestClass' } } },
        { label: 'Close Fee', fieldName: 'FEC_Close_Fee_Formatted__c', type: 'text', cellAlign: 'right', width: '95px', minWidth: '85px', cellAttributes: { class: { fieldName: 'closeFeeClass' } } },
        { label: 'Close Fee Amount', fieldName: 'FEC_Close_Fee_Amount_Formatted__c', type: 'text', cellAlign: 'right', width: '135px', minWidth: '120px', cellAttributes: { class: { fieldName: 'closeFeeAmountClass' } } },
        { label: 'Plan Payment Amount', fieldName: 'FEC_Plan_Payment_Amount_Formatted__c', type: 'text', cellAlign: 'right', width: '155px', minWidth: '140px', cellAttributes: { class: { fieldName: 'planPaymentAmountClass' } } }
    ];
    
    // Computed property for hasData - giống Card Info
    get hasData() {
        return !this.hasError;
    }
    
    // Hiển thị Payment Summary
    get showPaymentSummary() {
        // TẠM THỜI: Luôn hiển thị vì đang dùng API mock
        return true;
        // return !this.hasError && !this.hasTotalsError && !this.isTotalsLoading;
    }

    // Getters for template properties
    get hideRowNumber() {
        return false;
    }

    get hideUpdatedTime() {
        return true;
    }

    // Storage key for accordion state
    get storageKey() {
        return `cardPayment_accordion_${this.recordId}`;
    }

    // Handle accordion toggle - Card Payment
    handleCardPaymentToggle() {
        const index = this.activeSections.indexOf('cardPayment');
        if (index > -1) {
            this.activeSections = this.activeSections.filter(s => s !== 'cardPayment');
        } else {
            this.activeSections = [...this.activeSections, 'cardPayment'];
        }
        this.saveAccordionState();
    }

    // Save accordion state to localStorage
    saveAccordionState() {
        try {
            localStorage.setItem(this.storageKey, JSON.stringify(this.activeSections));
        } catch (e) {
            // Silent error
        }
    }

    // Restore accordion state from localStorage
    restoreAccordionState() {
        try {
            const savedState = localStorage.getItem(this.storageKey);
            if (savedState) {
                this.activeSections = JSON.parse(savedState);
            } else {
                this.activeSections = ['cardPayment'];
            }
        } catch (e) {
            this.activeSections = ['cardPayment'];
        }
    }

    // Check if section is open
    get isCardPaymentOpen() {
        return this.activeSections.includes('cardPayment');
    }

    // Icon name for accordion chevron
    get cardPaymentIconName() {
        return this.isCardPaymentOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // Section class for custom accordion
    get sectionClass() {
        let classes = 'slds-accordion__section';
        if (this.isCardPaymentOpen) {
            classes += ' slds-is-open';
        }
        return classes;
    }

    // Content class for accordion content
    get cardPaymentContentClass() {
        return this.isCardPaymentOpen 
            ? 'slds-accordion__content' 
            : 'slds-accordion__content slds-hide';
    }

    // Imperative call để lấy totals (hỗ trợ callout)
    loadTotals() {
        if (!this.recordId) {
            return;
        }
        
        this.isTotalsLoading = true;
        this.hasTotalsError = false;
        
        getCardPaymentTotals({ caseId: this.recordId })
            .then(data => {
                this.fullPaymentAmount = data.fullPaymentAmount || 0;
                this.loanBalance = data.loanBalance || 0;
                this.fullPaymentWithoutIPP = data.fullPaymentWithoutIPP || 0;
                this.fullIPPPaymentAmount = data.fullIPPPaymentAmount || 0;
                // Note: Total fields are now calculated from card payment data, not from API
                this.helpTextMap = data.helpTexts || {};
                this.hasTotalsError = false;
                this.isTotalsLoading = false;
            })
            .catch(error => {
                this.fullPaymentAmount = 0;
                this.loanBalance = 0;
                this.fullPaymentWithoutIPP = 0;
                this.fullIPPPaymentAmount = 0;
                // Keep calculated totals from card payment data even if API fails
                this.helpTextMap = {};
                this.hasTotalsError = true;
                this.isTotalsLoading = false;
            });
    }
    
    @api
    refreshData() {
        // Refresh cả totals và card payment data
        this.loadTotals();
        this.loadCardPaymentData(); // This will also recalculate totals from data
    }
    
    // Formatted currency values for summary (với 0 decimal places)
    get formattedFullPaymentAmount() {
        return formatCurrency(this.fullPaymentAmount, 0);
    }
    
    get isFullPaymentAmountNegative() {
        return isNegative(this.fullPaymentAmount) ? 'slds-text-color_error' : '';
    }
    
    get formattedLoanBalance() {
        return formatCurrency(this.loanBalance, 0);
    }
    
    get isLoanBalanceNegative() {
        return isNegative(this.loanBalance) ? 'slds-text-color_error' : '';
    }
    
    get formattedFullPaymentWithoutIPP() {
        return formatCurrency(this.fullPaymentWithoutIPP, 0);
    }
    
    get isFullPaymentWithoutIPPNegative() {
        return isNegative(this.fullPaymentWithoutIPP) ? 'slds-text-color_error' : '';
    }
    
    get formattedFullIPPPaymentAmount() {
        return formatCurrency(this.fullIPPPaymentAmount, 0);
    }
    
    get isFullIPPPaymentAmountNegative() {
        return isNegative(this.fullIPPPaymentAmount) ? 'slds-text-color_error' : '';
    }
    
    get formattedTotalCurrentBalance() {
        return formatCurrency(this.totalCurrentBalance, 0);
    }
    
    get isTotalCurrentBalanceNegative() {
        return isNegative(this.totalCurrentBalance) ? 'slds-text-color_error' : '';
    }
    
    get formattedTotalAccruedInterest() {
        return formatCurrency(this.totalAccruedInterest, 0);
    }
    
    get isTotalAccruedInterestNegative() {
        return isNegative(this.totalAccruedInterest) ? 'slds-text-color_error' : '';
    }
    
    get formattedTotalIPPAccruedInterest() {
        return formatCurrency(this.totalIPPAccruedInterest, 0);
    }
    
    get isTotalIPPAccruedInterestNegative() {
        return isNegative(this.totalIPPAccruedInterest) ? 'slds-text-color_error' : '';
    }
    
    get formattedTotalPerDiem() {
        return formatCurrency(this.totalPerDiem, 0);
    }
    
    get isTotalPerDiemNegative() {
        return isNegative(this.totalPerDiem) ? 'slds-text-color_error' : '';
    }
    
    get formattedTotalDeferredInterest() {
        return formatCurrency(this.totalDeferredInterest, 0);
    }
    
    get isTotalDeferredInterestNegative() {
        return isNegative(this.totalDeferredInterest) ? 'slds-text-color_error' : '';
    }
    
    get formattedTotalCloseFeeAmount() {
        return formatCurrency(this.totalCloseFeeAmount, 0);
    }
    
    get isTotalCloseFeeAmountNegative() {
        return isNegative(this.totalCloseFeeAmount) ? 'slds-text-color_error' : '';
    }
    
    get formattedTotalPlanPaymentAmount() {
        return formatCurrency(this.totalPlanPaymentAmount, 0);
    }
    
    get isTotalPlanPaymentAmountNegative() {
        return isNegative(this.totalPlanPaymentAmount) ? 'slds-text-color_error' : '';
    }
}