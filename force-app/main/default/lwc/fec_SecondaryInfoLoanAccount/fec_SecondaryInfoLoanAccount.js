import { LightningElement, api, track } from 'lwc';
import loadSecondaryLoanInfo from '@salesforce/apex/FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanInfo';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FEC_Disbursement_Label from '@salesforce/label/c.FEC_Disbursement_Label';
import FEC_Collections_Info_Label from '@salesforce/label/c.FEC_Collections_Info_Label';
import FEC_Sales_Info_Label from '@salesforce/label/c.FEC_Sales_Info_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Termination_Loading_Alt from '@salesforce/label/c.FEC_Termination_Loading_Alt';

export default class Fec_SecondaryInfoLoanAccount extends LightningElement {
    @api recordId;

    @track accountData;
    @track error;
    @track isLoading = false;

    get activeSections() {
        return [FEC_Disbursement_Label, FEC_Collections_Info_Label, FEC_Sales_Info_Label];
    }

    customLabel = {
        disbursementLabel: FEC_Disbursement_Label,
        collectionInfoLabel: FEC_Collections_Info_Label,
        salesInfoLabel: FEC_Sales_Info_Label,
        msgErrorAPI: FEC_MSG_Error_API_Label,
        loadingAlt: FEC_Termination_Loading_Alt,
    };

    connectedCallback() {
        console.log('[SecondaryInfo] connectedCallback, recordId=', this.recordId);
        this.loadData();
    }

    loadData() {
        if (!this.recordId) {
            console.warn('[SecondaryInfo] loadData skipped: recordId empty');
            return;
        }
        console.log('[SecondaryInfo] loadData start, caseId=', this.recordId);

        this.isLoading = true;

        loadSecondaryLoanInfo({ caseId: this.recordId })
            .then(result => {
                const hasValue = (v) => v != null && String(v).trim() !== '';
                const d = result || {};
                const hasData = !!(
                    hasValue(d.bankName) || hasValue(d.branchName) || hasValue(d.accountNumber) ||
                    hasValue(d.disbursementChannel) || hasValue(d.responsibleUnit) || hasValue(d.responsiblePerson) ||
                    hasValue(d.dateAssigned) || hasValue(d.ccCode) || hasValue(d.ccName) ||
                    hasValue(d.dsaCode) || hasValue(d.dsaName) || hasValue(d.tsaCode) || hasValue(d.tsaName) ||
                    hasValue(d.topUpLoanAmountRequested)
                );
                console.log('[SecondaryInfo] loadSecondaryLoanInfo OK', {
                    hasData,
                    disbursementDate: d.disbursementDate,
                    dateAssigned: d.dateAssigned,
                    ccCode: d.ccCode,
                    ccName: d.ccName,
                    responsibleUnit: d.responsibleUnit,
                    responsiblePerson: d.responsiblePerson,
                });
                console.log('[SecondaryInfo] full result (no helpTexts):', JSON.stringify({
                    ...d,
                    helpTexts: d.helpTexts ? '(object)' : undefined,
                }));
                this.accountData = result;
                this.error = undefined;
            })
            .catch(err => {
                console.error('[SecondaryInfo] loadSecondaryLoanInfo FAILED', {
                    message: err?.body?.message || err?.message,
                    stack: err?.stack,
                    body: err?.body,
                });
                this.accountData = null;
                this.handleError(err);
            })
            .finally(() => {
                this.isLoading = false;
                console.log('[SecondaryInfo] loadData end');
            });
    }

    /* ================= UI HELPERS ================= */

    /** Chỉ coi có data khi có ít nhất một trường có giá trị. Khi false → hiển thị "Tên section - Tải dữ liệu không thành công". */
    get hasData() {
        if (!this.accountData || typeof this.accountData !== 'object') return false;
        const d = this.accountData;
        const hasValue = (v) => v != null && String(v).trim() !== '';
        return (
            hasValue(d.bankName) ||
            hasValue(d.branchName) ||
            hasValue(d.accountNumber) ||
            hasValue(d.disbursementChannel) ||
            hasValue(d.responsibleUnit) ||
            hasValue(d.responsiblePerson) ||
            hasValue(d.dateAssigned) ||
            hasValue(d.ccCode) ||
            hasValue(d.ccName) ||
            hasValue(d.dsaCode) ||
            hasValue(d.dsaName) ||
            hasValue(d.tsaCode) ||
            hasValue(d.tsaName) ||
            hasValue(d.topUpLoanAmountRequested)
        );
    }

    get disbursementFields() {
        if (!this.accountData) return [];

        return [
            this.buildField('Bank Name', this.accountData?.bankName, 'FEC_Bank_Name__c'),
            this.buildField('Disbursement Channel', this.accountData?.disbursementChannel, 'FEC_Disbursement_Channel__c'),
            this.buildMoneyField('Top Up Loan Amount Requested', this.accountData?.topUpLoanAmountRequested, 'FEC_Top_Up_Loan_Amount_Requested__c'),
            this.buildField('Branch Name', this.accountData?.branchName, 'FEC_Branch_Name__c'),
            this.buildField('Disbursement Date', this.accountData?.disbursementDate, 'FEC_Disbursement_Date__c'),
            this.buildMoneyField('Top Up Old A/c Outstanding', this.accountData?.topUpOldAcOutstanding, 'FEC_Top_Up_Old_A_c_Outstanding__c'),
            this.buildField('Account Number', this.accountData?.accountNumber, 'FEC_Account_Number__c'),
            this.buildField('Is Top Up Account', this.accountData?.isTopUpAccount, 'FEC_Is_Top_Up_Account__c'),
            this.buildField('Top Up Old A/c App ID', this.accountData?.topUpOldAcAppId, 'FEC_Top_Up_Old_Account_App_ID__c'),
        ];
    }

    get collectionInfoFields() {
        if (!this.accountData) return [];

        return [
            this.buildField('Responsible Unit', this.accountData?.responsibleUnit, 'FEC_Responsible_Unit__c'),
            this.buildField('Date Assigned', this.accountData?.dateAssigned, 'FEC_Date_Assigned__c'),
            { label: '', value: '' }, // Ô trống cột 3 hàng 1
            this.buildField('Responsible Person', this.accountData?.responsiblePerson, 'FEC_Responsible_Person__c'),
        ];
    }

    get salesInfoFields() {
        if (!this.accountData) return [];

        return [
            this.buildField('CC Code', this.accountData?.ccCode, 'FEC_CC_Code__c'),
            this.buildField('DSA Code', this.accountData?.dsaCode, 'FEC_DSA_Code__c'),
            this.buildField('TSA Code', this.accountData?.tsaCode, 'FEC_TSA_Code__c'),
            this.buildField('CC Name', this.accountData?.ccName, 'FEC_CC_Name__c'),
            this.buildField('DSA Name', this.accountData?.dsaName, 'FEC_DSA_Name__c'),
            this.buildField('TSA Name', this.accountData?.tsaName, 'FEC_TSA_Name__c'),
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
