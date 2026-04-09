import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import FEC_ACCOUNT_OR_CONTRACT from '@salesforce/schema/Case.FEC_Account_or_Contract__c';
import FEC_CONTRACT_NUMBER from '@salesforce/schema/Case.FEC_Contract_Number__c';
import loadLoanAccountInfo from '@salesforce/apex/FEC_MainInfoLoanAccountController.loadLoanAccountInfo';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { isNegative } from 'c/fec_CommonUtils';
import FEC_Contract_Label from '@salesforce/label/c.FEC_Contract_Label';
import FEC_Loan_Label from '@salesforce/label/c.FEC_Loan_Label';
import FEC_Payment_Label from '@salesforce/label/c.FEC_Payment_Label';
import FEC_Debt_Sale_Label from '@salesforce/label/c.FEC_Debt_Sale_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';
import FEC_Application_ID_Label from '@salesforce/label/c.FEC_Application_ID_Label';
import FEC_MainInfo_Contract_Number_Label from '@salesforce/label/c.FEC_MainInfo_Contract_Number_Label';
import FEC_MainInfo_Contract_Type_Label from '@salesforce/label/c.FEC_MainInfo_Contract_Type_Label';
import FEC_MainInfo_Charge_Off_Date_Label from '@salesforce/label/c.FEC_MainInfo_Charge_Off_Date_Label';
import FEC_MainInfo_Contract_Status_Label from '@salesforce/label/c.FEC_MainInfo_Contract_Status_Label';
import FEC_MainInfo_Product_Code_Label from '@salesforce/label/c.FEC_MainInfo_Product_Code_Label';
import FEC_MainInfo_Rate_Label from '@salesforce/label/c.FEC_MainInfo_Rate_Label';
import FEC_MainInfo_Agreement_Date_Label from '@salesforce/label/c.FEC_MainInfo_Agreement_Date_Label';
import FEC_MainInfo_Scheme_ID_Label from '@salesforce/label/c.FEC_MainInfo_Scheme_ID_Label';
import FEC_MainInfo_Account_Status_Change_Date_Label from '@salesforce/label/c.FEC_MainInfo_Account_Status_Change_Date_Label';
import FEC_MainInfo_Scheme_Desc_Label from '@salesforce/label/c.FEC_MainInfo_Scheme_Desc_Label';
import FEC_MainInfo_Loan_Amount_Label from '@salesforce/label/c.FEC_MainInfo_Loan_Amount_Label';
import FEC_MainInfo_Tenure_Label from '@salesforce/label/c.FEC_MainInfo_Tenure_Label';
import FEC_MainInfo_Installment_Remaining_Label from '@salesforce/label/c.FEC_MainInfo_Installment_Remaining_Label';
import FEC_MainInfo_Insurance_Amount_Label from '@salesforce/label/c.FEC_MainInfo_Insurance_Amount_Label';
import FEC_MainInfo_EMI_Label from '@salesforce/label/c.FEC_MainInfo_EMI_Label';
import FEC_MainInfo_First_Payment_Date_Label from '@salesforce/label/c.FEC_MainInfo_First_Payment_Date_Label';
import FEC_MainInfo_Last_Payment_Date_Label from '@salesforce/label/c.FEC_MainInfo_Last_Payment_Date_Label';
import FEC_MainInfo_Next_Due_Date_Label from '@salesforce/label/c.FEC_MainInfo_Next_Due_Date_Label';
import FEC_MainInfo_Days_Past_Due_Label from '@salesforce/label/c.FEC_MainInfo_Days_Past_Due_Label';
import FEC_MainInfo_Company_Name_Label from '@salesforce/label/c.FEC_MainInfo_Company_Name_Label';
import FEC_MainInfo_Sold_Amount_Label from '@salesforce/label/c.FEC_MainInfo_Sold_Amount_Label';
import FEC_MainInfo_Sold_Date_Label from '@salesforce/label/c.FEC_MainInfo_Sold_Date_Label';
import FEC_MainInfo_Sold_Note_Label from '@salesforce/label/c.FEC_MainInfo_Sold_Note_Label';

export default class Fec_MainInfoLoanAccount extends LightningElement {
    /* ================= INPUT ================= */
    @api recordId;

    /* ================= STATE ================= */
    @track accountData;
    @track error;
    @track isLoading = false;
    @track isProcessing = false;

    /** Tránh load trùng khi LDS emit nhiều lần; đổi khi đổi hợp đồng Loan (lookup + số HĐ). */
    _caseContractSignature;

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

    /* ================= CASE → RELOAD KHI ĐỔI HỢP ĐỒNG LOAN ================= */

    @wire(getRecord, {
        recordId: '$recordId',
        fields: [FEC_ACCOUNT_OR_CONTRACT, FEC_CONTRACT_NUMBER],
    })
    wiredCaseForLoanRefresh({ data, error }) {
        if (!this.recordId || !data) {
            return;
        }
        if (error) {
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
            this.buildField(FEC_MainInfo_Contract_Number_Label, this.accountData?.contractNumber, 'FEC_Contract_Number__c'),
            this.buildField(FEC_MainInfo_Contract_Type_Label, this.accountData?.contractType, 'FEC_Contract_Type__c'),
            this.buildField(FEC_MainInfo_Charge_Off_Date_Label, this.accountData?.chargeOffDate, 'FEC_Charge_Off_Date__c'),
            this.buildField(FEC_MainInfo_Contract_Status_Label, this.accountData?.contractStatus, 'FEC_Contract_Status__c'),
            this.buildField(FEC_MainInfo_Product_Code_Label, this.accountData?.productCode, 'FEC_Product_Code__c'),
            this.buildField(FEC_MainInfo_Rate_Label, this.accountData?.rate, 'FEC_Rate__c'),
            this.buildField(FEC_MainInfo_Agreement_Date_Label, this.accountData?.agreementDate, 'FEC_Agreement_Date__c'),
            this.buildField(FEC_MainInfo_Scheme_ID_Label, this.accountData?.schemeID, 'FEC_Scheme_ID__c'),
            this.buildField(FEC_Application_ID_Label, this.accountData?.applicationId, 'FEC_Application_ID__c'),
            this.buildField(FEC_MainInfo_Account_Status_Change_Date_Label, this.accountData?.accountStatusChangeDate, 'FEC_Account_Status_Change_Date__c'),
            this.buildField(FEC_MainInfo_Scheme_Desc_Label, this.accountData?.schemeDesc, 'FEC_Scheme_Desc__c'),
        ];
    }

    get loanFields() {
        if (!this.accountData) return [];

        return [
            this.buildMoneyField(FEC_MainInfo_Loan_Amount_Label, this.accountData?.loanAmount, 'FEC_Loan_Amount__c'),
            this.buildField(FEC_MainInfo_Installment_Remaining_Label, this.accountData?.installmentRemaining, 'FEC_Installments_Remaining__c'),
            this.buildMoneyField(FEC_MainInfo_EMI_Label, this.accountData?.emi, 'FEC_EMI__c'),
            this.buildField(FEC_MainInfo_Tenure_Label, this.accountData?.tenure, 'FEC_Tenure__c'),
            this.buildMoneyField(FEC_MainInfo_Insurance_Amount_Label, this.accountData?.insuranceAmount, 'FEC_Insurance_Amount__c'),
            
        ];
    }

    /** 2 cột nội dung, cột 3 để trống (grid 3 cột). */
    get paymentFields() {
        if (!this.accountData) return [];
        const emptyCell = { label: '', value: '' };
        return [
            this.buildField(FEC_MainInfo_First_Payment_Date_Label, this.accountData?.firstPaymentDate, 'FEC_First_Payment_Date__c'),
            this.buildField(FEC_MainInfo_Next_Due_Date_Label, this.accountData?.nextDueDate, 'FEC_Next_Due_Date__c'),
            
            emptyCell,
            this.buildField(FEC_MainInfo_Last_Payment_Date_Label, this.accountData?.lastPaymentDate, 'FEC_Last_Payment_Date__c'),
            this.buildField(FEC_MainInfo_Days_Past_Due_Label, this.accountData?.daysPastDue, 'FEC_Days_Past_Due__c'),
            emptyCell,
        ];
    }

    /** 2 cột nội dung, cột 3 để trống (grid 3 cột). */
    get debtSaleFields() {
        if (!this.accountData) return [];
        const emptyCell = { label: '', value: '' };
        return [
            this.buildField(FEC_MainInfo_Company_Name_Label, this.accountData?.companyName, 'FEC_Company_Name__c'),
            this.buildField(FEC_MainInfo_Sold_Date_Label, this.accountData?.soldDate, 'FEC_Sold_Date__c'),
            emptyCell,
            this.buildMoneyField(FEC_MainInfo_Sold_Amount_Label, this.accountData?.soldAmount, 'FEC_Sold_Amount__c'),
            this.buildField(FEC_MainInfo_Sold_Note_Label, this.accountData?.soldNote, 'FEC_Sold_Note__c'),
            emptyCell,
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
            type: isNegative(value) ? 'negative' : 'regular',
            helpText: helpText || undefined
        };
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
