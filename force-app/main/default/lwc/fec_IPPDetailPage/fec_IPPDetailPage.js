import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { formatCurrency, isNegative, autoHighlightNegativeCurrency } from 'c/fec_currencyUtils';
import refreshIPPScheduleData from '@salesforce/apex/FEC_IPPScheduleController.refreshIPPScheduleData';
import getIPPHelpTextMap from '@salesforce/apex/FEC_IPPController.getIPPHelpTextMap';
import { setConsoleTab } from 'c/fec_CommonUtils';
import IPP_DETAILS_LABEL from '@salesforce/label/c.FEC_IPP_Details_Label';
import IPP_SCHEDULE_LABEL from '@salesforce/label/c.FEC_IPP_Schedule_Label';
import SALES_INFO_LABEL from '@salesforce/label/c.FEC_Sales_Info_Label';
import TOTAL_IPP_PAYMENT_AMOUNT_LABEL from '@salesforce/label/c.FEC_Total_IPP_Payment_Amount_Label';
import TOTAL_IPP_MONTHLY_PRINCIPAL_LABEL from '@salesforce/label/c.FEC_Total_IPP_Monthly_Principal_Label';
import TOTAL_IPP_MONTHLY_INTEREST_LABEL from '@salesforce/label/c.FEC_Total_IPP_Monthly_Interest_Label';
import CC_CODE_LABEL from '@salesforce/label/c.FEC_CC_Code_Label';
import CC_NAME_LABEL from '@salesforce/label/c.FEC_CC_Name_Label';
import DSA_CODE_LABEL from '@salesforce/label/c.FEC_DSA_Code_Label';
import DSA_NAME_LABEL from '@salesforce/label/c.FEC_DSA_Name_Label';
import TSA_CODE_LABEL from '@salesforce/label/c.FEC_TSA_Code_Label';
import TSA_NAME_LABEL from '@salesforce/label/c.FEC_TSA_Name_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Common_No_Results_Label from '@salesforce/label/c.FEC_Common_No_Results_Label';

import FEC_IPP_Label from '@salesforce/label/c.FEC_IPP_Label';
import FEC_Details_Label from '@salesforce/label/c.FEC_Details_Label';

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

    // Error states for section-level API failure display
    hasIPPScheduleError = false;
    hasSalesInfoError = false;
    
    // Help text map for field inline help (giống IPPDetails / Card Payment)
    helpTextMap = {};

    // Custom labels từ CustomLabels.labels-meta.xml (Account Info)
    ERROR_MESSAGE = FEC_MSG_Error_API_Label;
    
    connectedCallback() {
        this.loadHelpText();
    }

    /** Nhãn tab Console — gọi sau khi navigate/state sẵn sàng, không gọi trong connectedCallback. */
    updateServiceConsoleTab() {
        setConsoleTab('IPP Plan', 'standard:record');
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
    
    get customLabel() {
        return {
            ippLabel: FEC_IPP_Label,
            ippDetailLabel: IPP_DETAILS_LABEL,
            detailsLabel: FEC_Details_Label,
            ippScheduleLabel: IPP_SCHEDULE_LABEL,
            salesInfoLabel: SALES_INFO_LABEL,
            totalIPPPaymentAmountLabel: TOTAL_IPP_PAYMENT_AMOUNT_LABEL,
            totalIPPMonthlyPrincipalLabel: TOTAL_IPP_MONTHLY_PRINCIPAL_LABEL,
            totalIPPMonthlyInterestLabel: TOTAL_IPP_MONTHLY_INTEREST_LABEL,
            ccCodeLabel: CC_CODE_LABEL,
            ccNameLabel: CC_NAME_LABEL,
            dsaCodeLabel: DSA_CODE_LABEL,
            dsaNameLabel: DSA_NAME_LABEL,
            tsaCodeLabel: TSA_CODE_LABEL,
            tsaNameLabel: TSA_NAME_LABEL,
            noIPPScheduleDataLabel: FEC_Common_No_Results_Label,
            noDataToDisplayLabel: FEC_Common_No_Results_Label
        };
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
                    // Mỗi lần load trang đều gọi API IPP Schedule (refreshIPPScheduleData)
                    if (this.recordId) {
                        this.loadIPPSchedules();
                    } else {
                        this.isLoading = false;
                        this.updateServiceConsoleTab();
                    }
                } catch (e) {
                    this.isLoading = false;
                    this.updateServiceConsoleTab();
                }
            } else {
                this.isLoading = false;
                this.updateServiceConsoleTab();
            }
        }
    }

    // Sync từ API rồi load: gọi refreshIPPScheduleData để IPP Schedule có dữ liệu
    loadIPPSchedules() {
        if (!this.recordId) {
            this.isLoading = false;
            this.updateServiceConsoleTab();
            return;
        }
        this.hasIPPScheduleError = false;
        this.hasSalesInfoError = false;
        refreshIPPScheduleData({ ippId: this.recordId })
            .then(data => {
                console.log('[IPPDetailPage] refreshIPPScheduleData response:', {
                    hasData: !!data,
                    schedulesLength: data?.schedules?.length ?? 0,
                    totalPaymentAmount: data?.totalPaymentAmount,
                    totalMonthlyPrincipal: data?.totalMonthlyPrincipal,
                    totalMonthlyInterest: data?.totalMonthlyInterest,
                    hasIppRecord: !!data?.ippRecord,
                    rawDataKeys: data ? Object.keys(data) : []
                });
                if ((data?.schedules?.length ?? 0) === 0 && data?.emptyScheduleReason) {
                    console.warn('[IPPDetailPage] Lý do schedule rỗng (từ Apex):', data.emptyScheduleReason);
                }
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
                    console.log('[IPPDetailPage] schedules rỗng, data.schedules=', data?.schedules);
                    if (data?.emptyScheduleReason) {
                        console.warn('[IPPDetailPage] emptyScheduleReason=', data.emptyScheduleReason, '— NO_ACCOUNT_NUMBER: Customer History thiếu số TK; API_RETURNED_NO_IPPS: API không trả IPP; FILTER_EMPTY: không khớp Plan/RecordNo; API_ERROR: lỗi gọi API.');
                    }
                    this.ippSchedules = [];
                }
                // Totals + Sales Info sau khi Apex đồng bộ API → DB (refreshIPPScheduleData = getIPPScheduleData + skip Sales populate)
                if (this.ippRecord && data) {
                    const rec = data.ippRecord || {};
                    this.ippRecord = {
                        ...this.ippRecord,
                        totalIPPPaymentAmount: data.totalPaymentAmount,
                        totalIPPMonthlyPrincipal: data.totalMonthlyPrincipal,
                        totalIPPMonthlyInterest: data.totalMonthlyInterest,
                        ccCode: rec.FEC_CC_Code__c ?? this.ippRecord.ccCode,
                        ccName: rec.FEC_CC_Name__c ?? this.ippRecord.ccName,
                        dsaCode: rec.FEC_DSA_Code__c ?? this.ippRecord.dsaCode,
                        dsaName: rec.FEC_DSA_Name__c ?? this.ippRecord.dsaName,
                        tsaCode: rec.FEC_TSA_Code__c ?? this.ippRecord.tsaCode,
                        tsaName: rec.FEC_TSA_Name__c ?? this.ippRecord.tsaName
                    };
                }
                this.hasIPPScheduleError = false;
                this.hasSalesInfoError = false;
                this.updateServiceConsoleTab();
                this.isLoading = false;
            })
            .catch(() => {
                this.ippSchedules = [];
                this.hasIPPScheduleError = true;
                this.hasSalesInfoError = true;
                this.isLoading = false;
                this.updateServiceConsoleTab();
            });
    }
    
    get pageTitle() {
        return `IPP Details - ${this.planNumber || ''}`;
    }
    
    get hasData() {
        return this.ippRecord != null;
    }
    
    // Sales Info field getters
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

    // Sales Info fields
    get salesInfoFields() {
        if (!this.ippRecord) return [];
        return [
            { label: 'CC Code', value: this.ippRecord.ccCode || '-' },
            { label: 'CC Name', value: this.ippRecord.ccName || '-' },
            { label: 'DSA Code', value: this.ippRecord.dsaCode || '-' },
            { label: 'DSA Name', value: this.ippRecord.dsaName || '-' },
            { label: 'TSA Code', value: this.ippRecord.tsaCode || '-' },
            { label: 'TSA Name', value: this.ippRecord.tsaName || '-' }
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

    get hasSalesInfoData() {
        if (!this.ippRecord || !this.hasSchedules) {
            return false;
        }

        const salesValues = [
            this.ippRecord.ccCode,
            this.ippRecord.ccName,
            this.ippRecord.dsaCode,
            this.ippRecord.dsaName,
            this.ippRecord.tsaCode,
            this.ippRecord.tsaName
        ];

        return salesValues.some(value => value !== null && value !== undefined && String(value).trim() !== '');
    }

    get schedulePageSize() {
        return 10;
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
    
    /** Totals do controller (FEC_IPPScheduleController.buildResult) tính và trả về; component chỉ hiển thị */
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