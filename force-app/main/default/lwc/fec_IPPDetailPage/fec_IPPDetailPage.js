import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { formatCurrency, isNegative, autoHighlightNegativeCurrency } from 'c/fec_currencyUtils';
import getIPPScheduleData from '@salesforce/apex/FEC_IPPScheduleController.getIPPScheduleData';
import getIPPHelpTextMap from '@salesforce/apex/FEC_IPPController.getIPPHelpTextMap';

export default class Fec_IPPDetailPage extends NavigationMixin(LightningElement) {
    @api recordId;
    
    // Data from URL state
    planNumber;
    recordData;
    
    // Parsed data
    ippRecord;
    
    // IPP Schedule data
    ippSchedules = [];
    
    // Active accordion sections
    activeSections = ['ippSchedule', 'salesInfo'];
    
    // Loading state
    isLoading = true;
    
    // Help text map for field inline help (giống IPPDetails / Card Payment)
    helpTextMap = {};
    
    connectedCallback() {
        this.loadHelpText();
    }
    
    loadHelpText() {
        getIPPHelpTextMap()
            .then(data => {
                this.helpTextMap = data || {};
            })
            .catch(() => {
                this.helpTextMap = {};
            });
    }
    
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            this.recordId = currentPageReference.state.c__recordId;
            this.planNumber = currentPageReference.state.c__planNumber;
            
            const recordDataStr = currentPageReference.state.c__recordData;
            if (recordDataStr) {
                try {
                    this.ippRecord = JSON.parse(recordDataStr);
                    // Defer để state/recordId đã commit; tránh lần đầu wire chạy sớm mà schedule chưa load
                    // Sales Info hiển thị ngay vì lấy từ recordData (state), Schedule cần gọi getIPPScheduleData
                    setTimeout(() => {
                        if (this.recordId) {
                            this.loadIPPSchedules();
                        } else {
                            this.isLoading = false;
                        }
                    }, 0);
                } catch (e) {
                    console.error('Error parsing record data:', e);
                    this.isLoading = false;
                }
            } else {
                this.isLoading = false;
            }
        }
    }
    
    // Load IPP Schedule data (gọi getIPPScheduleData để trigger API GetCardSecInfo khi DB chưa có schedule)
    loadIPPSchedules() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        
        getIPPScheduleData({ ippId: this.recordId })
            .then(data => {
                const schedules = (data && data.schedules) ? data.schedules : [];
                if (schedules.length > 0) {
                    this.ippSchedules = schedules.map(schedule => {
                        const formattedSchedule = {
                            Id: schedule.Id,
                            paymentNo: schedule.FEC_IPP_Payment_No__c,
                            openingBalance: formatCurrency(schedule.FEC_IPP_Opening_Balance__c || 0, 0),
                            paymentAmount: formatCurrency(schedule.FEC_IPP_Payment_Amount__c || 0, 0),
                            monthlyPrincipal: formatCurrency(schedule.FEC_IPP_Monthly_Principal__c || 0, 0),
                            monthlyInterest: formatCurrency(schedule.FEC_IPP_Monthly_Interest__c || 0, 0),
                            openingBalanceRaw: schedule.FEC_IPP_Opening_Balance__c || 0,
                            paymentAmountRaw: schedule.FEC_IPP_Payment_Amount__c || 0,
                            monthlyPrincipalRaw: schedule.FEC_IPP_Monthly_Principal__c || 0,
                            monthlyInterestRaw: schedule.FEC_IPP_Monthly_Interest__c || 0
                        };
                        const processedSchedule = autoHighlightNegativeCurrency(formattedSchedule);
                        const fieldClassMapping = {
                            'openingBalanceRawClass': 'openingBalanceClass',
                            'paymentAmountRawClass': 'paymentAmountClass',
                            'monthlyPrincipalRawClass': 'monthlyPrincipalClass',
                            'monthlyInterestRawClass': 'monthlyInterestClass'
                        };
                        Object.keys(fieldClassMapping).forEach(fullFieldName => {
                            if (processedSchedule[fullFieldName]) {
                                const className = processedSchedule[fullFieldName];
                                formattedSchedule[fieldClassMapping[fullFieldName]] = className === 'currency-negative'
                                    ? 'slds-text-color_error'
                                    : className;
                            }
                        });
                        return formattedSchedule;
                    });
                } else {
                    this.ippSchedules = [];
                }
                // Cập nhật totals + Sales Info từ API/DB (getIPPScheduleData đã query DB và gọi API Sales Info nếu thiếu)
                if (this.ippRecord && data) {
                    const rec = data.ippRecord || {};
                    this.ippRecord = {
                        ...this.ippRecord,
                        totalIPPPaymentAmount: data.totalPaymentAmount,
                        totalIPPMonthlyPrincipal: data.totalMonthlyPrincipal,
                        totalIPPMonthlyInterest: data.totalMonthlyInterest,
                        applicationId: rec.FEC_Application_ID__c ?? this.ippRecord.applicationId,
                        ccCode: rec.FEC_CC_Code__c ?? this.ippRecord.ccCode,
                        ccName: rec.FEC_CC_Name__c ?? this.ippRecord.ccName,
                        dsaCode: rec.FEC_DSA_Code__c ?? this.ippRecord.dsaCode,
                        dsaName: rec.FEC_DSA_Name__c ?? this.ippRecord.dsaName,
                        tsaCode: rec.FEC_TSA_Code__c ?? this.ippRecord.tsaCode,
                        tsaName: rec.FEC_TSA_Name__c ?? this.ippRecord.tsaName,
                        originationChannel: rec.FEC_Origination_Channel__c ?? this.ippRecord.originationChannel,
                        disbursementChannel: rec.FEC_Disbursement_Channel__c ?? this.ippRecord.disbursementChannel
                    };
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.ippSchedules = [];
                this.isLoading = false;
            });
    }
    
    get pageTitle() {
        return `IPP Details - ${this.planNumber || ''}`;
    }
    
    get hasData() {
        return this.ippRecord != null;
    }
    
    // Sales Info field getters
    get applicationId() {
        return this.ippRecord?.applicationId || '-';
    }
    
    get ccCode() {
        return this.ippRecord?.ccCode || '-';
    }
    
    get ccName() {
        return this.ippRecord?.ccName || '-';
    }
    
    get dsaCode() {
        return this.ippRecord?.dsaCode || '-';
    }
    
    get dsaName() {
        return this.ippRecord?.dsaName || '-';
    }
    
    get tsaCode() {
        return this.ippRecord?.tsaCode || '-';
    }
    
    get tsaName() {
        return this.ippRecord?.tsaName || '-';
    }
    
    get originationChannel() {
        return this.ippRecord?.originationChannel || '-';
    }
    
    get disbursementChannel() {
        return this.ippRecord?.disbursementChannel || '-';
    }

    // Sales Info fields
    get salesInfoFields() {
        if (!this.ippRecord) return [];
        return [
            { label: 'CC Code', value: this.ippRecord.ccCode || '-' },
            { label: 'CC Name', value: this.ippRecord.ccName || '-' },
            { label: 'DSA Code', value: this.ippRecord.dsaCode || '-' },
            { label: 'DSA Name', value: this.ippRecord.dsaName || '-' },
            { label: 'TSA Code', value: this.ippRecord.tsaCode || '-' },
            { label: 'TSA Name', value: this.ippRecord.tsaName || '-' },
            { label: 'Application ID', value: this.ippRecord.applicationId || '-' },
            { label: 'Origination Channel', value: this.ippRecord.originationChannel || '-' },
            { label: 'Disbursement Channel', value: this.ippRecord.disbursementChannel || '-' }
        ];
    }
    
    // IPP Schedule columns - các cột số căn phải
    get scheduleColumns() {
        return [
            { label: 'Payment No.', fieldName: 'paymentNo', type: 'text', sortable: true, cellAlign: 'center'},
            { label: 'Opening Balance', fieldName: 'openingBalance', type: 'text', sortable: true, cellAlign: 'right', cellAttributes: { class: { fieldName: 'openingBalanceClass' } }},
            { label: 'Payment Amount', fieldName: 'paymentAmount', type: 'text', sortable: true, cellAlign: 'right', cellAttributes: { class: { fieldName: 'paymentAmountClass' } }},
            { label: 'Monthly Principal', fieldName: 'monthlyPrincipal', type: 'text', sortable: true, cellAlign: 'right', cellAttributes: { class: { fieldName: 'monthlyPrincipalClass' } }},
            { label: 'Monthly Interest', fieldName: 'monthlyInterest', type: 'text', sortable: true, cellAlign: 'right', cellAttributes: { class: { fieldName: 'monthlyInterestClass' } }}
        ];
    }
    
    get hasSchedules() {
        return this.ippSchedules && this.ippSchedules.length > 0;
    }
    
    get hideRowNumber() {
        return false;
    }
    
    // Schedule Totals fields
    get scheduleTotalsFields() {
        if (!this.ippRecord) return [];
        return [
            { 
                label: 'Total IPP Payment Amount', 
                value: this.formatCurrencyValue(this.ippRecord.totalIPPPaymentAmount),
                isNegative: isNegative(this.ippRecord.totalIPPPaymentAmount)
            },
            { 
                label: 'Total IPP Monthly Principal', 
                value: this.formatCurrencyValue(this.ippRecord.totalIPPMonthlyPrincipal),
                isNegative: isNegative(this.ippRecord.totalIPPMonthlyPrincipal)
            },
            { 
                label: 'Total IPP Monthly Interest', 
                value: this.formatCurrencyValue(this.ippRecord.totalIPPMonthlyInterest),
                isNegative: isNegative(this.ippRecord.totalIPPMonthlyInterest)
            }
        ];
    }
    
    get totalPaymentAmount() {
        return this.formatCurrencyValue(this.ippRecord?.totalIPPPaymentAmount);
    }
    
    get totalPaymentAmountNegative() {
        return isNegative(this.ippRecord?.totalIPPPaymentAmount) ? 'slds-text-color_error' : '';
    }
    
    get totalMonthlyPrincipal() {
        return this.formatCurrencyValue(this.ippRecord?.totalIPPMonthlyPrincipal);
    }
    
    get totalMonthlyPrincipalNegative() {
        return isNegative(this.ippRecord?.totalIPPMonthlyPrincipal) ? 'slds-text-color_error' : '';
    }
    
    get totalMonthlyInterest() {
        return this.formatCurrencyValue(this.ippRecord?.totalIPPMonthlyInterest);
    }
    
    get totalMonthlyInterestNegative() {
        return isNegative(this.ippRecord?.totalIPPMonthlyInterest) ? 'slds-text-color_error' : '';
    }
    
    formatCurrencyValue(value) {
        if (value == null) return '-';
        return formatCurrency(value, 0);
    }
    
    handleBack() {
        // Navigate back to previous page
        window.history.back();
    }
    
    handleViewRecord() {
        // Navigate to standard IPP record page
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'FEC_IPP__c',
                actionName: 'view'
            }
        });
    }
    
    // Accordion toggle handlers
    handleIPPScheduleToggle() {
        const index = this.activeSections.indexOf('ippSchedule');
        if (index > -1) {
            this.activeSections = this.activeSections.filter(s => s !== 'ippSchedule');
        } else {
            this.activeSections = [...this.activeSections, 'ippSchedule'];
        }
    }
    
    handleSalesInfoToggle() {
        const index = this.activeSections.indexOf('salesInfo');
        if (index > -1) {
            this.activeSections = this.activeSections.filter(s => s !== 'salesInfo');
        } else {
            this.activeSections = [...this.activeSections, 'salesInfo'];
        }
    }
    
    // Section state getters
    get isIPPScheduleOpen() {
        return this.activeSections.includes('ippSchedule');
    }
    
    get isSalesInfoOpen() {
        return this.activeSections.includes('salesInfo');
    }
    
    get ippScheduleIconName() {
        return this.isIPPScheduleOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    
    get salesInfoIconName() {
        return this.isSalesInfoOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }
    
    get ippScheduleSectionClass() {
        return this.isIPPScheduleOpen ? 'slds-accordion__section slds-is-open' : 'slds-accordion__section';
    }
    
    get salesInfoSectionClass() {
        return this.isSalesInfoOpen ? 'slds-accordion__section slds-is-open' : 'slds-accordion__section';
    }
    
    get ippScheduleContentClass() {
        return this.isIPPScheduleOpen ? 'slds-accordion__content' : 'slds-accordion__content slds-hide';
    }
    
    get salesInfoContentClass() {
        return this.isSalesInfoOpen ? 'slds-accordion__content' : 'slds-accordion__content slds-hide';
    }
}
