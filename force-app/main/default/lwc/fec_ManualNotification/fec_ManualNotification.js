import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getAvailableNotifications from '@salesforce/apex/FEC_Notification.getAvailableNotifications';
import sendManualEmail from '@salesforce/apex/FEC_Notification.sendManualEmail';
import getTemplate from '@salesforce/apex/FEC_TemplateController.getTemplate';

export default class Fec_ManualNotification extends NavigationMixin(LightningElement) {
    @api recordId; 
    @track options = [];
    @track rawNotifications = [];
    @track _record = null;
    @track _isPreviewOpen = false;
    
    selectedNotificationId;
    selectedTemplateId;
    selectedChannel = '';
    selectedTargetGroup = '';
    targetEmail = '';
    error;

    @wire(getAvailableNotifications, { caseId: '$recordId' })
    wiredNotifications({ error, data }) {
        if (data) {
            this.rawNotifications = data;
            this.options = data.map(item => {
                return { label: item.label, value: item.value };
            });
            this.error = undefined;
        } else if (error) {
            this.error = 'Lỗi tải danh sách template: ' + (error.body ? error.body.message : JSON.stringify(error));
            this.options = undefined;
            this.rawNotifications = [];
        }
    }

    get record() {
        return this._record;
    }

    handleChange(event) {
        this.selectedNotificationId = event.detail.value;
        
        const selectedItem = this.rawNotifications.find(item => item.value === this.selectedNotificationId);
        
        if (selectedItem) {
            this.selectedChannel = selectedItem.channel;
            this.selectedTemplateId = selectedItem.templateId;
            this.selectedTargetGroup = selectedItem.targetGroup;
            this.targetEmail = selectedItem.targetEmail;
        }
    }

    get isActionDisabled() {
        return !this.selectedNotificationId;
    }

    handleClosePreview() {
        this._isPreviewOpen = false;
    }

    async handlePreview() {
        try {
            const recResult = await getTemplate({ templateId: this.selectedTemplateId });    
            this._record = recResult ? this._mapTemplate(recResult) : null;
            this._isPreviewOpen = true;
        } catch (error) {
            this._record = null;
            // eslint-disable-next-line no-console
            console.error('[templateDetailPage] Error loading template:', error);
        }
        // if (this.selectedTemplateId) {
        //     this[NavigationMixin.Navigate]({
        //         type: 'standard__recordPage',
        //         attributes: {
        //             recordId: this.selectedTemplateId,
        //             objectApiName: 'EmailTemplate',
        //             actionName: 'view'
        //         }
        //     });
        // }
    }

    /**
     * Map FEC_Template__c SObject to a flat UI-friendly object.
     */
    _mapTemplate(rec) {
        const lh = rec.FEC_Enhanced_Letterhead__r;
        return {
            id:                     rec.Id,
            name:                   rec.Name || '',
            apiName:                rec.FEC_API_Name__c || '',
            description:            rec.FEC_Description__c || '',
            folderName:             rec.FEC_Folder__r ? rec.FEC_Folder__r.Name : '',
            isActive:               rec.FEC_Active__c,
            enhancedLetterheadName: lh ? lh.Name : '',
            letterheadHeaderHtml:   lh ? (lh.FEC_Header__c || '') : '',
            letterheadFooterHtml:   lh ? (lh.FEC_Footer__c || '') : '',
            applicableMailbox:      rec.FEC_Applicable_for_Mailbox__c
                ? rec.FEC_Applicable_for_Mailbox__c.split(';')
                : [],
            subject:                rec.FEC_Subject_Line__c || '',
            emailBody:              rec.FEC_Body__c || '',
            lastModifiedBy:         rec.LastModifiedBy ? rec.LastModifiedBy.Name : '',
            lastModifiedById:       rec.LastModifiedById || '',
            lastModifiedDate:       rec.LastModifiedDate
        };
    }

    handleSend() {
        sendManualEmail({ caseId: this.recordId, templateId: this.selectedTemplateId })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Thành công',
                        message: 'Đã gửi email thành công tới khách hàng.',
                        variant: 'success',
                    })
                );
                // Reset states
                this.selectedNotificationId = null; 
                this.selectedTemplateId = null;
                this.selectedChannel = '';
                this.selectedTargetGroup = '';
                this.targetEmail = '';
            })
            .catch(error => {
                this.error = 'Lỗi gửi mail: ' + (error.body ? error.body.message : JSON.stringify(error));
            });
    }
}