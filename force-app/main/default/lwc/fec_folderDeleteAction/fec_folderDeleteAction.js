import { LightningElement, api, track } from 'lwc';
import { deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Import Custom Labels
import FEC_Delete_Folder_Title from '@salesforce/label/c.FEC_Delete_Folder_Title';
import FEC_Delete_Folder_Confirmation from '@salesforce/label/c.FEC_Delete_Folder_Confirmation';
import FEC_Cancel_Button from '@salesforce/label/c.FEC_Button_Cancel';
import FEC_Delete_Button from '@salesforce/label/c.FEC_Delete_Button';
import FEC_Success_Message from '@salesforce/label/c.FEC_Success_Message';
import FEC_Delete_Email_Template_Title from '@salesforce/label/c.FEC_Delete_Email_Template_Title';
import FEC_Delete_Email_Template_Confirmation from '@salesforce/label/c.FEC_Delete_Email_Template_Confirmation';
import FEC_Success_Message_Email from '@salesforce/label/c.FEC_Success_Message_Email';

export default class Fec_folderDeleteAction extends LightningElement {
    @api recordId; // The ID of the folder/record to delete
    @api name;
    // @api type;
    @track isLoading = false;

    // Mapping labels for HTML
    label = { };

    _type; // Private variable to hold the value

    @api
    get type() { // Getter
        return this._type;
    }

    set type(value) { // Setter
        this._type = value;
        const _label = {
            title: this.type === 'template' ? FEC_Delete_Email_Template_Title : FEC_Delete_Folder_Title,
            confirmation: this.type === 'template' ? FEC_Delete_Email_Template_Confirmation : FEC_Delete_Folder_Confirmation,
            cancel: FEC_Cancel_Button,
            delete: FEC_Delete_Button,
            success: this.type === 'template' ? FEC_Success_Message_Email : FEC_Success_Message
        };
        this.label = _label;
    }

    // 1. Dispatch Close Event (User clicked Cancel or X)
    handleCancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    // 2. Dispatch Save/Success Event (After successful deletion)
    handleDelete() {
        this.isLoading = true;
        
        deleteRecord(this.recordId)
            .then(() => {
                this.isLoading = false;
                this.showToast('', this.label.success.replace('MERGE_FIELD_NAME', this.name), 'success');
                
                // Signal to parent that data has changed and modal should close
                this.dispatchEvent(new CustomEvent('savesuccess', {
                    detail: { recordId: this.recordId }
                }));
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('', error.body.message, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}