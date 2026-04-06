import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getAvailableNotifications from '@salesforce/apex/FEC_Notification.getAvailableNotifications';
import sendManualEmail from '@salesforce/apex/FEC_Notification.sendManualEmail';
import getTemplate from '@salesforce/apex/FEC_TemplateController.getTemplate';
import labelSendManualNotification from '@salesforce/label/c.FEC_Send_Manual_Notification';
import LBL_SFT_Notification_Type from '@salesforce/label/c.LBL_SFT_Notification_Type';
import FEC_Choose_Notification_Type from '@salesforce/label/c.FEC_Choose_Notification_Type';
import LBL_SFT_Notification_Channel from '@salesforce/label/c.LBL_SFT_Notification_Channel';
import FEC_Target_Email from '@salesforce/label/c.FEC_Target_Email';
import FEC_Target_Group from '@salesforce/label/c.FEC_Target_Group';
import FEC_Action_Preview from '@salesforce/label/c.FEC_Action_Preview';
import FEC_Send from '@salesforce/label/c.FEC_Send';
import FEC_Error_Loading_Template_List from '@salesforce/label/c.FEC_Error_Loading_Template_List';
import FEC_MSG_IPP_AddIpp_Default_Success from '@salesforce/label/c.FEC_MSG_IPP_AddIpp_Default_Success';
import FEC_Email_Sent_Success from '@salesforce/label/c.FEC_Email_Sent_Success';
import FEC_Email_Send_Error from '@salesforce/label/c.FEC_Email_Send_Error';


export default class Fec_ManualNotification extends NavigationMixin(LightningElement) {
    @api recordId; 
    @track options = [];
    @track rawNotifications = [];
    @track _record = null;
    @track _isPreviewOpen = false;

    label = {
        sendManualNotification: labelSendManualNotification,
        LBL_SFT_Notification_Type: LBL_SFT_Notification_Type,
        FEC_Choose_Notification_Type: FEC_Choose_Notification_Type,
        LBL_SFT_Notification_Channel: LBL_SFT_Notification_Channel,
        FEC_Target_Email: FEC_Target_Email,
        FEC_Target_Group: FEC_Target_Group,
        FEC_Action_Preview: FEC_Action_Preview,
        FEC_Send: FEC_Send,
        FEC_Error_Loading_Template_List: FEC_Error_Loading_Template_List,
        FEC_MSG_IPP_AddIpp_Default_Success: FEC_MSG_IPP_AddIpp_Default_Success,
        FEC_Email_Sent_Success: FEC_Email_Sent_Success,
        FEC_Email_Send_Error: FEC_Email_Send_Error
    };
    
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
            this.error = this.label.FEC_Error_Loading_Template_List + ': ' + (error.body ? error.body.message : JSON.stringify(error));
            this.options = undefined;
            this.rawNotifications = [];
        }
    }

    get record() {
        return this._record;
    }

    get notiTypePlaceHolder() {
        return this.label.FEC_Choose_Notification_Type + '...';
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
                        title: this.label.FEC_MSG_IPP_AddIpp_Default_Success,
                        message: this.label.FEC_Email_Sent_Success,
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
                this.error =  this.label.FEC_Email_Send_Error + ': ' + (error.body ? error.body.message : JSON.stringify(error));
            });
    }
}