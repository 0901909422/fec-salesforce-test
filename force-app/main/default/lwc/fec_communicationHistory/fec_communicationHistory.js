import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { STR_EMPTY } from 'c/fec_CommonConst';

import CONTRACT_FIELD from '@salesforce/schema/Case.FEC_Contract_Number__c';
import RT_NAME_FIELD from '@salesforce/schema/Case.RecordType.Name';

import fetchCollectionData from '@salesforce/apex/FEC_FetchCollectionDataServiceCallout.fetchCollectionData';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Account_Contract_Number from '@salesforce/label/c.FEC_Account_Contract_Number';
import FEC_Communication_Type from '@salesforce/label/c.FEC_Communication_Type';
import FEC_Communication_Template from '@salesforce/label/c.FEC_Communication_Template';
import FEC_Campaign_Name from '@salesforce/label/c.FEC_Campaign_Name';
import FEC_Phone_Number from '@salesforce/label/c.FEC_Phone_Number';
import FEC_Communication_Date from '@salesforce/label/c.FEC_Communication_Date';
import FEC_Address from '@salesforce/label/c.FEC_Address';

const CASE_FIELDS = [CONTRACT_FIELD, RT_NAME_FIELD];

const SECTION_LABEL = 'Communication History';

/** Mẫu để test UI (bật Preview trên App Builder) */
const PREVIEW_COMMUNICATION_HISTORY = [
    {
        ContractNumber: 'HD-2024-001234',
        CommunicationType: 'SMS',
        Template: 'PAYMENT_REMINDER_V2',
        CampaignName: 'Thu hồi nợ T4/2026',
        PhoneNumber: '09061234567',
        CommunicatedDate: '13/04/2026 09:15:00',
        Address2: '123 Nguyễn Huệ, Q.1, TP.HCM'
    },
    {
        ContractNumber: 'HD-2024-001234',
        CommunicationType: 'Email',
        Template: 'LEGAL_NOTICE_STD',
        CampaignName: 'Nhắc nợ Level 2',
        PhoneNumber: STR_EMPTY,
        CommunicatedDate: '05/04/2026 14:00:00',
        Address2: '—'
    }
];

export default class Fec_communicationHistory extends LightningElement {
    @api recordId;

    /** Bật trên App Builder: bỏ qua API, hiển thị bảng với dữ liệu mẫu (chỉ để test FE). */
    @api previewSampleData = false;

    _contractNumber;
    _recordTypeName;

    /** null = lỗi / không hợp lệ; mảng (có thể rỗng) = tải API thành công */
    @track communicationHistories;
    @track isLoading = true;

    sectionTitleText = SECTION_LABEL;
    labelMsgApiError = FEC_MSG_Error_API_Label;
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
        if (this.previewSampleData) {
            this.communicationHistories = PREVIEW_COMMUNICATION_HISTORY.map((r) => ({ ...r }));
            this.isLoading = false;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase({ data, error }) {
        if (this.previewSampleData) {
            this.communicationHistories = PREVIEW_COMMUNICATION_HISTORY.map((r) => ({ ...r }));
            this.isLoading = false;
            return;
        }
        if (data) {
            this._contractNumber = data.fields.FEC_Contract_Number__c?.value;
            this._recordTypeName = data.fields.RecordType?.displayValue;
            this.loadCommunicationHistory();
        } else if (error) {
            this.communicationHistories = null;
            this.isLoading = false;
        }
    }

    async loadCommunicationHistory() {
        if (this.previewSampleData) {
            this.communicationHistories = PREVIEW_COMMUNICATION_HISTORY.map((r) => ({ ...r }));
            this.isLoading = false;
            return;
        }

        this.isLoading = true;

        try {
            if (!this._contractNumber || !this._recordTypeName) {
                this.communicationHistories = null;
                return;
            }

            const response = await fetchCollectionData({
                contractNumber: this._contractNumber,
                recordType: this._recordTypeName
            });

            if (!response || response.Success === false) {
                this.communicationHistories = null;
            } else {
                const list = response.CommunicationHistory;
                this.communicationHistories = Array.isArray(list) ? list : null;
            }
        } catch (e) {
            this.communicationHistories = null;
        } finally {
            this.isLoading = false;
        }
    }

    get showErrorBanner() {
        return !this.isLoading && this.communicationHistories === null;
    }

    get showDataSection() {
        return !this.isLoading && Array.isArray(this.communicationHistories);
    }

    /** Bản ghi cho fec_RelatedListPaging — cần Id ổn định */
    get recordsForTable() {
        if (!Array.isArray(this.communicationHistories)) {
            return [];
        }
        return this.communicationHistories.map((row, idx) => ({
            Id: `ch-${idx}`,
            ContractNumber: row?.ContractNumber ?? STR_EMPTY,
            CommunicationType: row?.CommunicationType ?? STR_EMPTY,
            Template: row?.Template ?? STR_EMPTY,
            CampaignName: row?.CampaignName ?? STR_EMPTY,
            PhoneNumber: row?.PhoneNumber ?? STR_EMPTY,
            CommunicatedDate: row?.CommunicatedDate ?? STR_EMPTY,
            Address2: row?.Address2 ?? STR_EMPTY
        }));
    }
}