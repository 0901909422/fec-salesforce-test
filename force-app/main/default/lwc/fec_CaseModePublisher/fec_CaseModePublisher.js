import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { publish, MessageContext } from 'lightning/messageService';
import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import clearCreatedFromSearchFlag from '@salesforce/apex/FEC_CaseInitUpdateService.clearCreatedFromSearchFlag';

import IS_CREATED_FROM_SEARCH_FIELD from '@salesforce/schema/Case.FEC_Is_Created_From_Search__c';

const FIELDS = [IS_CREATED_FROM_SEARCH_FIELD];

export default class Fec_CaseModePublisher extends LightningElement {
    @api recordId;
    _hasProcessed = false; // Biến cờ để đảm bảo chỉ chạy logic 1 lần

    @wire(MessageContext)
    messageContext;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredCase({ error, data }) {
        if (data && !this._hasProcessed) {
            const isCreatedFromSearch = getFieldValue(data, IS_CREATED_FROM_SEARCH_FIELD);
            
            // Nếu field đang là true (hoặc logic bạn muốn check trước khi chạy)
            if (isCreatedFromSearch === true) {
                this._hasProcessed = true; // Đánh dấu đã xử lý ngay lập tức
                this.handleUpdateAndPublish();
            }
        } else if (error) {
            console.error('Error retrieving case data:', error);
        }
    }

    handleUpdateAndPublish() {
        clearCreatedFromSearchFlag({ caseId: this.recordId })
            .then(() => {
                console.log('Record updated successfully');
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                setTimeout(() => {
                    try {
                        const payload = {
                            isModeEdit: true
                        };
                        publish(this.messageContext, IS_MODE_EDIT, payload);
                        console.log('Message published with payload:', payload);
                    } catch (error) {
                        console.error('Error in update/publish process:', error);
                    }
                }, 500);
            })
            .catch((error) => {
                console.error('Error clearing created-from-search flag:', error);
            });
    }
}