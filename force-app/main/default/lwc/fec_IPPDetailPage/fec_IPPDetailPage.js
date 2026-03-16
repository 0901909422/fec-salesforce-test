import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { formatCurrency, isNegative, autoHighlightNegativeCurrency } from 'c/fec_currencyUtils';
import getIPPScheduleData from '@salesforce/apex/FEC_IPPScheduleController.getIPPScheduleData';
import getIPPHelpTextMap from '@salesforce/apex/FEC_IPPController.getIPPHelpTextMap';
import { setConsoleTab } from 'c/fec_CommonUtils';
import IPP_DETAILS_LABEL from '@salesforce/label/c.FEC_IPP_Details_Label';
import IPP_SCHEDULE_LABEL from '@salesforce/label/c.FEC_IPP_Schedule_Label';
import SALES_INFO_LABEL from '@salesforce/label/c.FEC_Sales_Info_Label';
import TOTAL_IPP_PAYMENT_AMOUNT_LABEL from '@salesforce/label/c.FEC_Total_IPP_Payment_Amount_Label';
import TOTAL_IPP_MONTHLY_PRINCIPAL_LABEL from '@salesforce/label/c.FEC_Total_IPP_Monthly_Principal_Label';
import TOTAL_IPP_MONTHLY_INTEREST_LABEL from '@salesforce/label/c.FEC_Total_IPP_Monthly_Interest_Label';
import APPLICATION_ID_LABEL from '@salesforce/label/c.FEC_Application_ID_Label';
import CC_CODE_LABEL from '@salesforce/label/c.FEC_CC_Code_Label';
import CC_NAME_LABEL from '@salesforce/label/c.FEC_CC_Name_Label';
import DSA_CODE_LABEL from '@salesforce/label/c.FEC_DSA_Code_Label';
import DSA_NAME_LABEL from '@salesforce/label/c.FEC_DSA_Name_Label';
import TSA_CODE_LABEL from '@salesforce/label/c.FEC_TSA_Code_Label';
import TSA_NAME_LABEL from '@salesforce/label/c.FEC_TSA_Name_Label';
import ORIGINATION_CHANNEL_LABEL from '@salesforce/label/c.FEC_Origination_Channel_Label';
import DISBURSEMENT_CHANNEL_LABEL from '@salesforce/label/c.FEC_Disbursement_Channel_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import NO_IPP_SCHEDULE_DATA_LABEL from '@salesforce/label/c.FEC_MSG_No_IPP_Schedule_Data';
import NO_DATA_TO_DISPLAY_LABEL from '@salesforce/label/c.FEC_MSG_No_Data_To_Display';
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
    
    // Help text map for field inline help (giống IPPDetails / Card Payment)
    helpTextMap = {};

    // Custom labels từ CustomLabels.labels-meta.xml (Account Info)
    ERROR_MESSAGE = FEC_MSG_Error_API_Label;
    
    // Flag để đảm bảo chỉ load schedule 1 lần
    _scheduleLoaded = false;
    
    // Retry counter cho việc load schedules
    _scheduleRetryCount = 0;
    _maxRetries = 1; // Retry tối đa 1 lần

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
    
    get isMockRecord() {
        return this.recordId && String(this.recordId).startsWith('mock-');
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
            applicationIdLabel: APPLICATION_ID_LABEL,
            ccCodeLabel: CC_CODE_LABEL,
            ccNameLabel: CC_NAME_LABEL,
            dsaCodeLabel: DSA_CODE_LABEL,
            dsaNameLabel: DSA_NAME_LABEL,
            tsaCodeLabel: TSA_CODE_LABEL,
            tsaNameLabel: TSA_NAME_LABEL,
            originationChannelLabel: ORIGINATION_CHANNEL_LABEL,
            disbursementChannelLabel: DISBURSEMENT_CHANNEL_LABEL,
            noIPPScheduleDataLabel: NO_IPP_SCHEDULE_DATA_LABEL,
            noDataToDisplayLabel: NO_DATA_TO_DISPLAY_LABEL
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
                    // Load IPP Schedule ngay khi có đủ recordId và chưa load
                    // Sales Info hiển thị ngay vì lấy từ recordData (state), Schedule cần gọi getIPPScheduleData
                    if (this.recordId && !this._scheduleLoaded) {
                        this._scheduleLoaded = true;
                        if (this.recordId && String(this.recordId).startsWith('mock-')) {
                            this.loadMockIPPData();
                        } else {
                            this.loadIPPSchedules();
                        }
                    } else if (!this.recordId) {
                        this.isLoading = false;
                    }
                } catch (e) {
                    this.isLoading = false;
                }
            } else {
                this.isLoading = false;
            }
        }
    }

    /** Mock record: lấy IPP Schedule từ Apex (FEC_MockData.getHardcodedIPPScheduleDataForUI). */
    loadMockIPPData() {
        this.loadIPPSchedules();
    }
    
    // Load IPP Schedule data (gọi getIPPScheduleData để trigger API GetCardSecInfo khi DB chưa có schedule)
    loadIPPSchedules() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        

        getIPPScheduleData({ ippId: this.recordId })
            .then(data => {

                setConsoleTab('IPP Detail', 'standard:record');
                const schedules = (data && data.schedules) ? data.schedules : [];
                
                // Nếu không có schedules và chưa retry, đợi 1s rồi retry (API đã insert nhưng query chưa kịp thấy)
                if (schedules.length === 0 && this._scheduleRetryCount < this._maxRetries) {
                    this._scheduleRetryCount++;
                    setTimeout(() => {
                        this.retryLoadSchedules();
                    }, 1000);
                    return; // Không set isLoading = false, giữ spinner
                }
                
                if (schedules.length === 0) {
                }
                
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
    
    // Retry loading schedules - gọi lại API để query DB sau khi API đã insert xong
    retryLoadSchedules() {
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
                
                // Cập nhật totals + Sales Info
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