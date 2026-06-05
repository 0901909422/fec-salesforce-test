import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import FEC_ACCOUNT_OR_CONTRACT from '@salesforce/schema/Case.FEC_Account_or_Contract__c';
import FEC_CONTRACT_NUMBER from '@salesforce/schema/Case.FEC_Contract_Number__c';
import { isNegative, formatNum } from 'c/fec_CommonUtils';
import getTerminationData from '@salesforce/apex/FEC_TerminationLoanController.getTerminationData';
import FEC_Termination_Label from '@salesforce/label/c.FEC_Termination_Label';
import FEC_Early_Termination_Label from '@salesforce/label/c.FEC_Early_Termination_Label';
import FEC_Overdue_Label from '@salesforce/label/c.FEC_Overdue_Label';
import FEC_Fee_Charge_Label from '@salesforce/label/c.FEC_Fee_Charge_Label';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';
import FEC_Common_No_Results_Label from '@salesforce/label/c.FEC_Common_No_Results_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Termination_Type_Label from '@salesforce/label/c.FEC_Termination_Type_Label';
import FEC_Termination_Assessed_Amount_Label from '@salesforce/label/c.FEC_Termination_Assessed_Amount_Label';
import FEC_Termination_Collected_Amount_Label from '@salesforce/label/c.FEC_Termination_Collected_Amount_Label';
import FEC_Termination_Waived_Amount_Label from '@salesforce/label/c.FEC_Termination_Waived_Amount_Label';
import FEC_Termination_Outstanding_Amount_Label from '@salesforce/label/c.FEC_Termination_Outstanding_Amount_Label';
import FEC_Termination_Field_Termination_Amount_Label from '@salesforce/label/c.FEC_Termination_Field_Termination_Amount_Label';
import FEC_Termination_Field_Excess_Amount_Label from '@salesforce/label/c.FEC_Termination_Field_Excess_Amount_Label';
import FEC_Termination_Field_Pre_Payment_Penalty_Label from '@salesforce/label/c.FEC_Termination_Field_Pre_Payment_Penalty_Label';
import FEC_Termination_Field_Total_Installment_Paid_Label from '@salesforce/label/c.FEC_Termination_Field_Total_Installment_Paid_Label';
import FEC_Termination_Field_Current_Balance_Principal_Label from '@salesforce/label/c.FEC_Termination_Field_Current_Balance_Principal_Label';
import FEC_Termination_Field_Pending_Penal_Interest_Label from '@salesforce/label/c.FEC_Termination_Field_Pending_Penal_Interest_Label';
import FEC_Termination_Field_Total_Principal_Paid_Label from '@salesforce/label/c.FEC_Termination_Field_Total_Principal_Paid_Label';
import FEC_Termination_Field_Interest_On_Termination_Label from '@salesforce/label/c.FEC_Termination_Field_Interest_On_Termination_Label';
import FEC_Termination_Field_LPI_Paid_Label from '@salesforce/label/c.FEC_Termination_Field_LPI_Paid_Label';
import FEC_Termination_Field_Total_Interest_Paid_Label from '@salesforce/label/c.FEC_Termination_Field_Total_Interest_Paid_Label';
import FEC_Termination_Field_Total_Overdue_Amount_Label from '@salesforce/label/c.FEC_Termination_Field_Total_Overdue_Amount_Label';
import FEC_Termination_Field_Principal_Overdue_Label from '@salesforce/label/c.FEC_Termination_Field_Principal_Overdue_Label';
import FEC_Termination_Field_Interest_Overdue_Label from '@salesforce/label/c.FEC_Termination_Field_Interest_Overdue_Label';
import FEC_Termination_Field_Installments_Overdue_Label from '@salesforce/label/c.FEC_Termination_Field_Installments_Overdue_Label';
import FEC_Termination_Field_Penalty_Fee_Overdue_Label from '@salesforce/label/c.FEC_Termination_Field_Penalty_Fee_Overdue_Label';
import FEC_Termination_Field_Overdue_Penalty_Label from '@salesforce/label/c.FEC_Termination_Field_Overdue_Penalty_Label';

export default class Fec_Termination extends LightningElement {
    /* ================= INPUT ================= */
    @api recordId;

    /* ================= STATE ================= */
    @track terminationData;
    @track earlyTermination = [];
    @track overdue = [];
    @track feeChargeList = [];
    @track feeChargeUpdatedTime = null;
    @track errorMessage;
    @track isLoading = false;
    /** Help text map từ Apex (luồng giống fec_CardPayment). */
    helpTextMap = {};

    /** Tránh load trùng LDS; đổi khi đổi hợp đồng Loan. */
    _caseContractSignature;

    /* ================= LABELS (format MainInfoLoanAccount) ================= */
    customLabel = {
        cardTitle: FEC_Termination_Label,
        earlyTermination: FEC_Early_Termination_Label,
        overdue: FEC_Overdue_Label,
        feeCharge: FEC_Fee_Charge_Label,
        loadingAlt: FEC_Termination_Loading_Alt,
        noFeeChargeData: FEC_Common_No_Results_Label,
        noData: FEC_Common_No_Results_Label,
        msgErrorAPI: FEC_MSG_Error_API_Label,
    };

    get activeSections() {
        return [FEC_Early_Termination_Label, FEC_Overdue_Label, FEC_Fee_Charge_Label];
    }

    /** Map fieldApiName -> Custom Label cho Early Termination (hiển thị cột). */
    get earlyTerminationFieldLabelByApi() {
        return {
            'FEC_Termination_Amount__c': FEC_Termination_Field_Termination_Amount_Label,
            'FEC_Excess_Amount__c': FEC_Termination_Field_Excess_Amount_Label,
            'FEC_Pre_Payment_Penalty__c': FEC_Termination_Field_Pre_Payment_Penalty_Label,
            'FEC_Total_Installment_Paid__c': FEC_Termination_Field_Total_Installment_Paid_Label,
            'FEC_Current_Balance_Principal__c': FEC_Termination_Field_Current_Balance_Principal_Label,
            'FEC_Pending_Penal_Interest__c': FEC_Termination_Field_Pending_Penal_Interest_Label,
            'FEC_Total_Principal_Paid__c': FEC_Termination_Field_Total_Principal_Paid_Label,
            'FEC_Interest_On_Termination__c': FEC_Termination_Field_Interest_On_Termination_Label,
            'FEC_LPI_Paid__c': FEC_Termination_Field_LPI_Paid_Label,
            'FEC_Total_Interest_Paid__c': FEC_Termination_Field_Total_Interest_Paid_Label,
        };
    }

    /** Map fieldApiName -> Custom Label cho Overdue (hiển thị cột). */
    get overdueFieldLabelByApi() {
        return {
            'FEC_Total_Overdue_Amount__c': FEC_Termination_Field_Total_Overdue_Amount_Label,
            'FEC_Principal_Overdue__c': FEC_Termination_Field_Principal_Overdue_Label,
            'FEC_Interest_Overdue__c': FEC_Termination_Field_Interest_Overdue_Label,
            'FEC_Installments_Overdue__c': FEC_Termination_Field_Installments_Overdue_Label,
            'FEC_Penalty_Fee_Overdue__c': FEC_Termination_Field_Penalty_Fee_Overdue_Label,
            'FEC_Overdue_Penalty__c': FEC_Termination_Field_Overdue_Penalty_Label,
        };
    }

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [FEC_ACCOUNT_OR_CONTRACT, FEC_CONTRACT_NUMBER],
    })
    wiredCaseForLoanRefresh({ data, error }) {
        if (!this.recordId || !data || error) {
            return;
        }
        const historyId = getFieldValue(data, FEC_ACCOUNT_OR_CONTRACT);
        const contractNo = getFieldValue(data, FEC_CONTRACT_NUMBER);
        const signature = `${this.recordId}|${historyId || ''}|${contractNo || ''}`;
        if (this._caseContractSignature === signature) {
            return;
        }
        this._caseContractSignature = signature;
        this.loadData();
    }

    loadData() {
        if (!this.recordId) return;

        this.isLoading = true;
        this.errorMessage = undefined;

        getTerminationData({ caseId: this.recordId })
            .then((result) => {
                this.terminationData = result;
                this.earlyTermination = result.earlyTermination || [];
                this.overdue = result.overdue || [];
                this.feeChargeList = result.feeChargeList || [];
                this.feeChargeUpdatedTime = new Date();
                this.helpTextMap = result.helpTexts || {};
                if (result.error) {
                    this.errorMessage = result.error;
                }
            })
            .catch((err) => {
                this.errorMessage = err?.body?.message || err?.message || 'Unknown error';
                this.earlyTermination = [];
                this.overdue = [];
                this.feeChargeList = [];
                this.helpTextMap = {};
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /**
     * Hiển thị section có trường (giống Main/Secondary) khi không có lỗi.
     * Chỉ hiển thị "tải dữ liệu không thành công" khi errorMessage (API lỗi).
     */
    get hasData() {
        return !this.errorMessage;
    }

    /* Nhãn mặc định cho Early Termination khi API trả về rỗng (đồng bộ với controller) */
    get defaultEarlyTerminationLabels() {
        return [
            FEC_Termination_Field_Termination_Amount_Label,
            FEC_Termination_Field_Excess_Amount_Label,
            FEC_Termination_Field_Pre_Payment_Penalty_Label,
            FEC_Termination_Field_Total_Installment_Paid_Label,
            FEC_Termination_Field_Current_Balance_Principal_Label,
            FEC_Termination_Field_Pending_Penal_Interest_Label,
            FEC_Termination_Field_Total_Principal_Paid_Label,
            FEC_Termination_Field_Interest_On_Termination_Label,
            FEC_Termination_Field_LPI_Paid_Label,
            FEC_Termination_Field_Total_Interest_Paid_Label,
        ];
    }

    /* Nhãn mặc định cho Overdue khi API trả về rỗng (đồng bộ với controller) */
    get defaultOverdueLabels() {
        return [
            FEC_Termination_Field_Total_Overdue_Amount_Label,
            FEC_Termination_Field_Principal_Overdue_Label,
            FEC_Termination_Field_Interest_Overdue_Label,
            FEC_Termination_Field_Installments_Overdue_Label,
            FEC_Termination_Field_Penalty_Fee_Overdue_Label,
            FEC_Termination_Field_Overdue_Penalty_Label,
        ];
    }

    /* ================= SECTION FIELDS (format common-record-detail-section, helpText theo fieldApiName như SecondaryInfo) ================= */
    get earlyTerminationLabelToApi() {
        return {
            [FEC_Termination_Field_Termination_Amount_Label]: 'FEC_Termination_Amount__c',
            [FEC_Termination_Field_Excess_Amount_Label]: 'FEC_Excess_Amount__c',
            [FEC_Termination_Field_Pre_Payment_Penalty_Label]: 'FEC_Pre_Payment_Penalty__c',
            [FEC_Termination_Field_Total_Installment_Paid_Label]: 'FEC_Total_Installment_Paid__c',
            [FEC_Termination_Field_Current_Balance_Principal_Label]: 'FEC_Current_Balance_Principal__c',
            [FEC_Termination_Field_Pending_Penal_Interest_Label]: 'FEC_Pending_Penal_Interest__c',
            [FEC_Termination_Field_Total_Principal_Paid_Label]: 'FEC_Total_Principal_Paid__c',
            [FEC_Termination_Field_Interest_On_Termination_Label]: 'FEC_Interest_On_Termination__c',
            [FEC_Termination_Field_LPI_Paid_Label]: 'FEC_LPI_Paid__c',
            [FEC_Termination_Field_Total_Interest_Paid_Label]: 'FEC_Total_Interest_Paid__c',
        };
    }

    get overdueLabelToApi() {
        return {
            [FEC_Termination_Field_Total_Overdue_Amount_Label]: 'FEC_Total_Overdue_Amount__c',
            [FEC_Termination_Field_Principal_Overdue_Label]: 'FEC_Principal_Overdue__c',
            [FEC_Termination_Field_Interest_Overdue_Label]: 'FEC_Interest_Overdue__c',
            [FEC_Termination_Field_Installments_Overdue_Label]: 'FEC_Installments_Overdue__c',
            [FEC_Termination_Field_Penalty_Fee_Overdue_Label]: 'FEC_Penalty_Fee_Overdue__c',
            [FEC_Termination_Field_Overdue_Penalty_Label]: 'FEC_Overdue_Penalty__c',
        };
    }

    getHelpText(fieldApiName) {
        if (!fieldApiName || !this.helpTextMap || typeof this.helpTextMap !== 'object') return null;
        return this.helpTextMap[fieldApiName] || this.helpTextMap[fieldApiName.toLowerCase()] || null;
    }

    buildField(label, value, fieldApiName) {
        const helpText = this.getHelpText(fieldApiName);
        return {
            label,
            value: value || '-',
            helpText: helpText || undefined
        };
    }

    buildMoneyField(label, value, fieldApiName) {
        const helpText = this.getHelpText(fieldApiName);
        return {
            label,
            value: value || '-',
            type: isNegative(value) ? 'negative' : 'regular',
            helpText: helpText || undefined
        };
    }

    normalizeApiDisplayValue(value) {
        return value == null || value === '' ? '-' : value;
    }

    formatNumberOrDash(value) {
        return value == null ? '-' : formatNum(value);
    }

    get earlyTerminationFields() {
        const labelToApi = this.earlyTerminationLabelToApi;
        const labelByApi = this.earlyTerminationFieldLabelByApi;
        const displayLabel = (fieldApiName, fallback) => labelByApi[fieldApiName] || fallback;
        if (this.earlyTermination && this.earlyTermination.length > 0) {
            return this.earlyTermination.map((item) => {
                const hasValue =
                    item.value != null ||
                    (item.valueFormatted != null && item.valueFormatted !== '');
                const value = hasValue
                    ? item.valueFormatted != null && item.valueFormatted !== ''
                        ? item.valueFormatted
                        : '0.00'
                    : '-';
                const fieldApiName = labelToApi[item.label];
                const label = displayLabel(fieldApiName, item.label);
                return item.isNegative
                    ? this.buildMoneyField(label, value, fieldApiName)
                    : this.buildField(label, value, fieldApiName);
            });
        }
        return this.defaultEarlyTerminationLabels.map((label) => {
            const fieldApiName = labelToApi[label];
            return this.buildField(displayLabel(fieldApiName, label), '-', fieldApiName);
        });
    }

    get overdueFields() {
        const labelToApi = this.overdueLabelToApi;
        const labelByApi = this.overdueFieldLabelByApi;
        const displayLabel = (fieldApiName, fallback) => labelByApi[fieldApiName] || fallback;
        if (this.overdue && this.overdue.length > 0) {
            return this.overdue.map((item) => {
                const value = this.normalizeApiDisplayValue(item.valueFormatted);
                const fieldApiName = labelToApi[item.label];
                if (!fieldApiName) {
                    return null;
                }
                const label = displayLabel(fieldApiName, item.label);
                return this.buildField(label, value, fieldApiName);
            }).filter((item) => item !== null);
        }
        return this.defaultOverdueLabels.map((label) => {
            const fieldApiName = labelToApi[label];
            return this.buildField(displayLabel(fieldApiName, label), '-', fieldApiName);
        });
    }

    /* ================= FEE/CHARGE BẢNG 5 CỘT (trong Termination, dùng related-list-addresses-paging) ================= */
    feeChargeDefaultSortedBy = 'type';
    feeChargePageSize = 10;

    get feeChargePagingColumns() {
        const cols = [
            { label: FEC_Termination_Type_Label, fieldName: 'type', cellAlign: null },
            { label: FEC_Termination_Assessed_Amount_Label, fieldName: 'assessedAmountFormatted', cellAlign: 'right', cellAttributes: { class: { fieldName: 'assessedAmountCellClass' } } },
            { label: FEC_Termination_Collected_Amount_Label, fieldName: 'collectedAmountFormatted', cellAlign: 'right', cellAttributes: { class: { fieldName: 'collectedAmountCellClass' } } },
            { label: FEC_Termination_Waived_Amount_Label, fieldName: 'waivedAmountFormatted', cellAlign: 'right', cellAttributes: { class: { fieldName: 'waivedAmountCellClass' } } },
            { label: FEC_Termination_Outstanding_Amount_Label, fieldName: 'outstandingAmountFormatted', cellAlign: 'right', cellAttributes: { class: { fieldName: 'outstandingAmountCellClass' } } },
        ];
        return cols.map((c) => ({
            ...c,
            thClass: 'fec-fee-charge-th' + (c.cellAlign === 'right' ? ' slds-text-align_right' : ''),
        }));
    }

    get feeChargePagingRecords() {
        if (!this.feeChargeList || this.feeChargeList.length === 0) return [];
        const NEGATIVE_CLASS = 'currency-negative';
        return this.feeChargeList.map((row, index) => ({
            Id: 'fc-' + index,
            type: row.type || '',
            assessedAmountFormatted: this.formatNumberOrDash(row.assessedAmount),
            collectedAmountFormatted: this.formatNumberOrDash(row.collectedAmount),
            waivedAmountFormatted: this.formatNumberOrDash(row.waivedAmount),
            outstandingAmountFormatted: this.formatNumberOrDash(row.outstandingAmount),
            assessedAmountCellClass: isNegative(row.assessedAmount) ? NEGATIVE_CLASS : '',
            collectedAmountCellClass: isNegative(row.collectedAmount) ? NEGATIVE_CLASS : '',
            waivedAmountCellClass: isNegative(row.waivedAmount) ? NEGATIVE_CLASS : '',
            outstandingAmountCellClass: isNegative(row.outstandingAmount) ? NEGATIVE_CLASS : '',
        }));
    }

    get hasFeeChargeData() {
        return this.feeChargeList && this.feeChargeList.length > 0;
    }
}
