import { LightningElement, api, wire, track } from 'lwc';
import { getRelatedListRecords } from 'lightning/uiRelatedListApi';
import {FEC_ERROR_LOADING_ORIGINAL_INFORMATION } from "c/fec_CommonConst";
export default class Fec_OriginalInformation extends LightningElement {
    // Standard properties passed by fec_CaseBussiness dynamic loader
    @api recordId;
    @api subCodeCode;
    @api isEdit;
    @api isHiddenLwc;

    @track fieldList = [];
    error;
    label = {
        FEC_ERROR_LOADING_ORIGINAL_INFORMATION
    }
    @wire(getRelatedListRecords, {
        parentRecordId: '$recordId',
        relatedListId: 'Case_Flow_History__r',
        fields: ['FEC_Case_Flow_History__c.FEC_Field_List__c', 'FEC_Case_Flow_History__c.CreatedDate'],
        sortBy: ['-FEC_Case_Flow_History__c.CreatedDate']
    })
    wiredHistory({ error, data }) {
        if (data) {
            this.error = undefined;
            if (data.records && data.records.length > 0) {
                // The records are already sorted by the wire adapter (descending)
                const latestRecord = data.records[0];
                const fieldListStr = latestRecord.fields.FEC_Field_List__c.value;
                
                if (fieldListStr) {
                    try {
                        const parsedList = JSON.parse(fieldListStr);
                        
                        this.fieldList = parsedList.map((item, index) => {
                            return {
                                id: `field-${index}`,
                                label: item.label,
                                value: item.value,
                                objectName: item.objectName,
                                apiName: item.apiName
                            };
                        });
                    } catch (e) {
                        console.error('[fec_OriginalInformation] Error parsing FEC_Field_List__c: ', e);
                        this.fieldList = [];
                    }
                } else {
                    this.fieldList = [];
                }
            } else {
                this.fieldList = [];
            }
        } else if (error) {
            this.error = error;
            this.fieldList = [];
            console.error('[fec_OriginalInformation] Error fetching flow history: ', error);
        }
    }
}
