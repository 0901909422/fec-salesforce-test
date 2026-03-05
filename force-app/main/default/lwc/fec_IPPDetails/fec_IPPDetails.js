import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { publish, MessageContext } from 'lightning/messageService';
import FEC_IPP_NAVIGATION from '@salesforce/messageChannel/FEC_IPP_Navigation__c';
import getIPPRecords from '@salesforce/apex/FEC_IPPController.getIPPRecords';
import getIPPHelpTextMap from '@salesforce/apex/FEC_IPPController.getIPPHelpTextMap';
import { formatCurrency, isNegative, autoHighlightNegativeCurrency } from 'c/fec_currencyUtils';
import FEC_IPP_Details_Label from '@salesforce/label/c.FEC_IPP_Details_Label';
import FEC_Total_IPP_Balance_Label from '@salesforce/label/c.FEC_Total_IPP_Balance_Label';
import FEC_Total_IPP_Current_Balance_Label from '@salesforce/label/c.FEC_Total_IPP_Current_Balance_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import { formatDate } from 'c/fec_CommonUtils';

export default class Fec_IPPDetails extends NavigationMixin(LightningElement) {
    @api recordId;
    
    // Custom labels từ CustomLabels.labels-meta.xml (Account Info)
    ERROR_MESSAGE = FEC_MSG_Error_API_Label;
    
    customLabel = {
        ippDetailsLabel: FEC_IPP_Details_Label,
        totalIPPBalanceLabel: FEC_Total_IPP_Balance_Label,
        totalIPPCurrentBalanceLabel: FEC_Total_IPP_Current_Balance_Label
    };
    
    // Message Context for LMS
    @wire(MessageContext)
    messageContext;
    
    ippData = [];
    
    // IPP Totals calculated from API data
    totalIPPBalance = 0;
    totalIPPCurrentBalance = 0;
    
    // Active accordion section - open by default
    activeSections = ['ippDetails'];
    
    // Loading state - mặc định true để không flash "Tải dữ liệu không thành công" khi chưa gọi API xong
    isLoading = true;
    wrapText = true;
    
    // Page size for table pagination
    pageSize = 10;
    
    // Updated time for display
    updatedTime;
    
    // Storage key for accordion state
    get storageKey() {
        return `ippDetails_accordion_${this.recordId}`;
    }
    
    // Error state - Mặc định báo lỗi cho đến khi có dữ liệu
    hasError = true;
    
    // Help text map for field inline help
    helpTextMap = {};
    
    columns = [
        { label: 'Record No.', fieldName: 'recordNo', type: 'text', cellAlign: 'center', width: '100px', minWidth: '90px' },
        { 
            label: 'Plan', 
            fieldName: 'planNumber', 
            type: 'link', 
            recordIdField: 'Id',
            width: '90px',
            minWidth: '80px',
            hoverTitle: 'Sales Info',
            hoverFields: [
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
        { label: 'Open Date', fieldName: 'openDateFormatted', type: 'text', cellAlign: 'center', width: '100px', minWidth: '90px' },
        { label: 'First Due Date', fieldName: 'firstDueDateFormatted', type: 'text', cellAlign: 'center', width: '115px', minWidth: '105px' },
        { label: 'Mature Date', fieldName: 'matureDateFormatted', type: 'text', cellAlign: 'center', width: '110px', minWidth: '100px' },
        { 
            label: 'Balance', 
            fieldName: 'ippBalanceFormatted', 
            type: 'text',
            cellAlign: 'right',
            width: '115px',
            minWidth: '100px',
            cellAttributes: { class: { fieldName: 'ippBalanceClass' } }
        },
        { 
            label: 'Current Balance', 
            fieldName: 'currentBalanceFormatted', 
            type: 'text',
            cellAlign: 'right',
            width: '140px',
            minWidth: '125px',
            cellAttributes: { class: { fieldName: 'currentBalanceClass  ' } }
        },
        { label: 'Interest Rate', fieldName: 'interestRateFormatted', type: 'text', cellAlign: 'right', width: '115px', minWidth: '100px' },
        { label: 'Term', fieldName: 'ippTermFormatted', type: 'text', cellAlign: 'center', width: '80px', minWidth: '70px' },
        { label: 'Current Term', cellAlign: 'center', fieldName: 'currentTermFormatted', type: 'text', width: '90px', minWidth: '80px' }
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
    
    // Computed property for hasData - có dữ liệu khi không lỗi hoặc có ít nhất 1 bản ghi
    get hasData() {
        return !this.hasError && this.ippData && this.ippData.length > 0;
    }

    // Chỉ hiển thị "Tải dữ liệu không thành công" khi đã load xong (không còn loading) VÀ lỗi VÀ không có dữ liệu
    // (tránh flash lỗi lúc mới load vì ban đầu hasError=true, isLoading=false)
    get showErrorInHeader() {
        return !this.isLoading && this.hasError && (!this.ippData || this.ippData.length === 0);
    }

    // Hiển thị khối lỗi (no-data error) chỉ khi đã load xong VÀ lỗi VÀ không có dữ liệu
    get showErrorDiv() {
        return !this.isLoading && this.hasError && (!this.ippData || this.ippData.length === 0);
    }

    // Hiển thị bảng khi có dữ liệu HOẶC khi không lỗi (tránh ẩn bảng khi đã load được data)
    get showTable() {
        return (this.ippData && this.ippData.length > 0) || !this.hasError;
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
        this.loadHelpText();
        this.loadIPPData();
    }

    
    loadHelpText() {
        getIPPHelpTextMap()
            .then(data => {
                this.helpTextMap = data || {};
            })
            .catch(error => {
                console.error('Error loading help text:', error);
                this.helpTextMap = {};
            });
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
                
                try {
                    // Map records sang format datatable (hỗ trợ cả API DTO camelCase, Apex serialization và DB FEC_IPP__c)
                    // getValue thử lần lượt các key vì Apex có thể serialize tên thuộc tính khác (vd: IppBalance)
                    const getValue = (r, ...keys) => {
                        for (const k of keys) {
                            if (r == null || k == null) continue;
                            const v = r[k];
                            if (v !== undefined && v !== null) return v;
                            if (v === 0 || v === false) return v; // số 0 và boolean false là giá trị hợp lệ
                        }
                        return undefined;
                    };
                    const get = (r, apiKey, dbKey) => getValue(r, apiKey, dbKey);
                    const nonBreakingSpace = '\u00A0';

                    this.ippData = records.map((record) => {
                        const recordNo = (getValue(record, 'recordNo', 'FEC_IPP_Record_No__c') ?? '').toString();
                        const ippBalance = Number(getValue(record, 'ippBalance', 'IppBalance', 'FEC_IPP_Balance__c')) || 0;
                        const firstDueDate = getValue(record, 'firstDueDate', 'FirstDueDate', 'FEC_IPP_First_Due_Date__c') ?? null;
                        const matureDate = getValue(record, 'matureDate', 'MatureDate', 'FEC_IPP_Mature_Date__c') ?? null;
                        const currentBalance = Number(getValue(record, 'currentBalance', 'CurrentBalance', 'FEC_IPP_Current_Balance__c')) || 0;
                        const currentTerm = getValue(record, 'currentTerm', 'CurrentTerm', 'FEC_IPP_Current_Term__c') ?? null;
                        const ippTerm = getValue(record, 'ippTerm', 'IppTerm', 'FEC_IPP_Term__c') ?? null;
                        const openDate = getValue(record, 'openDate', 'OpenDate', 'FEC_IPP_Open_Date__c') ?? null;
                        const interestRate = getValue(record, 'interestRate', 'InterestRate', 'FEC_IPP_Interest_Rate__c') ?? null;
                        const totalIPPPaymentAmount = Number(getValue(record, 'totalIPPPaymentAmount', 'FEC_Total_IPP_Payment_Amount__c')) || 0;
                        const totalIPPMonthlyPrincipal = Number(getValue(record, 'totalIPPMonthlyPrincipal', 'FEC_Total_IPP_Monthly_Principal__c')) || 0;
                        const totalIPPMonthlyInterest = Number(getValue(record, 'totalIPPMonthlyInterest', 'FEC_Total_IPP_Monthly_Interest__c')) || 0;

                        const planNumber = (getValue(record, 'planNumber', 'PlanNumber', 'FEC_IPP_Plan__c') ?? '').toString();
                        const interestRateNum = interestRate != null ? Number(interestRate) : null;

                        return {
                            Id: record.Id ?? record.id,
                            recordNo: recordNo,
                            planNumber: planNumber,
                            openDate: openDate,
                            openDateFormatted: formatDate(openDate) || '',
                            firstDueDate: firstDueDate,
                            firstDueDateFormatted: formatDate(firstDueDate) || '',
                            matureDate: matureDate,
                            matureDateFormatted: formatDate(matureDate) || '',
                            ippBalance: ippBalance,
                            ippBalanceFormatted: formatCurrency(ippBalance, 0),
                            ippBalanceClass: isNegative(ippBalance) ? 'slds-text-color_error' : '',
                            currentBalance: currentBalance,
                            currentBalanceFormatted: formatCurrency(currentBalance, 0),
                            currentBalanceClass: isNegative(currentBalance) ? 'slds-text-color_error' : '',
                            interestRate: interestRateNum,
                            interestRateFormatted: interestRateNum != null ? interestRateNum + '%' : '-',
                            currentTerm: currentTerm,
                            currentTermFormatted: currentTerm != null ? String(formatCurrency(currentTerm, 0)) : '-',
                            ippTerm: ippTerm,
                            ippTermFormatted: ippTerm != null ? formatCurrency(ippTerm, 0) : '-',
                            totalIPPPaymentAmount: totalIPPPaymentAmount,
                            totalIPPPaymentAmountFormatted: formatCurrency(totalIPPPaymentAmount, 0),
                            totalIPPMonthlyPrincipal: totalIPPMonthlyPrincipal,
                            totalIPPMonthlyPrincipalFormatted: formatCurrency(totalIPPMonthlyPrincipal, 0),
                            totalIPPMonthlyInterest: totalIPPMonthlyInterest,
                            totalIPPMonthlyInterestFormatted: formatCurrency(totalIPPMonthlyInterest, 0),
                            ccCode: (getValue(record, 'ccCode', 'FEC_CC_Code__c') ?? '-').toString(),
                            ccName: (getValue(record, 'ccName', 'FEC_CC_Name__c') ?? '-').toString(),
                            dsaCode: (getValue(record, 'dsaCode', 'FEC_DSA_Code__c') ?? '-').toString(),
                            dsaName: (getValue(record, 'dsaName', 'FEC_DSA_Name__c') ?? '-').toString(),
                            tsaCode: (getValue(record, 'tsaCode', 'FEC_TSA_Code__c') ?? '-').toString(),
                            tsaName: (getValue(record, 'tsaName', 'FEC_TSA_Name__c') ?? '-').toString(),
                            applicationId: (getValue(record, 'applicationId', 'FEC_Application_ID__c') ?? '-').toString(),
                            originationChannel: (getValue(record, 'originationChannel', 'FEC_Origination_Channel__c') ?? '-').toString(),
                            disbursementChannel: (getValue(record, 'disbursementChannel', 'FEC_Disbursement_Channel__c') ?? '-').toString()
                        };
                    });
                    this.totalIPPBalance = this.ippData.reduce((sum, plan) => sum + (plan.ippBalance || 0), 0);
                    this.totalIPPCurrentBalance = this.ippData.reduce((sum, plan) => sum + (plan.currentBalance || 0), 0);
                    this.hasError = false;
                    this.updatedTime = new Date();
                    this.isLoading = false;
                } catch (mappingError) {
                    console.error('Error mapping IPP data:', mappingError);
                    this.hasError = true;
                    this.ippData = [];
                    this.totalIPPBalance = 0;
                    this.totalIPPCurrentBalance = 0;
                    this.isLoading = false;
                }
            })
            .catch(error => {
                console.error('Error loading IPP data:', error);
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
    
    // Default sort cho RelatedListPaging (Open Date mới nhất trước)
    get defaultSortBy() {
        return 'openDateFormatted';
    }
    get defaultSortDirection() {
        return 'desc';
    }

    /**
     * Handle row select từ RelatedListPaging (click vào IPP Plan hyperlink)
     * Navigate đến custom IPP detail page
     */
    handleRowSelect(event) {
        const recordId = event.detail.recordId;
        if (!recordId) return;

        const row = this.ippData.find((r) => r.Id === recordId);
        if (!row) return;

        // Navigate đến custom IPP detail page với Aura wrapper
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: {
                componentName: 'c__FEC_IPPDetailPageWrapper'
            },
            state: {
                c__recordId: recordId,
                c__planNumber: row.planNumber,
                c__recordData: JSON.stringify(row)
            }
        });

        // Publish LMS message (optional)
        const payload = {
            action: 'viewSalesInfo',
            planNumber: row.planNumber,
            ippRecordId: recordId,
            recordData: JSON.stringify(row)
        };
        publish(this.messageContext, FEC_IPP_NAVIGATION, payload);
    }
    
    // Formatted currency values for summary (với 0 decimal places và prefix VND)
    get formattedTotalIPPBalance() {
        return formatCurrency(this.totalIPPBalance, 0);
    }
    
    get isTotalIPPBalanceNegative() {
        return isNegative(this.totalIPPBalance);
    }
    
    get formattedTotalIPPCurrentBalance() {
        return formatCurrency(this.totalIPPCurrentBalance, 0);
    }
    
    get isTotalIPPCurrentBalanceNegative() {
        return isNegative(this.totalIPPCurrentBalance);
    }
    
    // CSS class cho summary totals để highlight màu đỏ nếu âm
    get totalIPPBalanceClass() {
        const baseClass = 'slds-p-left_medium';
        return isNegative(this.totalIPPBalance) 
            ? `${baseClass} slds-text-color_error` 
            : baseClass;
    }
    
    get totalIPPCurrentBalanceClass() {
        const baseClass = 'slds-p-left_medium';
        return isNegative(this.totalIPPCurrentBalance) 
            ? `${baseClass} slds-text-color_error` 
            : baseClass;
    }
}
