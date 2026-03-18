import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPendingServiceCases from '@salesforce/apex/FEC_GetServiceCases.getPendingServiceCases';
import getCaseFieldHelpTexts from '@salesforce/apex/FEC_GetServiceCases.getCaseFieldHelpTexts';
import { formatDateTime } from 'c/fec_CommonUtils';
import { STR_NA, STR_EMPTY, MSG_UNKNOWN_ERROR, CASE_OBJECT_API_NAME, NAV_ACTION_VIEW } from 'c/fec_CommonConst';
import FEC_Button_Refresh from '@salesforce/label/c.FEC_Button_Refresh';
import FEC_Pending_Service_Cases_Section_Title from '@salesforce/label/c.FEC_Pending_Service_Cases_Section_Title';
import FEC_Case_ID_Label from '@salesforce/label/c.FEC_Case_ID_Label';
import FEC_Case_Status_Label from '@salesforce/label/c.FEC_Case_Status_Label';
import FEC_Account_Contract_Number_Label from '@salesforce/label/c.FEC_Account_Contract_Number_Label';
import FEC_Label_Product_Type from '@salesforce/label/c.FEC_Label_Product_Type';
import FEC_Label_Category from '@salesforce/label/c.FEC_Label_Category';
import FEC_Label_Sub_Category from '@salesforce/label/c.FEC_Label_Sub_Category';
import FEC_Label_Sub_Code from '@salesforce/label/c.FEC_Label_Sub_Code';
import FEC_Interaction_ID from '@salesforce/label/c.FEC_Interaction_ID';
import FEC_Interaction_Channel_Label from '@salesforce/label/c.FEC_Interaction_Channel_Label';
import FEC_Interaction_Sub_Channel_Label from '@salesforce/label/c.FEC_Interaction_Sub_Channel_Label';
import FEC_Label_Channel from '@salesforce/label/c.FEC_Label_Channel';
import FEC_Label_Sub_Channel from '@salesforce/label/c.FEC_Label_Sub_Channel';
import FEC_Case_Created_On_Label from '@salesforce/label/c.FEC_Case_Created_On_Label';
import FEC_Case_Created_By_Label from '@salesforce/label/c.FEC_Case_Created_By_Label';
import FEC_Last_Updated_On_Label from '@salesforce/label/c.FEC_Last_Updated_On_Label';
import FEC_Last_Updated_By_Label from '@salesforce/label/c.FEC_Last_Updated_By_Label';
import FEC_Interaction_Title_Label from '@salesforce/label/c.FEC_Interaction_Title_Label';

export default class Fec_PendingServiceCases extends NavigationMixin(LightningElement) {
  @track data = [];
  @track lastRefreshTime = null;
  @track isLoading = false;
  @track error;

  sortedBy = 'caseCreatedOn';

  activeSections = ['pendingServiceCases'];

  customLabel = {
    sectionTitle: FEC_Pending_Service_Cases_Section_Title,
    refresh: FEC_Button_Refresh,
    caseIdLabel: FEC_Case_ID_Label,
    caseStatusLabel: FEC_Case_Status_Label,
    accountContractNumberLabel: FEC_Account_Contract_Number_Label,
    productTypeLabel: FEC_Label_Product_Type,
    categoryLabel: FEC_Label_Category,
    subCategoryLabel: FEC_Label_Sub_Category,
    subCodeLabel: FEC_Label_Sub_Code,
    interactionIdLabel: FEC_Interaction_ID,
    interactionChannelLabel: FEC_Interaction_Channel_Label,
    interactionSubChannelLabel: FEC_Interaction_Sub_Channel_Label,
    channelLabel: FEC_Label_Channel,
    subChannelLabel: FEC_Label_Sub_Channel,
    caseCreatedOnLabel: FEC_Case_Created_On_Label,
    caseCreatedByLabel: FEC_Case_Created_By_Label,
    lastUpdatedOnLabel: FEC_Last_Updated_On_Label,
    lastUpdatedByLabel: FEC_Last_Updated_By_Label,
    interactionTitleLabel: FEC_Interaction_Title_Label,
  };

  _helpTexts = {};
  get _basePendingColumns() {
    return [
      {
        label: this.customLabel.caseIdLabel,
        fieldName: 'caseIdText',
        fieldApiName: 'FEC_ID_Search__c',
        type: 'link',
        recordIdField: 'caseId',
        objectApiName: CASE_OBJECT_API_NAME,
        hoverTitle: this.customLabel.sectionTitle,
        cellAlign: 'center',
        hoverFields: [
          { label: this.customLabel.caseIdLabel, fieldName: 'caseIdText' },
          { label: this.customLabel.caseStatusLabel, fieldName: 'caseStatus' },
          { label: this.customLabel.accountContractNumberLabel, fieldName: 'accountContractNumber' },
          { label: this.customLabel.productTypeLabel, fieldName: 'productType' },
          { label: this.customLabel.categoryLabel, fieldName: 'category' },
          { label: this.customLabel.subCategoryLabel, fieldName: 'subCategory' },
          { label: this.customLabel.subCodeLabel, fieldName: 'subCode' },
          { label: this.customLabel.interactionIdLabel, fieldName: 'interactionIdLabel' },
          { label: this.customLabel.interactionChannelLabel, fieldName: 'channel' },
          { label: this.customLabel.interactionSubChannelLabel, fieldName: 'interactionSubChannel' },
          { label: this.customLabel.caseCreatedOnLabel, fieldName: 'caseCreatedOnFormatted' },
          { label: this.customLabel.caseCreatedByLabel, fieldName: 'caseCreatedBy' },
          { label: this.customLabel.lastUpdatedOnLabel, fieldName: 'lastUpdatedOnFormatted' },
          { label: this.customLabel.lastUpdatedByLabel, fieldName: 'lastUpdatedBy' },
        ],
      },
      { label: this.customLabel.caseStatusLabel, fieldName: 'caseStatus', fieldApiName: 'FEC_Case_Status__c', type: 'text', cellAlign: 'center' },
      { label: this.customLabel.accountContractNumberLabel, fieldName: 'accountContractNumber', fieldApiName: 'FEC_Account_or_Contract__c', type: 'text' },
      { label: this.customLabel.productTypeLabel, fieldName: 'productType', fieldApiName: 'FEC_Product_Type__c', type: 'link', recordIdField: 'productTypeId', objectApiName: 'FEC_Product_Type__c', cellAlign: 'center' },
      { label: this.customLabel.categoryLabel, fieldName: 'category', fieldApiName: 'FEC_Category__c', type: 'text' },
      { label: this.customLabel.subCategoryLabel, fieldName: 'subCategory', fieldApiName: 'FEC_SubCategory__c', type: 'text' },
      { label: this.customLabel.subCodeLabel, fieldName: 'subCode', fieldApiName: 'FEC_SubCode__c', type: 'text' },
      {
        label: this.customLabel.interactionIdLabel,
        fieldName: 'interactionIdLabel',
        fieldApiName: 'FEC_Interaction__c',
        type: 'link',
        recordIdField: 'interactionId',
        hoverTitle: this.customLabel.interactionTitleLabel,
        cellAlign: 'center',
        hoverFields: [
          { label: this.customLabel.interactionIdLabel, fieldName: 'interactionIdLabel' },
          { label: this.customLabel.channelLabel, fieldName: 'channel' },
          { label: this.customLabel.subChannelLabel, fieldName: 'interactionSubChannel' },
        ],
      },
      { label: this.customLabel.interactionChannelLabel, fieldName: 'channel', fieldApiName: 'FEC_Channel__c', type: 'text', cellAlign: 'center' },
      { label: this.customLabel.interactionSubChannelLabel, fieldName: 'interactionSubChannel', fieldApiName: 'FEC_Interaction_Subchannel__c', type: 'text' },
      { label: this.customLabel.caseCreatedOnLabel, fieldName: 'caseCreatedOnFormatted', fieldApiName: 'FEC_Case_Created_On__c', type: 'text', cellAlign: 'center' },
      { label: this.customLabel.caseCreatedByLabel, fieldName: 'caseCreatedBy', fieldApiName: 'FEC_Case_Created_By__c', type: 'text' },
      { label: this.customLabel.lastUpdatedOnLabel, fieldName: 'lastUpdatedOnFormatted', fieldApiName: 'FEC_Last_Updated_On__c', type: 'text', cellAlign: 'center' },
      { label: this.customLabel.lastUpdatedByLabel, fieldName: 'lastUpdatedBy', fieldApiName: 'FEC_Last_Updated_By__c', type: 'text' },
    ];
  }

  @wire(getCaseFieldHelpTexts)
  wiredHelpTexts({ data }) {
    this._helpTexts = data || {};
  }

  get pendingColumns() {
    const ht = this._helpTexts;
    return this._basePendingColumns.map((col) => ({
      ...col,
      helpText: (col.fieldApiName && ht[col.fieldApiName]) ? ht[col.fieldApiName] : undefined,
    }));
  }

  get pendingRecords() {
    return this.data;
  }

  connectedCallback() {
    this.fetchData();
  }

  async fetchData() {
    this.isLoading = true;
    this.error = undefined;
    try {
      const result = await getPendingServiceCases();
      this.lastRefreshTime = new Date().toISOString();
      this.data = (result || []).map((row) => ({
        ...row,
        Id: row.caseId,
        caseIdText: row.caseIdText || STR_EMPTY,
        interactionIdLabel: row.interactionIdText || STR_NA,
        caseCreatedOnFormatted: formatDateTime(row.caseCreatedOn),
        lastUpdatedOnFormatted: formatDateTime(row.lastUpdatedOn),
      }));
    } catch (e) {
      this.error = e.body?.message || e.message || MSG_UNKNOWN_ERROR;
      this.data = [];
    } finally {
      this.isLoading = false;
    }
  }

  handleRefresh() {
    this.fetchData();
  }

  handleRowSelect(event) {
    const recordId = event.detail?.recordId;
    if (!recordId) return;
    const objectApiName = event.detail?.objectApiName || CASE_OBJECT_API_NAME;
    this[NavigationMixin.Navigate]({
      type: 'standard__recordPage',
      attributes: {
        recordId: recordId,
        objectApiName: objectApiName,
        actionName: NAV_ACTION_VIEW,
      },
    });
  }

  get showTable() {
    return !this.isLoading && !this.error;
  }
}