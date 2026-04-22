import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { STR_EMPTY } from 'c/fec_CommonConst';

import CONTRACT_FIELD from '@salesforce/schema/Case.FEC_Contract_Number__c';
import RT_NAME_FIELD from '@salesforce/schema/Case.RecordType.Name';

import fetchCollectionData from '@salesforce/apex/FEC_FetchCollectionDataServiceCallout.fetchCollectionData';
import fetchCollectionDataWithDates from '@salesforce/apex/FEC_FetchCollectionDataServiceCallout.fetchCollectionDataWithDates';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_Agent_ID from '@salesforce/label/c.FEC_Agent_ID';
import FEC_Agent_Name from '@salesforce/label/c.FEC_Agent_Name';
import FEC_Allocation_Date from '@salesforce/label/c.FEC_Allocation_Date';
import FEC_Current_Pool from '@salesforce/label/c.FEC_Current_Pool';
import FEC_Current_Sub_Pool from '@salesforce/label/c.FEC_Current_Sub_Pool';
import FEC_Job from '@salesforce/label/c.FEC_Job';
import FEC_DPD from '@salesforce/label/c.FEC_DPD';
import FEC_POS from '@salesforce/label/c.FEC_POS';

const CASE_FIELDS = [CONTRACT_FIELD, RT_NAME_FIELD];

const SECTION_LABEL = 'Allocation History';

/** Mẫu để test UI (bật Preview trên App Builder) */
const PREVIEW_ALLOCATION_HISTORY = [
    {
        AgentID: 'agent001@example.com',
        AgentName: 'Nguyễn Văn A',
        AllocationDate: '13/04/2026 09:30:00',
        CurrentBucket: 'BUCKET_A',
        CurrentSubPool: 'SUB_01',
        Job: 'COLLECTOR',
        DPD: '45',
        POS: '12,500,000'
    },
    {
        AgentID: 'agent002@example.com',
        AgentName: 'Trần Thị B',
        AllocationDate: '01/03/2026 14:15:00',
        CurrentBucket: 'BUCKET_B',
        CurrentSubPool: 'SUB_02',
        Job: 'TEAM_LEAD',
        DPD: '30',
        POS: '8,200,000'
    }
];

export default class Fec_allocationHistory extends LightningElement {
    @api recordId;

    /** Bật trên App Builder: bỏ qua API, hiển thị bảng với dữ liệu mẫu (chỉ để test FE). */
    @api previewSampleData = false;

    _contractNumber;
    _recordTypeName;

    /** null = lỗi / không hợp lệ; mảng (có thể rỗng) = tải API thành công */
    @track allocationHistories;
    @track isLoading = true;

    // startDate/endDate dùng cho API — mặc định null (dùng fetchCollectionData cũ)
    _startDate = null;
    _endDate = null;

    sectionTitleText = SECTION_LABEL;
    labelMsgApiError = FEC_MSG_Error_API_Label;
    sortedByDescription = FEC_Allocation_Date;

    columns = [
        { label: FEC_Agent_ID, fieldName: 'AgentID', sortable: true, headerClass: 'header-left' },
        { label: FEC_Agent_Name, fieldName: 'AgentName', sortable: true, headerClass: 'header-left' },
        { label: FEC_Allocation_Date, fieldName: 'AllocationDate', sortable: true, headerClass: 'header-center' },
        { label: FEC_Current_Pool, fieldName: 'CurrentBucket', sortable: true, headerClass: 'header-center' },
        { label: FEC_Current_Sub_Pool, fieldName: 'CurrentSubPool', sortable: true, headerClass: 'header-center' },
        { label: FEC_Job, fieldName: 'Job', sortable: true, headerClass: 'header-center' },
        { label: FEC_DPD, fieldName: 'DPD', sortable: true, headerClass: 'header-center' },
        { label: FEC_POS, fieldName: 'POS', sortable: true, headerClass: 'header-right', cellAlign: 'right' }
    ];

    connectedCallback() {
        if (this.previewSampleData) {
            this.allocationHistories = PREVIEW_ALLOCATION_HISTORY.map((r) => ({ ...r }));
            this.isLoading = false;
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase({ data, error }) {
        if (this.previewSampleData) {
            this.allocationHistories = PREVIEW_ALLOCATION_HISTORY.map((r) => ({ ...r }));
            this.isLoading = false;
            return;
        }
        if (data) {
            this._contractNumber = data.fields.FEC_Contract_Number__c?.value;
            this._recordTypeName = data.fields.RecordType?.displayValue;
            this.loadAllocationHistory();
        } else if (error) {
            this.allocationHistories = null;
            this.isLoading = false;
        }
    }

    async loadAllocationHistory() {
        if (this.previewSampleData) {
            this.allocationHistories = PREVIEW_ALLOCATION_HISTORY.map((r) => ({ ...r }));
            this.isLoading = false;
            return;
        }

        this.isLoading = true;

        try {
            if (!this._contractNumber || !this._recordTypeName) {
                this.allocationHistories = null;
                return;
            }

            // Nếu có date filter thì dùng fetchCollectionDataWithDates, ngược lại dùng method cũ
            const response = this._startDate && this._endDate
                ? await fetchCollectionDataWithDates({
                    contractNumber: this._contractNumber,
                    recordType: this._recordTypeName,
                    startDate: this._startDate,
                    endDate: this._endDate
                })
                : await fetchCollectionData({
                    contractNumber: this._contractNumber,
                    recordType: this._recordTypeName
                });

            if (!response || response.Success === false) {
                this.allocationHistories = null;
            } else {
                const list = response.AllocationHistory;
                this.allocationHistories = Array.isArray(list) ? list : null;
            }
        } catch (e) {
            this.allocationHistories = null;
        } finally {
            this.isLoading = false;
        }
    }

    // Handler nhận event từ fec_CollectionDateFilter khi user bấm Apply
    handleDateFilterChange(e) {
        this._startDate = e.detail.startDate;
        this._endDate = e.detail.endDate;
        this.loadAllocationHistory();
    }

    get showErrorBanner() {
        return !this.isLoading && this.allocationHistories === null;
    }

    get showDataSection() {
        return !this.isLoading && Array.isArray(this.allocationHistories);
    }

    /** Bản ghi cho fec_RelatedListPaging — cần Id ổn định */
    get recordsForTable() {
        if (!Array.isArray(this.allocationHistories)) {
            return [];
        }
        return this.allocationHistories.map((row, idx) => ({
            Id: `ah-${idx}`,
            AgentID: row?.AgentID ?? STR_EMPTY,
            AgentName: row?.AgentName ?? STR_EMPTY,
            AllocationDate: row?.AllocationDate ?? STR_EMPTY,
            CurrentBucket: row?.CurrentBucket ?? STR_EMPTY,
            CurrentSubPool: row?.CurrentSubPool ?? STR_EMPTY,
            Job: row?.Job ?? STR_EMPTY,
            DPD: row?.DPD ?? STR_EMPTY,
            POS: row?.POS ?? STR_EMPTY
        }));
    }
}