import { LightningElement, api, track } from 'lwc';
import loadLoanAccountInfo from '@salesforce/apex/FEC_MainInfoLoanAccountController.loadLoanAccountInfo';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FEC_Contract_Label from '@salesforce/label/c.FEC_Contract_Label';
import FEC_Loan_Label from '@salesforce/label/c.FEC_Loan_Label';
import FEC_Payment_Label from '@salesforce/label/c.FEC_Payment_Label';
import FEC_Debt_Sale_Label from '@salesforce/label/c.FEC_Debt_Sale_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';

export default class Fec_MainInfoLoanAccount extends LightningElement {
    /* ================= INPUT ================= */
    @api recordId;

    /* ================= STATE ================= */
    @track accountData;
    @track error;
    @track isLoading = false;
    @track isProcessing = false;

    get activeSections() {
        return [FEC_Contract_Label, FEC_Loan_Label, FEC_Payment_Label, FEC_Debt_Sale_Label];
    }
    customLabel = {
        contractLabel: FEC_Contract_Label,
        loanLabel: FEC_Loan_Label,
        paymentLabel: FEC_Payment_Label,
        debtSaleLabel: FEC_Debt_Sale_Label,
        msgErrorAPI: FEC_MSG_Error_API_Label,
        loadingAlt: FEC_Termination_Loading_Alt,
    }

    /* ================= LIFECYCLE ================= */

    connectedCallback() {
        this.loadData();
    }

    /* ================= LOAD LOCAL DATA ================= */

    loadData() {
        if (!this.recordId) return;

        this.isLoading = true;

        loadLoanAccountInfo({ caseId: this.recordId })
            .then(result => {
                console.log('### loadLoanAccountInfo result:', JSON.stringify(result));

                this.accountData = result;
                this.error = undefined;
            })
            .catch(err => {
                this.accountData = null;
                this.handleError(err);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /* ================= UI HELPERS ================= */

    /** Chỉ coi có data khi có ít nhất một trường có giá trị. Khi false (không gọi được API / lỗi / không có dữ liệu) → hiển thị "Tên section - Tải dữ liệu không thành công". */
    get hasData() {
        if (!this.accountData || typeof this.accountData !== 'object') return false;
        const d = this.accountData;
        const hasValue = (v) => v != null && String(v).trim() !== '';
        return (
            hasValue(d.contractNumber) 
            // hasValue(d.contractStatus) ||
            // hasValue(d.contractType) ||
            // hasValue(d.loanAmount) ||
            // hasValue(d.emi) ||
            // hasValue(d.agreementDate) ||
            // hasValue(d.nextDueDate) ||
            // hasValue(d.companyName)
        );
    }

    get contractFields() {
        if (!this.accountData) return [];

        return [
            this.buildField('Contract Number', this.accountData?.contractNumber, 'FEC_Contract_Number__c'),
            this.buildField('Contract Type', this.accountData?.contractType, 'FEC_Contract_Type__c'),
            this.buildField('Charge Off Date', this.accountData?.chargeOffDate, 'FEC_Charge_Off_Date__c'),
            this.buildField('Contract Status', this.accountData?.contractStatus, 'FEC_Contract_Status__c'),
            this.buildField('Product Code', this.accountData?.productCode, 'FEC_Product_Code__c'),
            this.buildField('Rate', this.accountData?.rate, 'FEC_Rate__c'),
            this.buildField('Agreement Date', this.accountData?.agreementDate, 'FEC_Agreement_Date__c'),
            this.buildField('Scheme ID', this.accountData?.schemeID, 'FEC_Scheme_ID__c'),
            this.buildField('Application ID', this.accountData?.applicationId, 'FEC_Application_ID__c'),
            this.buildField('Account Status Change Date', this.accountData?.accountStatusChangeDate, 'FEC_Account_Status_Change_Date__c'),
            this.buildField('Scheme Desc', this.accountData?.schemeDesc, 'FEC_Scheme_Desc__c'),
        ];
    }

    get loanFields() {
        if (!this.accountData) return [];

        return [
            this.buildMoneyField('Loan Amount', this.accountData?.loanAmount, 'FEC_Loan_Amount__c'),
            this.buildField('Tenure', this.accountData?.tenure, 'FEC_Tenure__c'),
            this.buildField('Installment Remaining', this.accountData?.installmentRemaining, 'FEC_Installments_Remaining__c'),
            this.buildMoneyField('Insurance Amount', this.accountData?.insuranceAmount, 'FEC_Insurance_Amount__c'),
            this.buildMoneyField('EMI', this.accountData?.emi, 'FEC_EMI__c'),
        ];
    }

    get paymentFields() {
        if (!this.accountData) return [];

        return [
            this.buildField('First Payment Date', this.accountData?.firstPaymentDate, 'FEC_First_Payment_Date__c'),
            this.buildField('Last Payment Date', this.accountData?.lastPaymentDate, 'FEC_Last_Payment_Date__c'),
            this.buildField('Next Due Date', this.accountData?.nextDueDate, 'FEC_Next_Due_Date__c'),
            this.buildField('Days Past Due', this.accountData?.daysPastDue, 'FEC_Days_Past_Due__c'),
        ];
    }

    get debtSaleFields() {
        if (!this.accountData) return [];

        return [
            this.buildField('Company Name', this.accountData?.companyName, 'FEC_Company_Name__c'),
            this.buildMoneyField('Sold Amount', this.accountData?.soldAmount, 'FEC_Sold_Amount__c'),
            this.buildField('Sold Date', this.accountData?.soldDate, 'FEC_Sold_Date__c'),
            this.buildField('Sold Note', this.accountData?.soldNote, 'FEC_Sold_Note__c'),
        ];
    }

    getHelpText(fieldApiName) {
        if (!fieldApiName || !this.accountData?.helpTexts) return null;
        const helpTexts = this.accountData.helpTexts;
        return helpTexts[fieldApiName] || helpTexts[fieldApiName.toLowerCase()] || null;
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
            type: this.isNegative(value) ? 'negative' : 'regular',
            helpText: helpText || undefined
        };
    }

    isNegative(value) {
        return value && value.toString().startsWith('-');
    }

    /* ================= ERROR + TOAST ================= */

    handleError(err) {
        this.error = err?.body?.message || err?.message || 'Unknown error';
        this.showToast('Error', this.error, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}
