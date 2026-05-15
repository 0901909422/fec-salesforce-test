import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { deleteRecord, getRecord } from 'lightning/uiRecordApi';
import { publish, MessageContext } from 'lightning/messageService';
import { loadStyle } from 'lightning/platformResourceLoader';
import FEC_RA_EDIT_MODE from '@salesforce/messageChannel/FEC_RA_Edit_Mode__c';
import FEC_CommonCss from '@salesforce/resourceUrl/FEC_CommonCss';

const FIELDS = ['FEC_Routing_Assignment__c.Name'];

export default class Fec_RoutingAssignmentActions extends NavigationMixin(LightningElement) {
    @api recordId;
    @wire(MessageContext) messageContext;

    recordName;
    showDeleteModal = false;

    connectedCallback() {
        loadStyle(this, FEC_CommonCss);
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ data }) {
        if (data) this.recordName = data.fields.Name?.value;
    }

    handleEdit() {
        publish(this.messageContext, FEC_RA_EDIT_MODE, { recordId: this.recordId });
    }

    handleDelete() {
        this.showDeleteModal = true;
    }

    closeDeleteModal() {
        this.showDeleteModal = false;
    }

    async confirmDelete() {
        this.showDeleteModal = false;
        try {
            await deleteRecord(this.recordId);
            this.dispatchEvent(new ShowToastEvent({ title: 'Thành công', message: 'Đã xóa Routing Assignment.', variant: 'success' }));
            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: { objectApiName: 'FEC_Routing_Assignment__c', actionName: 'list' },
                state: { filterName: 'All' }
            });
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Lỗi', message: e?.body?.message || 'Lỗi khi xóa.', variant: 'error' }));
        }
    }
}
