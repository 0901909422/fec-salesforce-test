import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAllInteractions from '@salesforce/apex/FEC_GetInteractionCases.getAllInteractions';
import getCaseFieldHelpTexts from '@salesforce/apex/FEC_GetInteractionCases.getCaseFieldHelpTexts';
import logSensitiveAccess from '@salesforce/apex/FEC_InteractionHighlightController.logSensitiveAccess';
import { formatDateTimeVN, formatDuration } from 'c/fec_CommonUtils';
import { MSG_NO_RESULTS, STR_EMPTY, MSG_UNKNOWN_ERROR, CASE_OBJECT_API_NAME, NAV_ACTION_VIEW } from 'c/fec_CommonConst';
import FEC_Button_Refresh from '@salesforce/label/c.FEC_Button_Refresh';
import FEC_Interactions_Section_Title from '@salesforce/label/c.FEC_Interactions_Section_Title';
import FEC_Interaction_ID from '@salesforce/label/c.FEC_Interaction_ID';
import FEC_Interaction_Status_Label from '@salesforce/label/c.FEC_Interaction_Status_Label';
import FEC_Interaction_Created_On_Label from '@salesforce/label/c.FEC_Interaction_Created_On_Label';
import FEC_Last_Updated_On_Label from '@salesforce/label/c.FEC_Last_Updated_On_Label';
import FEC_Interaction_Duration_Label from '@salesforce/label/c.FEC_Interaction_Duration_Label';
import FEC_Interaction_Phone_Label from '@salesforce/label/c.FEC_Interaction_Phone_Label';
import FEC_Interaction_Channel_Label from '@salesforce/label/c.FEC_Interaction_Channel_Label';
import FEC_Interaction_Sub_Channel_Label from '@salesforce/label/c.FEC_Interaction_Sub_Channel_Label';

export default class Fec_InteractionCases extends NavigationMixin(LightningElement) {
  @track data = [];
  @track lastRefreshTime = null;
  @track isLoading = false;
  @track error;

  sortedBy = 'interactionCreatedOnFormatted';

  activeSections = ['interactions'];

  emptyMessage = MSG_NO_RESULTS;

  customLabel = {
    sectionTitle: FEC_Interactions_Section_Title,
    refresh: FEC_Button_Refresh,
    interactionIdLabel: FEC_Interaction_ID,
    interactionStatusLabel: FEC_Interaction_Status_Label,
    interactionCreatedOnLabel: FEC_Interaction_Created_On_Label,
    lastUpdatedOnLabel: FEC_Last_Updated_On_Label,
    interactionDurationLabel: FEC_Interaction_Duration_Label,
    interactionPhoneLabel: FEC_Interaction_Phone_Label,
    interactionChannelLabel: FEC_Interaction_Channel_Label,
    interactionSubChannelLabel: FEC_Interaction_Sub_Channel_Label,
  };

  _helpTexts = {};
  get _baseInteractionColumns() {
    return [
      {
        label: this.customLabel.interactionIdLabel,
        fieldName: 'interactionIdText',
        fieldApiName: 'FEC_ID_Search__c',
        type: 'link',
        recordIdField: 'Id',
        hoverTitle: this.customLabel.sectionTitle,
        cellAlign: 'center',
        hoverFields: [
          { label: this.customLabel.interactionIdLabel, fieldName: 'interactionIdText' },
          { label: this.customLabel.interactionStatusLabel, fieldName: 'interactionStatus' },
          { label: this.customLabel.interactionCreatedOnLabel, fieldName: 'interactionCreatedOnFormatted' },
          { label: this.customLabel.lastUpdatedOnLabel, fieldName: 'lastUpdatedOnFormatted' },
          { label: this.customLabel.interactionDurationLabel, fieldName: 'interactionDurationFormatted' },
          { label: this.customLabel.interactionPhoneLabel, fieldName: 'interactionPhone' },
          { label: this.customLabel.interactionChannelLabel, fieldName: 'channel' },
          { label: this.customLabel.interactionSubChannelLabel, fieldName: 'interactionSubChannel' },
        ],
      },
      { label: this.customLabel.interactionStatusLabel, fieldName: 'interactionStatus', fieldApiName: 'FEC_Interaction_Status__c', type: 'text', cellAlign: 'center' },
      { label: this.customLabel.interactionCreatedOnLabel, fieldName: 'interactionCreatedOnFormatted', fieldApiName: 'FEC_Created_On__c', type: 'text', cellAlign: 'center' },
      { label: this.customLabel.lastUpdatedOnLabel, fieldName: 'lastUpdatedOnFormatted', fieldApiName: 'FEC_Last_Updated_On_View__c', type: 'text', cellAlign: 'center' },
      { label: this.customLabel.interactionDurationLabel, fieldName: 'interactionDurationFormatted', fieldApiName: 'FEC_Interaction_Duration__c', type: 'text', cellAlign: 'center' },
      { label: this.customLabel.interactionPhoneLabel, fieldName: 'interactionPhone', fieldApiName: 'FEC_Phone_Number__c', type: 'eye', eyeMaskType: 'phone', cellAlign: 'center' },
      { label: this.customLabel.interactionChannelLabel, fieldName: 'channel', fieldApiName: 'FEC_Channel__c', type: 'text', cellAlign: 'center' },
      { label: this.customLabel.interactionSubChannelLabel, fieldName: 'interactionSubChannel', fieldApiName: 'FEC_Interaction_Subchannel__c', type: 'text' },
    ];
  }

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
        interactionIdText: row.interactionIdText || STR_EMPTY,
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
        objectApiName: CASE_OBJECT_API_NAME,
        actionName: NAV_ACTION_VIEW,
      },
    });
  }

  handleSensitiveLog(event) {
    const recordId = event.detail?.recordId;
    logSensitiveAccess({
      fieldName: this.customLabel.interactionPhoneLabel,
      caseId: recordId,
    }).catch((e) => {
      console.error('Sensitive log failed', e);
    });
  }

  get showTable() {
    return !this.isLoading && !this.error;
  }
}