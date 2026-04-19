import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import FEC_ACCOUNT_OR_CONTRACT from '@salesforce/schema/Case.FEC_Account_or_Contract__c';
import FEC_CONTRACT_NUMBER from '@salesforce/schema/Case.FEC_Contract_Number__c';
import loadSecondaryLoanInfo from '@salesforce/apex/FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanInfo';
import loadSecondaryLoanCollections from '@salesforce/apex/FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanCollections';
import loadSecondaryLoanSales from '@salesforce/apex/FEC_SecondaryInfoLoanAccountController.loadSecondaryLoanSales';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { isNegative } from 'c/fec_CommonUtils';
import FEC_Disbursement_Label from '@salesforce/label/c.FEC_Disbursement_Label';
import FEC_Collections_Info_Label from '@salesforce/label/c.FEC_Collections_Info_Label';
import FEC_Sales_Info_Label from '@salesforce/label/c.FEC_Sales_Info_Label';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Disbursement_Channel_Label from '@salesforce/label/c.FEC_Disbursement_Channel_Label';
import FEC_CC_Code_Label from '@salesforce/label/c.FEC_CC_Code_Label';
import FEC_CC_Name_Label from '@salesforce/label/c.FEC_CC_Name_Label';
import FEC_DSA_Code_Label from '@salesforce/label/c.FEC_DSA_Code_Label';
import FEC_DSA_Name_Label from '@salesforce/label/c.FEC_DSA_Name_Label';
import FEC_SecondaryInfo_Bank_Name_Label from '@salesforce/label/c.FEC_SecondaryInfo_Bank_Name_Label';
import FEC_SecondaryInfo_Top_Up_Loan_Amount_Requested_Label from '@salesforce/label/c.FEC_SecondaryInfo_Top_Up_Loan_Amount_Requested_Label';
import FEC_SecondaryInfo_Branch_Name_Label from '@salesforce/label/c.FEC_SecondaryInfo_Branch_Name_Label';
import FEC_SecondaryInfo_Disbursement_Date_Label from '@salesforce/label/c.FEC_SecondaryInfo_Disbursement_Date_Label';
import FEC_SecondaryInfo_Top_Up_Old_Ac_Outstanding_Label from '@salesforce/label/c.FEC_SecondaryInfo_Top_Up_Old_Ac_Outstanding_Label';
import FEC_SecondaryInfo_Account_Number_Label from '@salesforce/label/c.FEC_SecondaryInfo_Account_Number_Label';
import FEC_SecondaryInfo_Is_Top_Up_Account_Label from '@salesforce/label/c.FEC_SecondaryInfo_Is_Top_Up_Account_Label';
import FEC_SecondaryInfo_Top_Up_Old_Ac_App_ID_Label from '@salesforce/label/c.FEC_SecondaryInfo_Top_Up_Old_Ac_App_ID_Label';
import FEC_SecondaryInfo_Responsible_Unit_Label from '@salesforce/label/c.FEC_SecondaryInfo_Responsible_Unit_Label';
import FEC_SecondaryInfo_Date_Assigned_Label from '@salesforce/label/c.FEC_SecondaryInfo_Date_Assigned_Label';
import FEC_SecondaryInfo_Responsible_Person_Label from '@salesforce/label/c.FEC_SecondaryInfo_Responsible_Person_Label';
import FEC_SecondaryInfo_TSA_Code_Label from '@salesforce/label/c.FEC_SecondaryInfo_TSA_Code_Label';
import FEC_SecondaryInfo_TSA_Name_Label from '@salesforce/label/c.FEC_SecondaryInfo_TSA_Name_Label';

/** idle | loading | loaded | error */
const S_IDLE = 'idle';
const S_LOADING = 'loading';
const S_LOADED = 'loaded';
const S_ERROR = 'error';

export default class Fec_SecondaryInfoLoanAccount extends LightningElement {
    @api recordId;

    @track accountData;
    @track activeSections = [FEC_Disbursement_Label];
    @track collectionsStage = S_IDLE;
    @track salesStage = S_IDLE;

    @track isLoadingDisbursement = false;
    @track disbursementInitError = false;

    /** Tránh load trùng LDS; đổi khi đổi hợp đồng Loan. */
    _caseContractSignature;

    customLabel = {
        disbursementLabel: FEC_Disbursement_Label,
        collectionInfoLabel: FEC_Collections_Info_Label,
        salesInfoLabel: FEC_Sales_Info_Label,
        msgErrorAPI: FEC_MSG_Error_API_Label,
    };

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
        this.collectionsStage = S_IDLE;
        this.salesStage = S_IDLE;
        this.accountData = null;
        this.loadDisbursement();
    }

    loadDisbursement() {
        if (!this.recordId) {
            return;
        }

        this.isLoadingDisbursement = true;
        this.disbursementInitError = false;

        loadSecondaryLoanInfo({ caseId: this.recordId })
            .then((result) => {
                this.accountData = this.mergeAccountPartial(result);
                this.disbursementInitError = false;
            })
            .catch((err) => {
                this.accountData = null;
                this.disbursementInitError = true;
                this.handleError(err);
            })
            .finally(() => {
                this.isLoadingDisbursement = false;
            });
    }

    mergeAccountPartial(partial) {
        if (!partial || typeof partial !== 'object') {
            return this.accountData && typeof this.accountData === 'object' ? { ...this.accountData } : {};
        }
        const prev = this.accountData && typeof this.accountData === 'object' ? { ...this.accountData } : {};
        const helpPrev = prev.helpTexts && typeof prev.helpTexts === 'object' ? prev.helpTexts : {};
        const helpNew = partial.helpTexts && typeof partial.helpTexts === 'object' ? partial.helpTexts : {};
        return {
            ...prev,
            ...partial,
            helpTexts: { ...helpPrev, ...helpNew },
        };
    }

    toggleSection(sectionName) {
        const prev = Array.isArray(this.activeSections) ? [...this.activeSections] : [];
        const idx = prev.indexOf(sectionName);
        const next = idx > -1 ? prev.filter((s) => s !== sectionName) : [...prev, sectionName];
        this.activeSections = next;

        if (next.includes(FEC_Collections_Info_Label)) {
            this.ensureCollectionsLoaded();
        }
        if (next.includes(FEC_Sales_Info_Label)) {
            this.ensureSalesLoaded();
        }
    }

    handleDisbursementToggle() {
        this.toggleSection(FEC_Disbursement_Label);
    }

    handleCollectionsToggle() {
        this.toggleSection(FEC_Collections_Info_Label);
    }

    handleSalesToggle() {
        this.toggleSection(FEC_Sales_Info_Label);
    }

    get isDisbursementOpen() {
        return this.activeSections.includes(FEC_Disbursement_Label);
    }

    get isCollectionsOpen() {
        return this.activeSections.includes(FEC_Collections_Info_Label);
    }

    get isSalesOpen() {
        return this.activeSections.includes(FEC_Sales_Info_Label);
    }

    get disbursementIconName() {
        return this.isDisbursementOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get collectionsIconName() {
        return this.isCollectionsOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get salesIconName() {
        return this.isSalesOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get disbursementSectionClass() {
        return `slds-accordion__section${this.isDisbursementOpen ? ' slds-is-open' : ''}`;
    }

    get collectionsSectionClass() {
        return `slds-accordion__section${this.isCollectionsOpen ? ' slds-is-open' : ''}`;
    }

    get salesSectionClass() {
        return `slds-accordion__section${this.isSalesOpen ? ' slds-is-open' : ''}`;
    }

    get disbursementContentClass() {
        return this.isDisbursementOpen ? 'slds-accordion__content' : 'slds-accordion__content slds-hide';
    }

    get collectionsContentClass() {
        return this.isCollectionsOpen ? 'slds-accordion__content' : 'slds-accordion__content slds-hide';
    }

    get salesContentClass() {
        return this.isSalesOpen ? 'slds-accordion__content' : 'slds-accordion__content slds-hide';
    }

    get disbursementHeaderText() {
        if (this.disbursementInitError) {
            return `${this.customLabel.disbursementLabel} - ${this.customLabel.msgErrorAPI}`;
        }
        return this.customLabel.disbursementLabel;
    }

    ensureCollectionsLoaded() {
        if (!this.recordId) {
            return;
        }
        if (this.collectionsStage === S_LOADING || this.collectionsStage === S_LOADED) {
            return;
        }

        this.collectionsStage = S_LOADING;

        loadSecondaryLoanCollections({ caseId: this.recordId })
            .then((partial) => {
                this.accountData = this.mergeAccountPartial(partial);
                this.collectionsStage = S_LOADED;
            })
            .catch(() => {
                this.collectionsStage = S_ERROR;
            });
    }

    ensureSalesLoaded() {
        if (!this.recordId) {
            return;
        }
        if (this.salesStage === S_LOADING || this.salesStage === S_LOADED) {
            return;
        }

        this.salesStage = S_LOADING;

        loadSecondaryLoanSales({ caseId: this.recordId })
            .then((partial) => {
                this.accountData = this.mergeAccountPartial(partial);
                this.salesStage = S_LOADED;
            })
            .catch(() => {
                this.salesStage = S_ERROR;
            });
    }

    get collectionsSectionLabelError() {
        return this.collectionsStage === S_ERROR ? this.customLabel.msgErrorAPI : null;
    }

    get salesSectionLabelError() {
        return this.salesStage === S_ERROR ? this.customLabel.msgErrorAPI : null;
    }

    get isLoadingCollections() {
        return this.collectionsStage === S_LOADING;
    }

    get isLoadingSales() {
        return this.salesStage === S_LOADING;
    }

    get disbursementFields() {
        if (!this.accountData || this.disbursementInitError) {
            return [];
        }

        return [
            this.buildField(FEC_SecondaryInfo_Bank_Name_Label, this.accountData?.bankName, 'FEC_Bank_Name__c'),
            this.buildField(FEC_Disbursement_Channel_Label, this.accountData?.disbursementChannel, 'FEC_Disbursement_Channel__c'),
            this.buildMoneyField(
                FEC_SecondaryInfo_Top_Up_Loan_Amount_Requested_Label,
                this.accountData?.topUpLoanAmountRequested,
                'FEC_Top_Up_Loan_Amount_Requested__c'
            ),
            this.buildField(FEC_SecondaryInfo_Branch_Name_Label, this.accountData?.branchName, 'FEC_Branch_Name__c'),
            this.buildField(FEC_SecondaryInfo_Disbursement_Date_Label, this.accountData?.disbursementDate, 'FEC_Disbursement_Date__c'),
            this.buildMoneyField(
                FEC_SecondaryInfo_Top_Up_Old_Ac_Outstanding_Label,
                this.accountData?.topUpOldAcOutstanding,
                'FEC_Top_Up_Old_A_c_Outstanding__c'
            ),
            this.buildField(FEC_SecondaryInfo_Account_Number_Label, this.accountData?.accountNumber, 'FEC_Account_Number__c'),
            this.buildField(FEC_SecondaryInfo_Is_Top_Up_Account_Label, this.accountData?.isTopUpAccount, 'FEC_Is_Top_Up_Account__c'),
            this.buildField(FEC_SecondaryInfo_Top_Up_Old_Ac_App_ID_Label, this.accountData?.topUpOldAcAppId, 'FEC_Top_Up_Old_Account_App_ID__c'),
        ];
    }

    get collectionInfoFields() {
        if (this.collectionsStage !== S_LOADED || !this.accountData) {
            return [];
        }

        return [
            this.buildField(FEC_SecondaryInfo_Responsible_Unit_Label, this.accountData?.responsibleUnit, 'FEC_Responsible_Unit__c'),
            this.buildField(FEC_SecondaryInfo_Date_Assigned_Label, this.accountData?.dateAssigned, 'FEC_Date_Assigned__c'),
            { label: '', value: '' },
            this.buildField(FEC_SecondaryInfo_Responsible_Person_Label, this.accountData?.responsiblePerson, 'FEC_Responsible_Person__c'),
        ];
    }

    get salesInfoFields() {
        if (this.salesStage !== S_LOADED || !this.accountData) {
            return [];
        }

        return [
            this.buildField(FEC_CC_Code_Label, this.accountData?.ccCode, 'FEC_CC_Code__c'),
            this.buildField(FEC_DSA_Code_Label, this.accountData?.dsaCode, 'FEC_DSA_Code__c'),
            this.buildField(FEC_SecondaryInfo_TSA_Code_Label, this.accountData?.tsaCode, 'FEC_TSA_Code__c'),
            this.buildField(FEC_CC_Name_Label, this.accountData?.ccName, 'FEC_CC_Name__c'),
            this.buildField(FEC_DSA_Name_Label, this.accountData?.dsaName, 'FEC_DSA_Name__c'),
            this.buildField(FEC_SecondaryInfo_TSA_Name_Label, this.accountData?.tsaName, 'FEC_TSA_Name__c'),
        ];
    }

    getHelpText(fieldApiName) {
        if (!fieldApiName || !this.accountData?.helpTexts) {
            return null;
        }
        const helpTexts = this.accountData.helpTexts;
        return helpTexts[fieldApiName] || helpTexts[fieldApiName.toLowerCase()] || null;
    }

    buildField(label, value, fieldApiName) {
        const helpText = this.getHelpText(fieldApiName);
        return {
            label,
            value: value || '-',
            helpText: helpText || undefined,
        };
    }

    buildMoneyField(label, value, fieldApiName) {
        const helpText = this.getHelpText(fieldApiName);
        return {
            label,
            value: value || '-',
            type: isNegative(value) ? 'negative' : 'regular',
            helpText: helpText || undefined,
        };
    }

    handleError(err) {
        const message = err?.body?.message || err?.message || 'Unknown error';
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message,
                variant: 'error',
            })
        );
    }
}
