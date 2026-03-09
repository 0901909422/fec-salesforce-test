import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPendingServiceCases from '@salesforce/apex/FEC_GetServiceCases.getPendingServiceCases';
import getCaseFieldHelpTexts from '@salesforce/apex/FEC_GetServiceCases.getCaseFieldHelpTexts';
import { formatDateTimeVN } from 'c/fec_CommonUtils';
import { STR_NA } from 'c/fec_CommonConst';

export default class Fec_PendingServiceCases extends NavigationMixin(LightningElement) {
  @track data = [];
  @track lastRefreshTime = null;
  @track isLoading = false;
  @track error;

  sortedBy = 'caseCreatedOn';

  activeSections = ['pendingServiceCases'];

  labels = {
    sectionTitle: 'Pending Service Cases',
  };

  _helpTexts = {};
  _basePendingColumns = [
    {
      label: 'Case ID',
      fieldName: 'caseIdText',
      fieldApiName: 'FEC_ID_Search__c',
      type: 'link',
      recordIdField: 'caseId',
      objectApiName: 'Case',
      hoverTitle: 'Pending Service Cases',
      cellAlign: 'center',
      hoverFields: [
        { label: 'Case ID', fieldName: 'caseIdText' },
        { label: 'Case Status', fieldName: 'caseStatus' },
        { label: 'Account Or Contract Number', fieldName: 'accountContractNumber' },
        { label: 'Product Type', fieldName: 'productType' },
        { label: 'Category', fieldName: 'category' },
        { label: 'Sub Category', fieldName: 'subCategory' },
        { label: 'Sub Code', fieldName: 'subCode' },
        { label: 'Interaction ID', fieldName: 'interactionIdLabel' },
        { label: 'Interaction Channel', fieldName: 'channel' },
        { label: 'Interaction Sub Channel', fieldName: 'interactionSubChannel' },
        { label: 'Case Created On', fieldName: 'caseCreatedOnFormatted' },
        { label: 'Case Created By', fieldName: 'caseCreatedBy' },
        { label: 'Last Updated On', fieldName: 'lastUpdatedOnFormatted' },
        { label: 'Last Updated By', fieldName: 'lastUpdatedBy' },
      ],
    },
    { label: 'Case Status', fieldName: 'caseStatus', fieldApiName: 'FEC_Case_Status__c', type: 'text', cellAlign: 'center' },
    { label: 'Account Or Contract Number', fieldName: 'accountContractNumber', fieldApiName: 'FEC_Account_or_Contract__c', type: 'text' },
    { label: 'Product Type', fieldName: 'productType', fieldApiName: 'FEC_Product_Type__c', type: 'link', recordIdField: 'productTypeId', objectApiName: 'FEC_Product_Type__c', cellAlign: 'center' },
    { label: 'Category', fieldName: 'category', fieldApiName: 'FEC_Category__c', type: 'text' },
    { label: 'Sub Category', fieldName: 'subCategory', fieldApiName: 'FEC_SubCategory__c', type: 'text' },
    { label: 'Sub Code', fieldName: 'subCode', fieldApiName: 'FEC_SubCode__c', type: 'text' },
    {
      label: 'Interaction ID',
      fieldName: 'interactionIdLabel',
      fieldApiName: 'FEC_Interaction__c',
      type: 'link',
      recordIdField: 'interactionId',
      hoverTitle: 'Interaction',
      cellAlign: 'center',
      hoverFields: [
        { label: 'Interaction ID', fieldName: 'interactionIdLabel' },
        { label: 'Channel', fieldName: 'channel' },
        { label: 'Sub Channel', fieldName: 'interactionSubChannel' },
      ],
    },
    { label: 'Interaction Channel', fieldName: 'channel', fieldApiName: 'FEC_Channel__c', type: 'text', cellAlign: 'center' },
    { label: 'Interaction Sub Channel', fieldName: 'interactionSubChannel', fieldApiName: 'FEC_Interaction_Subchannel__c', type: 'text' },
    { label: 'Case Created On', fieldName: 'caseCreatedOnFormatted', fieldApiName: 'FEC_Case_Created_On__c', type: 'text', cellAlign: 'center' },
    { label: 'Case Created By', fieldName: 'caseCreatedBy', fieldApiName: 'FEC_Case_Created_By__c', type: 'text' },
    { label: 'Last Updated On', fieldName: 'lastUpdatedOnFormatted', fieldApiName: 'FEC_Last_Updated_On__c', type: 'text', cellAlign: 'center' },
    { label: 'Last Updated By', fieldName: 'lastUpdatedBy', fieldApiName: 'FEC_Last_Updated_By__c', type: 'text' },
  ];

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
        caseIdText: row.caseIdText || '',
        interactionIdLabel: row.interactionIdText || STR_NA,
        caseCreatedOnFormatted: formatDateTimeVN(row.caseCreatedOn),
        lastUpdatedOnFormatted: formatDateTimeVN(row.lastUpdatedOn),
      }));
    } catch (e) {
      this.error = e.body?.message || e.message || 'Unknown error';
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
    const objectApiName = event.detail?.objectApiName || 'Case';
    this[NavigationMixin.Navigate]({
      type: 'standard__recordPage',
      attributes: {
        recordId: recordId,
        objectApiName: objectApiName,
        actionName: 'view',
      },
    });
  }

  get showTable() {
    return !this.isLoading && !this.error;
  }
}