import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAllInteractions from '@salesforce/apex/FEC_GetInteractionCases.getAllInteractions';
import getCaseFieldHelpTexts from '@salesforce/apex/FEC_GetInteractionCases.getCaseFieldHelpTexts';
import logSensitiveAccess from '@salesforce/apex/FEC_InteractionHighlightController.logSensitiveAccess';
import { formatDateTimeVN, formatDuration } from 'c/fec_CommonUtils';
import { MSG_NO_RESULTS, MSG_UNKNOWN_ERROR } from 'c/fec_CommonConst';

export default class Fec_InteractionCases extends NavigationMixin(LightningElement) {
  @track data = [];
  @track lastRefreshTime = null;
  @track isLoading = false;
  @track error;

  sortedBy = 'interactionCreatedOnFormatted';

  activeSections = ['interactions'];

  emptyMessage = MSG_NO_RESULTS;

  labels = {
    sectionTitle: 'Interactions',
  };

  _helpTexts = {};
  _baseInteractionColumns = [
    {
      label: 'Interaction ID',
      fieldName: 'interactionIdText',
      fieldApiName: 'FEC_ID_Search__c',
      type: 'link',
      recordIdField: 'Id',
      hoverTitle: 'Interactions',
      cellAlign: 'center',
      hoverFields: [
        { label: 'Interaction ID', fieldName: 'interactionIdText' },
        { label: 'Interaction Status', fieldName: 'interactionStatus' },
        { label: 'Interaction Created On', fieldName: 'interactionCreatedOnFormatted' },
        { label: 'Last Updated On', fieldName: 'lastUpdatedOnFormatted' },
        { label: 'Interaction Duration', fieldName: 'interactionDurationFormatted' },
        { label: 'Interaction Phone', fieldName: 'interactionPhone' },
        { label: 'Interaction Channel', fieldName: 'channel' },
        { label: 'Interaction Sub Channel', fieldName: 'interactionSubChannel' },
      ],
    },
    { label: 'Interaction Status', fieldName: 'interactionStatus', fieldApiName: 'FEC_Interaction_Status__c', type: 'text', cellAlign: 'center' },
    { label: 'Interaction Created On', fieldName: 'interactionCreatedOnFormatted', fieldApiName: 'FEC_Created_On__c', type: 'text', cellAlign: 'center' },
    { label: 'Last Updated On', fieldName: 'lastUpdatedOnFormatted', fieldApiName: 'FEC_Last_Updated_On__c', type: 'text', cellAlign: 'center' },
    { label: 'Interaction Duration', fieldName: 'interactionDurationFormatted', fieldApiName: 'FEC_Interaction_Duration__c', type: 'text', cellAlign: 'center' },
    { label: 'Interaction Phone', fieldName: 'interactionPhone', fieldApiName: 'FEC_Phone_Number__c', type: 'eye', eyeMaskType: 'phone', cellAlign: 'center' },
    { label: 'Interaction Channel', fieldName: 'channel', fieldApiName: 'FEC_Channel__c', type: 'text', cellAlign: 'center' },
    { label: 'Interaction Sub Channel', fieldName: 'interactionSubChannel', fieldApiName: 'FEC_Interaction_Subchannel__c', type: 'text' },
  ];

  @wire(getCaseFieldHelpTexts)
  wiredHelpTexts({ data }) {
    this._helpTexts = data || {};
  }

  get interactionColumns() {
    const ht = this._helpTexts;
    return this._baseInteractionColumns.map((col) => ({
      ...col,
      helpText: (col.fieldApiName && ht[col.fieldApiName]) ? ht[col.fieldApiName] : undefined,
    }));
  }

  get interactionRecords() {
    return this.data;
  }

  get hasInteractionRecords() {
    return this.data && this.data.length > 0;
  }

  connectedCallback() {
    this.fetchData();
  }

  async fetchData() {
    this.isLoading = true;
    this.error = undefined;
    try {
      const result = await getAllInteractions();
      this.lastRefreshTime = new Date().toISOString();
      this.data = (result || []).map((row) => ({
        ...row,
        Id: row.interactionId,
        interactionIdText: row.interactionIdText || '',
        interactionCreatedOn: row.interactionCreatedOn,
        interactionCreatedOnFormatted: formatDateTimeVN(row.interactionCreatedOn),
        lastUpdatedOnFormatted: formatDateTimeVN(row.lastUpdatedOn),
        interactionDurationFormatted: formatDuration(row.interactionDuration),
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
    this[NavigationMixin.Navigate]({
      type: 'standard__recordPage',
      attributes: {
        recordId: recordId,
        objectApiName: 'Case',
        actionName: 'view',
      },
    });
  }

  handleSensitiveLog(event) {
    const recordId = event.detail?.recordId;
    logSensitiveAccess({
      fieldName: 'Interaction Phone',
      caseId: recordId,
    }).catch((e) => {
      console.error('Sensitive log failed', e);
    });
  }

  get showTable() {
    return !this.isLoading && !this.error;
  }
}