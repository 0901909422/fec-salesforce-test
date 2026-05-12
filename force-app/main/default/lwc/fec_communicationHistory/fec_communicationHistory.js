import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import COLLECTION_DATE_FILTER from '@salesforce/messageChannel/FEC_Collection_Date_Filter__c';
import { STR_EMPTY } from 'c/fec_CommonConst';
import { formatDateField, sortByDefaultDateFieldDesc } from 'c/fec_DateFormatter';

import CONTRACT_FIELD from '@salesforce/schema/Case.FEC_Contract_Number__c';
import RT_NAME_FIELD from '@salesforce/schema/Case.RecordType.Name';

import fetchCollectionData from '@salesforce/apex/FEC_FetchCollectionDataServiceCallout.fetchCollectionData';
import fetchCollectionDataWithDates from '@salesforce/apex/FEC_FetchCollectionDataServiceCallout.fetchCollectionDataWithDates';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_No_Data_Application_History from '@salesforce/label/c.FEC_No_Data_Application_History';
import Fetch_Collection_Data_Record_Type_Communication_History from '@salesforce/label/c.Fetch_Collection_Data_Record_Type_Communication_History';
import FEC_Account_Contract_Number from '@salesforce/label/c.FEC_Account_Contract_Number';
import FEC_Communication_Type from '@salesforce/label/c.FEC_Communication_Type';
import FEC_Communication_Template from '@salesforce/label/c.FEC_Communication_Template';
import FEC_Campaign_Name from '@salesforce/label/c.FEC_Campaign_Name';
import FEC_Phone_Number from '@salesforce/label/c.FEC_Phone_Number';
import FEC_Communication_Date from '@salesforce/label/c.FEC_Communication_Date';
import FEC_Address from '@salesforce/label/c.FEC_Address';

import { PREVIEW_COMMUNICATION_HISTORY } from './fec_communicationHistoryPreviewData';

const CASE_FIELDS = [CONTRACT_FIELD, RT_NAME_FIELD];

const SECTION_LABEL = 'Communication History';

export default class Fec_communicationHistory extends LightningElement {
    @api recordId;

    /**
     * App Builder / test: luồng hiển thị giống production (chờ Apply…).
     * Khi true, lần load sau Apply không gọi Apex mà trả dữ liệu từ PREVIEW_COMMUNICATION_HISTORY.
     */
    @api previewSampleData = false;

    _contractNumber;
    _recordTypeName;

    /** null = lỗi / không hợp lệ; mảng (có thể rỗng) = tải API thành công */
    @track communicationHistories;
    @track isLoading = false;
    @track isExpanded = false;

    _startDate = null;
    _endDate = null;
    _subscription = null;
    /** Chỉ gọi API sau khi user ấn Apply lần đầu */
    _hasApplied = false;

    @wire(MessageContext)
    messageContext;

    sectionTitleText = SECTION_LABEL;
    labelMsgApiError = FEC_MSG_Error_API_Label;
    labelNoData = FEC_No_Data_Application_History;
    sortedByDescription = FEC_Communication_Date;

    columns = [
        { label: FEC_Account_Contract_Number, fieldName: 'ContractNumber', headerClass: 'header-left' },
        { label: FEC_Communication_Type, fieldName: 'CommunicationType', headerClass: 'header-center' },
        { label: FEC_Communication_Template, fieldName: 'Template', headerClass: 'header-left' },
        { label: FEC_Campaign_Name, fieldName: 'CampaignName', headerClass: 'header-left' },
        {
            label: FEC_Phone_Number,
            fieldName: 'PhoneNumber',
            type: 'eye',
            cellAlign: 'center',
            headerClass: 'header-center'
        },
        { label: FEC_Communication_Date, fieldName: 'CommunicatedDate', headerClass: 'header-center' },
        { label: FEC_Address, fieldName: 'Address2', headerClass: 'header-left' }
    ];

    connectedCallback() {
        this._subscription = subscribe(
            this.messageContext,
            COLLECTION_DATE_FILTER,
            (msg) => {
                this._startDate = msg.startDate;
                this._endDate = msg.endDate;
                this._hasApplied = true;
                this.loadCommunicationHistory();
            },
            { scope: APPLICATION_SCOPE }
        );
    }

    disconnectedCallback() {
        unsubscribe(this._subscription);
        this._subscription = null;
    }

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase({ data, error }) {
        if (data) {
            this._contractNumber = data.fields.FEC_Contract_Number__c?.value;
            this._recordTypeName = data.fields.RecordType?.displayValue;
            // Không tự gọi API — chờ user ấn Apply
        } else if (error) {
            this.communicationHistories = null;
            this.isLoading = false;
        }
    }

    async loadCommunicationHistory() {
        if (!this._hasApplied) return;

        this.isLoading = true;

        try {
            if (!this._contractNumber || !this._recordTypeName) {
                this.communicationHistories = null;
                return;
            }

            if (this.previewSampleData) {
                this.communicationHistories = PREVIEW_COMMUNICATION_HISTORY.map((r) => ({ ...r }));
                return;
            }

            const response = this._startDate && this._endDate
                ? await fetchCollectionDataWithDates({
                    contractNumber: this._contractNumber,
                    recordType: Fetch_Collection_Data_Record_Type_Communication_History,
                    startDate: this._startDate,
                    endDate: this._endDate
                })
                : await fetchCollectionData({
                    contractNumber: this._contractNumber,
                    recordType: Fetch_Collection_Data_Record_Type_Communication_History
                });

            if (!response || response.Success === false) {
                this.communicationHistories = null;
            } else {
                const list = response.CommunicationHistory;
                // Nếu Success = true, luôn set array (rỗng nếu không có data)
                this.communicationHistories = Array.isArray(list) ? list : [];
            }
        } catch (e) {
            this.communicationHistories = null;
        } finally {
            this.isLoading = false;
            if (this._hasApplied) {
                this.isExpanded = Array.isArray(this.communicationHistories);
            }
        }
    }

    get showCollapsed() {
        return !this.isLoading && !this._hasApplied;
    }

    get showErrorBanner() {
        return !this.isLoading && this._hasApplied && this.communicationHistories === null;
    }

    get showDataSection() {
        return (
            !this.isLoading &&
            Array.isArray(this.communicationHistories) &&
            this._hasApplied
        );
    }

    /** Bản ghi cho fec_RelatedListPaging — cần Id ổn định */
    get recordsForTable() {
        if (!Array.isArray(this.communicationHistories)) {
            return [];
        }
        const sorted = sortByDefaultDateFieldDesc(this.communicationHistories, 'CommunicatedDate');
        return sorted.map((row, idx) => ({
            Id: `ch-${idx}`,
            ContractNumber: row?.ContractNumber ?? STR_EMPTY,
            CommunicationType: row?.CommunicationType ?? STR_EMPTY,
            Template: row?.Template ?? STR_EMPTY,
            CampaignName: row?.CampaignName ?? STR_EMPTY,
            PhoneNumber: row?.PhoneNumber ?? STR_EMPTY,
            CommunicatedDate: formatDateField(row?.CommunicatedDate),
            Address2: row?.Address2 ?? STR_EMPTY
        }));
    }

    handleToggle() {
        this.isExpanded = !this.isExpanded;
    }

    get sectionClass() {
        return `slds-accordion__section${this.isExpanded ? ' slds-is-open' : ''}`;
    }

    get iconName() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }
}