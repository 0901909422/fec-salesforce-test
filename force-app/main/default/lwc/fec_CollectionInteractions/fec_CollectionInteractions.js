import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import COLLECTION_DATE_FILTER from '@salesforce/messageChannel/FEC_Collection_Date_Filter__c';
import { STR_EMPTY } from 'c/fec_CommonConst';
import { formatCurrency0 } from 'c/fec_CommonUtils';
import { formatDateField } from 'c/fec_DateFormatter';

import CONTRACT_FIELD from '@salesforce/schema/Case.FEC_Contract_Number__c';
import RT_NAME_FIELD from '@salesforce/schema/Case.RecordType.Name';

import fetchCollectionData from '@salesforce/apex/FEC_FetchCollectionDataServiceCallout.fetchCollectionData';
import fetchCollectionDataWithDates from '@salesforce/apex/FEC_FetchCollectionDataServiceCallout.fetchCollectionDataWithDates';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_No_Data_Application_History from '@salesforce/label/c.FEC_No_Data_Application_History';
import Fetch_Collection_Data_Record_Type_Collection_Interaction from '@salesforce/label/c.Fetch_Collection_Data_Record_Type_Collection_Interaction';
import FEC_Interacted_Agent_ID from '@salesforce/label/c.FEC_Interacted_Agent_ID';
import FEC_Interacted_Date from '@salesforce/label/c.FEC_Interacted_Date';
import FEC_Interacted_Code from '@salesforce/label/c.FEC_Interacted_Code';
import FEC_Interacted_Phone from '@salesforce/label/c.FEC_Interacted_Phone';
import FEC_Promised_Repayment_Amount from '@salesforce/label/c.FEC_Promised_Repayment_Amount';
import FEC_Next_Interaction_Date from '@salesforce/label/c.FEC_Next_Interaction_Date';
import FEC_Contacted_Person from '@salesforce/label/c.FEC_Contacted_Person';
import FEC_Due_Reason from '@salesforce/label/c.FEC_Due_Reason';
import FEC_Note from '@salesforce/label/c.FEC_Note';

const CASE_FIELDS = [CONTRACT_FIELD, RT_NAME_FIELD];

const SECTION_LABEL = 'Collection Interactions';

/** Apex → LWC có thể camelCase; dữ liệu interaction đọc từ InteractionHistory. */
function interactionsListFromResponse(response) {
    if (!response || typeof response !== 'object') {
        return [];
    }
    const raw = response.InteractionHistory ?? response.interactionHistory;

    return Array.isArray(raw) ? raw : [];
}

/** Mẫu để test UI (bật Preview trên App Builder) */
const PREVIEW_INTERACTIONS = [
    {
        InteractedAgentsID: 'preview@preview.com',
        InteractedDate: '24/10/2023 10:00:00',
        InteractedCode: 'NAB',
        PhoneNumber: '09061234567',
        PromisedRepaymentAmount: '19,300,000',
        NextInteractionDate: '10/24/2023',
        ContactedPerson: 'CLIENT',
        DueReason: 'N/A',
        OtherNotes: 'KH không bắt máy'
    }
];

export default class Fec_CollectionInteractions extends LightningElement {
    @api recordId;

    /** Bật trên App Builder: bỏ qua API, hiển thị bảng với dữ liệu mẫu (chỉ để test FE). */
    @api previewSampleData = false;

    _contractNumber;
    _recordTypeName;

    /** null = lỗi / không hợp lệ; mảng (có thể rỗng) = tải API thành công */
    @track interactions;
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
    sortedByDescription = FEC_Interacted_Date;

    columns = [
        { label: FEC_Interacted_Agent_ID, fieldName: 'InteractedAgentsID', headerClass: 'header-left' },
        { label: FEC_Interacted_Date, fieldName: 'InteractedDate', headerClass: 'header-center' },
        { label: FEC_Interacted_Code, fieldName: 'InteractedCode', headerClass: 'header-center' },
        {
            label: FEC_Interacted_Phone,
            fieldName: 'PhoneNumber',
            type: 'eye',
            cellAlign: 'center',
            headerClass: 'header-center'
        },
        { label: FEC_Promised_Repayment_Amount, fieldName: 'PromisedRepaymentAmount', headerClass: 'header-right', cellAlign: 'right' },
        { label: FEC_Next_Interaction_Date, fieldName: 'NextInteractionDate', headerClass: 'header-center' },
        { label: FEC_Contacted_Person, fieldName: 'ContactedPerson', headerClass: 'header-center' },
        { label: FEC_Due_Reason, fieldName: 'DueReason', headerClass: 'header-left' },
        { label: FEC_Note, fieldName: 'OtherNotes', headerClass: 'header-left' }
    ];

    connectedCallback() {
        if (this.previewSampleData) {
            this.interactions = PREVIEW_INTERACTIONS.map((r) => ({ ...r }));
            this.isLoading = false;
            return;
        }
        this._subscription = subscribe(
            this.messageContext,
            COLLECTION_DATE_FILTER,
            (msg) => {
                this._startDate = msg.startDate;
                this._endDate = msg.endDate;
                this._hasApplied = true;
                this.loadInteractions();
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
        if (this.previewSampleData) {
            this.interactions = PREVIEW_INTERACTIONS.map((r) => ({ ...r }));
            this.isLoading = false;
            return;
        }
        if (data) {
            this._contractNumber = data.fields.FEC_Contract_Number__c?.value;
            this._recordTypeName = data.fields.RecordType?.displayValue;
            // Không tự gọi API — chờ user ấn Apply
        } else if (error) {
            this.interactions = null;
            this.isLoading = false;
        }
    }

    async loadInteractions() {
        if (this.previewSampleData) {
            this.interactions = PREVIEW_INTERACTIONS.map((r) => ({ ...r }));
            this.isLoading = false;
            return;
        }

        if (!this._hasApplied) return;

        this.isLoading = true;

        try {
            if (!this._contractNumber || !this._recordTypeName) {
                this.interactions = null;
                return;
            }
            const response = this._startDate && this._endDate
                ? await fetchCollectionDataWithDates({
                    contractNumber: this._contractNumber,
                    recordType: Fetch_Collection_Data_Record_Type_Collection_Interaction,
                    startDate: this._startDate,
                    endDate: this._endDate
                })
                : await fetchCollectionData({
                    contractNumber: this._contractNumber,
                    recordType: Fetch_Collection_Data_Record_Type_Collection_Interaction
                });

            if (!response || response.Success === false) {
                this.interactions = null;
            } else {
                // Nếu Success = true, luôn set array (rỗng nếu không có data)
                this.interactions = interactionsListFromResponse(response);
            }
        } catch (e) {
            this.interactions = null;
        } finally {
            this.isLoading = false;
            // API OK (mảng có hoặc rỗng): luôn mở section — giống NFU / các khối collection khác
            if (this._hasApplied) this.isExpanded = Array.isArray(this.interactions);
        }
    }

    get showCollapsed() {
        return !this.isLoading && !this._hasApplied;
    }

    get showErrorBanner() {
        return !this.isLoading && this._hasApplied && this.interactions === null;
    }

    get showDataSection() {
        return !this.isLoading && this._hasApplied && Array.isArray(this.interactions);
    }

    /** Bản ghi cho fec_RelatedListPaging — cần Id ổn định */
    get recordsForTable() {
        if (!Array.isArray(this.interactions)) {
            return [];
        }
        return this.interactions.map((row, idx) => ({
            Id: `ci-${idx}`,
            InteractedAgentsID: row?.InteractedAgentsID ?? STR_EMPTY,
            InteractedDate: formatDateField(row?.InteractedDate),
            InteractedCode: row?.InteractedCode ?? STR_EMPTY,
            PhoneNumber: row?.PhoneNumber ?? STR_EMPTY,
            PromisedRepaymentAmount: formatCurrency0(row?.PromisedRepaymentAmount, {
                emptyDisplay: STR_EMPTY,
                integerMode: 'trunc'
            }),
            NextInteractionDate: formatDateField(row?.NextInteractionDate),
            ContactedPerson: row?.ContactedPerson ?? STR_EMPTY,
            DueReason: row?.DueReason ?? STR_EMPTY,
            OtherNotes: row?.OtherNotes ?? STR_EMPTY
        }));
    }

    handleToggle() {
        this.isExpanded = !this.isExpanded;
    }

    get sectionClass() {
        return this.isExpanded ? 'slds-accordion__section slds-is-open' : 'slds-accordion__section';
    }

    get iconName() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }
}