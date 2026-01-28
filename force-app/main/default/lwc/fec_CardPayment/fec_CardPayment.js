import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCardPaymentRecords from '@salesforce/apex/FEC_CardPaymentController.getCardPaymentRecords';
import getCardPaymentTotals from '@salesforce/apex/FEC_CardPaymentController.getCardPaymentTotals';
import { formatCurrency, isNegative, autoHighlightNegativeCurrency } from 'c/fec_currencyUtils';

// Error message constant
const ERROR_MESSAGE = 'Tải dữ liệu không thành công';

export default class Fec_CardPayment extends NavigationMixin(LightningElement) {
    _recordId;
    
    // Expose ERROR_MESSAGE for template
    ERROR_MESSAGE = ERROR_MESSAGE;
    
    // Hide row number in table
    hideRowNumber = true;
    
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
            
            // Format các trường số với dấu phẩy
            // Number(18,0) - không có số thập phân
            const integerFields = [
                'FEC_Current_Balance__c',
                'FEC_Close_Fee_Amount__c',
                'FEC_Plan_Payment_Amount__c'
            ];
            
            integerFields.forEach(field => {
                if (formattedRecord[field] != null && formattedRecord[field] !== undefined) {
                    const value = Number(formattedRecord[field]);
                    // Thay __c bằng _Formatted__c để tạo tên field đúng
                    const formattedFieldName = field.replace('__c', '_Formatted__c');
                    formattedRecord[formattedFieldName] = formatCurrency(value, 0);
                }
            });
            
            // Number(18,2) - có 2 chữ số thập phân
            const decimalFields = [
                'FEC_Accrued_Interest__c',
                'FEC_Per_Diem__c',
                'FEC_Deferred_Interest__c',
                'FEC_IPP_Accrued_Interest__c'
            ];
            
            decimalFields.forEach(field => {
                // Thay __c bằng _Formatted__c để tạo tên field đúng
                const formattedFieldName = field.replace('__c', '_Formatted__c');
                if (formattedRecord[field] != null && formattedRecord[field] !== undefined) {
                    const value = Number(formattedRecord[field]);
                    formattedRecord[formattedFieldName] = formatCurrency(value, 2);
                } else {
                    // Nếu null/undefined, hiển thị 0.00
                    formattedRecord[formattedFieldName] = '0.00';
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
                this.hasError = false;
                this.updatedTime = new Date();
                this.isLoading = false;
            })
            .catch(error => {
                this.hasError = true;
                this.cardPaymentData = [];
                this.isLoading = false;
            });
    }
    
    cardPaymentData = [];
    
    // Card Payment Totals from Customer History
    fullPaymentAmount = 0;
    loanBalance = 0;
    fullPaymentWithoutIPP = 0;
    fullIPPPaymentAmount = 0;
    
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
    
    // Updated time for display
    updatedTime;
    
    columns = [
        { label: 'Rec', fieldName: 'FEC_Rec__c' },
        { label: 'REF Number', fieldName: 'FEC_REF_Number__c' },
        { label: 'Current Balance', fieldName: 'FEC_Current_Balance_Formatted__c', type: 'text', cellAttributes: { class: { fieldName: 'currentBalanceClass' }, alignment: 'right' } },
        { label: 'Open Date', fieldName: 'FEC_Open_Date__c', type: 'date' },
        { label: 'Plan', fieldName: 'FEC_Plan__c' },
        { label: 'Base Rate', fieldName: 'FEC_Base_Rate_Formatted__c', cellAttributes: { class: { fieldName: 'baseRateClass' } } },
        { label: 'Begin Date', fieldName: 'FEC_Begin_Date__c', type: 'date' },
        { label: 'Accrued Interest', fieldName: 'FEC_Accrued_Interest_Formatted__c', type: 'text', cellAttributes: { class: { fieldName: 'accruedInterestClass' }, alignment: 'right' } },
        { label: 'Per Diem', fieldName: 'FEC_Per_Diem_Formatted__c', type: 'text', cellAttributes: { class: { fieldName: 'perDiemClass' }, alignment: 'right' } },
        { label: 'Deferred Interest', fieldName: 'FEC_Deferred_Interest_Formatted__c', type: 'text', cellAttributes: { class: { fieldName: 'deferredInterestClass' }, alignment: 'right' } },
        { label: 'IPP\u00A0Interest', fieldName: 'FEC_IPP_Interest_Formatted__c', cellAttributes: { class: { fieldName: 'ippInterestClass' } } },
        { label: 'IPP Accrued Interest', fieldName: 'FEC_IPP_Accrued_Interest_Formatted__c', type: 'text', cellAttributes: { class: { fieldName: 'ippAccruedInterestClass' }, alignment: 'right' } },
        { label: 'Close Fee', fieldName: 'FEC_Close_Fee_Formatted__c', cellAttributes: { class: { fieldName: 'closeFeeClass' } } },
        { label: 'Close Fee Amount', fieldName: 'FEC_Close_Fee_Amount_Formatted__c', type: 'text', cellAttributes: { class: { fieldName: 'closeFeeAmountClass' }, alignment: 'right' } },
        { label: 'Plan Payment Amount', fieldName: 'FEC_Plan_Payment_Amount_Formatted__c', type: 'text', cellAttributes: { class: { fieldName: 'planPaymentAmountClass' }, alignment: 'right' } }
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
                this.hasTotalsError = false;
                this.isTotalsLoading = false;
            })
            .catch(error => {
                this.fullPaymentAmount = 0;
                this.loanBalance = 0;
                this.fullPaymentWithoutIPP = 0;
                this.fullIPPPaymentAmount = 0;
                this.hasTotalsError = true;
                this.isTotalsLoading = false;
            });
    }
    
    @api
    refreshData() {
        // Refresh cả totals và card payment data
        this.loadTotals();
        this.loadCardPaymentData();
    }
    
    // Formatted currency values for summary (với 0 decimal places)
    get formattedFullPaymentAmount() {
        return formatCurrency(this.fullPaymentAmount, 0);
    }
    
    get isFullPaymentAmountNegative() {
        return isNegative(this.fullPaymentAmount) ? 'currency-negative' : '';
    }
    
    get formattedLoanBalance() {
        return formatCurrency(this.loanBalance, 0);
    }
    
    get isLoanBalanceNegative() {
        return isNegative(this.loanBalance) ? 'currency-negative' : '';
    }
    
    get formattedFullPaymentWithoutIPP() {
        return formatCurrency(this.fullPaymentWithoutIPP, 0);
    }
    
    get isFullPaymentWithoutIPPNegative() {
        return isNegative(this.fullPaymentWithoutIPP) ? 'currency-negative' : '';
    }
    
    get formattedFullIPPPaymentAmount() {
        return formatCurrency(this.fullIPPPaymentAmount, 0);
    }
    
    get isFullIPPPaymentAmountNegative() {
        return isNegative(this.fullIPPPaymentAmount) ? 'currency-negative' : '';
    }
}