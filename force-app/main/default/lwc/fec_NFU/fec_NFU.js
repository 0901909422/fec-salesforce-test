import { LightningElement, api, wire, track } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import COLLECTION_DATE_FILTER from '@salesforce/messageChannel/FEC_Collection_Date_Filter__c';
import { STR_EMPTY } from 'c/fec_CommonConst';
import CONTRACT_FIELD from '@salesforce/schema/Case.FEC_Contract_Number__c';
import RT_NAME_FIELD from '@salesforce/schema/Case.RecordType.Name';

import fetchCollectionData from '@salesforce/apex/FEC_FetchCollectionDataServiceCallout.fetchCollectionData';
import fetchCollectionDataWithDates from '@salesforce/apex/FEC_FetchCollectionDataServiceCallout.fetchCollectionDataWithDates';
import FEC_MSG_Error_API_Label from '@salesforce/label/c.FEC_MSG_Error_API_Label';
import FEC_NFUStatus from '@salesforce/label/c.FEC_NFUStatus';
import FEC_NFUStartDate from '@salesforce/label/c.FEC_NFUStartDate';
import FEC_NFU_Reason from '@salesforce/label/c.FEC_NFU_Reason';
import FEC_NFU_Code from '@salesforce/label/c.FEC_NFU_Code';
import FEC_NFUExpiryDate from '@salesforce/label/c.FEC_NFUExpiryDate';

const FIELDS = [CONTRACT_FIELD, RT_NAME_FIELD];

const SECTION_LABEL = 'NFU';
const EMPTY = '-';

/** Mẫu để test UI (bật Preview trên App Builder) */
const PREVIEW_NFU = {
    NFUStatus: 'No',
    NFUStartDate: '05/01/2024 05:01:10',
    NFUExpiryDate: '06/01/2024 05:01:10',
    NFUCode: 'CS_NFU_COMPLAINT30',
    NFUReason: 'KH khiếu nại và cần xác minh từ các Đơn vị liên quan'
};

export default class Fec_NFU extends LightningElement {
    @api recordId;

    /** Bật trên App Builder: bỏ qua API, hiển thị lưới với dữ liệu mẫu (chỉ để test FE). */
    @api previewSampleData = false;

    _contractNumber;
    _recordTypeName;

    @track nfuData;
    @track isLoading = true;

    _startDate = null;
    _endDate = null;
    _subscription = null;

    @wire(MessageContext)
    messageContext;

    sectionTitleText = SECTION_LABEL;
    labelMsgApiError = FEC_MSG_Error_API_Label;

    connectedCallback() {
        if (this.previewSampleData) {
            this.nfuData = { ...PREVIEW_NFU };
            this.isLoading = false;
            return;
        }
        this._subscription = subscribe(
            this.messageContext,
            COLLECTION_DATE_FILTER,
            (msg) => {
                this._startDate = msg.startDate;
                this._endDate = msg.endDate;
                this.loadNfu();
            },
            { scope: APPLICATION_SCOPE }
        );
    }

    disconnectedCallback() {
        unsubscribe(this._subscription);
        this._subscription = null;
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredCase({ data, error }) {
        if (this.previewSampleData) {
            this.nfuData = { ...PREVIEW_NFU };
            this.isLoading = false;
            return;
        }
        if (data) {
            this._contractNumber = data.fields.FEC_Contract_Number__c?.value;
            this._recordTypeName = data.fields.RecordType?.displayValue;
            this.loadNfu();
        } else if (error) {
            this.nfuData = null;
            this.isLoading = false;
        }
    }

    async loadNfu() {
        if (this.previewSampleData) {
            this.nfuData = { ...PREVIEW_NFU };
            this.isLoading = false;
            return;
        }

        this.isLoading = true;

        try {
            if (!this._contractNumber || !this._recordTypeName) {
                this.nfuData = null;
                return;
            }

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

            if (!response || response.Success === false || !response.NFUDetailsList || response.NFUDetailsList.length === 0) {
                this.nfuData = null;
            } else {
                this.nfuData = response.NFUDetailsList[0];
            }
        } catch (e) {
            this.nfuData = null;
        } finally {
            this.isLoading = false;
        }
    }

    get nfuFields() {
        const d = this.nfuData;
        if (!d) {
            return [];
        }

        const val = (api) => {
            const raw = d[api];
            return raw != null && String(raw).trim() !== STR_EMPTY ? raw : EMPTY;
        };

        return [
            this.buildField('NFUStatus', FEC_NFUStatus, val('NFUStatus')),
            this.buildField('NFUStartDate', FEC_NFUStartDate, val('NFUStartDate')),
            this.buildField('NFUReason', FEC_NFU_Reason, val('NFUReason')),
            this.buildField('NFUCode', FEC_NFU_Code, val('NFUCode')),
            this.buildField('NFUExpiryDate', FEC_NFUExpiryDate, val('NFUExpiryDate'))
        ];
    }

    buildField(key, label, value) {
        return { key, label, value };
    }
}