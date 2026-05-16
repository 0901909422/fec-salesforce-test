// tungnm37: New General Assignment - form đơn giản từ list view
import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import saveGeneralAssignment from '@salesforce/apex/FEC_GeneralAssignmentController.saveGeneralAssignment';
import LABEL_SUCCESS from '@salesforce/label/c.FEC_GA_Save_Success';
import LABEL_CREATED from '@salesforce/label/c.FEC_GA_Create_Success_Message';
import LABEL_CREATE_ERROR from '@salesforce/label/c.FEC_GA_Create_Error_Message';
import LABEL_NAME_REQUIRED from '@salesforce/label/c.FEC_GA_Name_Required_Field';
import LABEL_CODE_REQUIRED from '@salesforce/label/c.FEC_GA_Code_Required_Field';

export default class Fec_NewGeneralAssignment extends NavigationMixin(LightningElement) {
    @track generalAssignmentName = '';
    @track generalAssignmentCode = '';
    @track active = true;
    @track errorMsg = '';
    @track isSaving = false;

    connectedCallback() {}

    handleNameChange(e) { 
        this.generalAssignmentName = e.target.value;
        // Auto-fill Code with same value as Name
        this.generalAssignmentCode = e.target.value;
    }
    handleCodeChange(e) { this.generalAssignmentCode = e.target.value; }
    handleActiveChange(e) { this.active = e.target.checked; }

    _navigateToList() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'FEC_General_Assignment_Config__c', actionName: 'list' },
            state: { filterName: 'All' }
        });
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
        this._navigateToList();
    }

    async handleSave() {
        if (!this.generalAssignmentName) { this.errorMsg = LABEL_NAME_REQUIRED; return; }
        if (!this.generalAssignmentCode) { this.errorMsg = LABEL_CODE_REQUIRED; return; }
        this.errorMsg = '';
        this.isSaving = true;
        try {
            const newId = await saveGeneralAssignment({
                nocId: null,
                customerType: null,
                channelIds: null,
                stageId: null,
                generalAssignmentName: this.generalAssignmentName,
                generalAssignmentCode: this.generalAssignmentCode,
                active: this.active
            });
            this.dispatchEvent(new ShowToastEvent({
                title: LABEL_SUCCESS,
                message: LABEL_CREATED,
                variant: 'success'
            }));
            this.dispatchEvent(new CustomEvent('save', { detail: { id: newId } }));
            // Navigate đến record mới (tab sẽ đổi sang record detail)
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: newId, objectApiName: 'FEC_General_Assignment_Config__c', actionName: 'view' }
            });
        } catch (e) {
            this.errorMsg = e?.body?.message || LABEL_CREATE_ERROR;
        } finally {
            this.isSaving = false;
        }
    }
}

