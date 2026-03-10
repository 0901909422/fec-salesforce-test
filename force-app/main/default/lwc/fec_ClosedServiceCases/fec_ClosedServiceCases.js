import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getClosedServiceCases from '@salesforce/apex/FEC_GetServiceCases.getClosedServiceCases';
import getCaseFieldHelpTexts from '@salesforce/apex/FEC_GetServiceCases.getCaseFieldHelpTexts';
import { formatDateTimeVN } from 'c/fec_CommonUtils';
import { STR_NA, MSG_NO_RESULTS, MSG_UNKNOWN_ERROR,STR_EMPTY, CASE_OBJECT_API_NAME, NAV_ACTION_VIEW } from 'c/fec_CommonConst';
import FEC_Button_Refresh from '@salesforce/label/c.FEC_Button_Refresh';
import FEC_Closed_Service_Cases_Section_Title from '@salesforce/label/c.FEC_Closed_Service_Cases_Section_Title';
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

export default class Fec_ClosedServiceCases extends NavigationMixin(LightningElement) {
  @track data = [];
  @track lastRefreshTime = null;
  @track isLoading = false;
  @track error;

  sortedBy = 'caseCreatedOn';

  activeSections = ['closedServiceCases'];

  emptyMessage = MSG_NO_RESULTS;

  labels = {
    sectionTitle: FEC_Closed_Service_Cases_Section_Title,
    refresh: FEC_Button_Refresh,
  };

  _helpTexts = {};
  _baseClosedColumns = [
    {
      label: FEC_Case_ID_Label,
      fieldName: 'caseIdText',
      fieldApiName: 'FEC_ID_Search__c',
      type: 'link',
      recordIdField: 'caseId',
      objectApiName: CASE_OBJECT_API_NAME,
      hoverTitle: FEC_Closed_Service_Cases_Section_Title,
      cellAlign: 'center',
      hoverFields: [
        { label: FEC_Case_ID_Label, fieldName: 'caseIdText' },
        { label: FEC_Case_Status_Label, fieldName: 'caseStatus' },
        { label: FEC_Account_Contract_Number_Label, fieldName: 'accountContractNumber' },
        { label: FEC_Label_Product_Type, fieldName: 'productType' },
        { label: FEC_Label_Category, fieldName: 'category' },
        { label: FEC_Label_Sub_Category, fieldName: 'subCategory' },
        { label: FEC_Label_Sub_Code, fieldName: 'subCode' },
        { label: FEC_Interaction_ID, fieldName: 'interactionIdLabel' },
        { label: FEC_Interaction_Channel_Label, fieldName: 'channel' },
        { label: FEC_Interaction_Sub_Channel_Label, fieldName: 'interactionSubChannel' },
        { label: FEC_Case_Created_On_Label, fieldName: 'caseCreatedOnFormatted' },
        { label: FEC_Case_Created_By_Label, fieldName: 'caseCreatedBy' },
        { label: FEC_Last_Updated_On_Label, fieldName: 'lastUpdatedOnFormatted' },
        { label: FEC_Last_Updated_By_Label, fieldName: 'lastUpdatedBy' },
      ],
    },
    { label: FEC_Case_Status_Label, fieldName: 'caseStatus', fieldApiName: 'FEC_Case_Status__c', type: 'text', cellAlign: 'center' },
    { label: FEC_Account_Contract_Number_Label, fieldName: 'accountContractNumber', fieldApiName: 'FEC_Account_or_Contract__c', type: 'text' },
    { label: FEC_Label_Product_Type, fieldName: 'productType', fieldApiName: 'FEC_Product_Type__c', type: 'link', recordIdField: 'productTypeId', objectApiName: 'FEC_Product_Type__c', cellAlign: 'center' },
    { label: FEC_Label_Category, fieldName: 'category', fieldApiName: 'FEC_Category__c', type: 'text' },
    { label: FEC_Label_Sub_Category, fieldName: 'subCategory', fieldApiName: 'FEC_SubCategory__c', type: 'text' },
    { label: FEC_Label_Sub_Code, fieldName: 'subCode', fieldApiName: 'FEC_SubCode__c', type: 'text' },
    {
      label: FEC_Interaction_ID,
      fieldName: 'interactionIdLabel',
      fieldApiName: 'FEC_Interaction__c',
      type: 'link',
      recordIdField: 'interactionId',
      hoverTitle: FEC_Interaction_Title_Label,
      cellAlign: 'center',
      hoverFields: [
        { label: FEC_Interaction_ID, fieldName: 'interactionIdLabel' },
        { label: FEC_Label_Channel, fieldName: 'channel' },
        { label: FEC_Label_Sub_Channel, fieldName: 'interactionSubChannel' },
      ],
    },
    { label: FEC_Interaction_Channel_Label, fieldName: 'channel', fieldApiName: 'FEC_Channel__c', type: 'text', cellAlign: 'center' },
    { label: FEC_Interaction_Sub_Channel_Label, fieldName: 'interactionSubChannel', fieldApiName: 'FEC_Interaction_Subchannel__c', type: 'text' },
    { label: FEC_Case_Created_On_Label, fieldName: 'caseCreatedOnFormatted', fieldApiName: 'FEC_Case_Created_On__c', type: 'text', cellAlign: 'center' },
    { label: FEC_Case_Created_By_Label, fieldName: 'caseCreatedBy', fieldApiName: 'FEC_Case_Created_By__c', type: 'text' },
    { label: FEC_Last_Updated_On_Label, fieldName: 'lastUpdatedOnFormatted', fieldApiName: 'FEC_Last_Updated_On__c', type: 'text', cellAlign: 'center' },
    { label: FEC_Last_Updated_By_Label, fieldName: 'lastUpdatedBy', fieldApiName: 'FEC_Last_Updated_By__c', type: 'text' },
  ];

  @wire(getCaseFieldHelpTexts)
  wiredHelpTexts({ data }) {
    this._helpTexts = data || {};
  }

  get closedColumns() {
    const ht = this._helpTexts;
    return this._baseClosedColumns.map((col) => ({
      ...col,
      helpText: (col.fieldApiName && ht[col.fieldApiName]) ? ht[col.fieldApiName] : undefined,
    }));
  }

  get closedRecords() {
    return this.data;
  }

  get hasClosedRecords() {
    return this.data && this.data.length > 0;
  }

  connectedCallback() {
    this.fetchData();
  }

  async fetchData() {
    this.isLoading = true;
    this.error = undefined;
    try {
      const result = await getClosedServiceCases();
      this.lastRefreshTime = new Date().toISOString();
      this.data = (result || []).map((row) => ({
        ...row,
        Id: row.caseId,
        caseIdText: row.caseIdText || STR_EMPTY,
        interactionIdLabel: row.interactionIdText || STR_NA,
        caseCreatedOnFormatted: formatDateTimeVN(row.caseCreatedOn),
        lastUpdatedOnFormatted: formatDateTimeVN(row.lastUpdatedOn),
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