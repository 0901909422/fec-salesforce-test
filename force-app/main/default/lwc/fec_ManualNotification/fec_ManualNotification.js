import { LightningElement, api, wire, track } from 'lwc';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import IS_MODE_EDIT from '@salesforce/messageChannel/FEC_Case_Mode__c';
import CASE_NOC from '@salesforce/messageChannel/FEC_Case_NOC__c';
import getCase from '@salesforce/apex/FEC_CaseEditNOCController.getCase';
import { VIEW_MODE_HANDLING } from 'c/fec_CommonConst';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getAvailableNotifications from '@salesforce/apex/FEC_Notification.getAvailableNotifications';
import sendManualEmail from '@salesforce/apex/FEC_Notification.sendManualEmail';
import previewTemplate from '@salesforce/apex/FEC_Notification.previewTemplate';
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
import fec_UserSearchModal from 'c/fec_UserSearchModal';
import searchInternalUsers from '@salesforce/apex/FEC_Notification.searchInternalUsers';
import { 
    SEARCH_PLACEHOLDER, 
    TARGET_GROUP_INTERNAL_USER,
    SEARCH_INTERNAL_USERS,
    PATTERN_EMAIL_FEC_STRICT,
    MSG_INVALID_EMAIL_FORMAT,
    ERROR_MODAL_TITLE,
    MSG_ENTER_EMAIL_CORRECTLY
} from 'c/fec_CommonConst';


export default class Fec_ManualNotification extends NavigationMixin(LightningElement) {
    @api recordId; 
    @track options = [];
    @track rawNotifications = [];
    @track _record = null;
    @track _isPreviewOpen = false;
    SEARCH_PLACEHOLDER = SEARCH_PLACEHOLDER;

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

    @wire(MessageContext)
    messageContext;
    
    subscriptionMode = null;
    subscriptionNOC = null;
    
    @track modeEditCase = false;
    @track isSubmited = true;
    @track interactionViewMode = '';
    
    @track productTypeId = null;
    @track categoryId = null;
    @track subCategoryId = null;
    @track subCodeId = null;
    @track isDropdownOpen = false;
    @track isSearching = false;
    @track userSearchResults = [];
    @track searchTerm = '';
    searchTimeout;

    // Getter kiểm tra Internal User
    get isInternalUser() {
        return this.selectedTargetGroup === TARGET_GROUP_INTERNAL_USER;
    }

    // Getter kiểm tra kết quả rỗng
    get noResults() {
        return this.userSearchResults.length === 0;
    }

    // get isEdit() {
    //     const defaultEdit = (this.modeEditCase || this.interactionViewMode === VIEW_MODE_HANDLING) ? true : false;
    //     return defaultEdit && !this.isSubmited;
    // }

    async connectedCallback() {
        this.subscribeToMessageChannel();
        try {
            const res = await getCase({ recordId: this.recordId });
            this.isSubmited = res.FEC_Is_Submited__c;
            this.interactionViewMode = res.FEC_Interaction_View_Mode__c;
            this.productTypeId = res.FEC_Product_Type__c;
            this.categoryId = res.FEC_Category__c;
            this.subCategoryId = res.FEC_SubCategory__c;
            this.subCodeId = res.FEC_SubCode__c;
            this.fetchNotifications();
        } catch(error) {
            console.error('Error fetching Case details in fec_ManualNotification: ', error);
        }
    }

    disconnectedCallback() {
        unsubscribe(this.subscriptionMode);
        this.subscriptionMode = null;

        unsubscribe(this.subscriptionNOC);
        this.subscriptionNOC = null;
    }

    subscribeToMessageChannel() {
        this.subscriptionMode = subscribe(
            this.messageContext,
            IS_MODE_EDIT,
            (message) => this.handleModeMessage(message),
            { scope: APPLICATION_SCOPE }
        );

        this.subscriptionNOC = subscribe(
            this.messageContext,
            CASE_NOC,
            (message) => this.handleNOCMessage(message),
            { scope: APPLICATION_SCOPE }
        );
    }

    handleModeMessage(message) {
        if (!message || typeof message.isModeEdit === 'undefined') return;
        this.modeEditCase = message.isModeEdit === true;
    }

    handleNOCMessage(message) {
        if (!message) return;
        this.productTypeId = message?.productTypeId;
        this.categoryId = message?.categoryId;
        this.subCategoryId = message?.subCategoryId;
        this.subCodeId = message?.subCodeId;
        this.fetchNotifications();
    }

    async fetchNotifications() {
        if (!this.recordId) return;
        try {
            const data = await getAvailableNotifications({ 
                caseId: this.recordId, 
                productTypeId: this.productTypeId, 
                categoryId: this.categoryId, 
                subCategoryId: this.subCategoryId, 
                subCodeId: this.subCodeId 
            });
            console.log('--- [fetchNotifications] data: ' + JSON.stringify(data));
            this.rawNotifications = data;
            this.options = data.map(item => {
                return { label: item.label, value: item.value };
            });
                        // Reset all selections since the available notifications just changed
            this.selectedNotificationId = null;
            this.selectedTemplateId = null;
            this.selectedChannel = '';
            this.selectedTargetGroup = '';
            this.targetEmail = '';
            this.searchTerm = '';
            this.isDropdownOpen = false;
            this.userSearchResults = [];
            this.error = undefined;
        } catch (error) {
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
            // Xóa email và reset trạng thái combobox nếu là Internal User
            if (this.selectedTargetGroup === TARGET_GROUP_INTERNAL_USER) {
                this.targetEmail = '';
                this.searchTerm = '';
                this.isDropdownOpen = false;
                this.userSearchResults = [];
            } else {
                this.targetEmail = selectedItem.targetEmail;
            }
        }
    }

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        
        // Đóng dropdown nếu gõ ít hơn 2 ký tự
        if (!this.searchTerm) {
            this.isDropdownOpen = false;
            this.userSearchResults = [];
            this.isSearching = false;
            return;
        }

        this.isSearching = true;
        this.isDropdownOpen = true;

        // Debounce: Chờ 300ms sau khi ngừng gõ mới gọi server
        clearTimeout(this.searchTimeout);
        this.searchTimeout = setTimeout(() => {
            searchInternalUsers({ searchTerm: this.searchTerm })
                .then(result => {
                    this.userSearchResults = result;
                    this.isSearching = false;
                })
                .catch(error => {
                    console.error('Lỗi tìm kiếm users:', error);
                    this.isSearching = false;
                });
        }, 300); 
    }

    // Xử lý khi chọn 1 user
    handleSelectUser(event) {
        const selectedEmail = event.currentTarget.dataset.email;
        this.targetEmail = selectedEmail; // Biến này sẽ được gửi đi
        this.searchTerm = selectedEmail;  // Hiển thị email lên ô input
        this.isDropdownOpen = false;      // Tắt combobox
    }

    // --- NEW: Open Modal Logic ---
    async handleEmailInputKeyup(event) {
        if (this.selectedTargetGroup === TARGET_GROUP_INTERNAL_USER && event.keyCode === 13) {
            // Open the LWC Modal and wait for the user to close it
            const result = await fec_UserSearchModal.open({
                size: 'large',
                description: SEARCH_INTERNAL_USERS,
                initialSearchTerm: this.searchTerm 
            });

            if (result) {
                this.targetEmail = result;
                this.searchTerm = result;
                this.isDropdownOpen = false;
            }
        }
    }

    handleEmailChange(event) {
        this.targetEmail = event.target.value;
        const input = event.target;
        const val = this.targetEmail ? this.targetEmail.toString().trim() : "";
        if (!val) {
            input.setCustomValidity("");
        } else {
            const oneLevel = PATTERN_EMAIL_FEC_STRICT;
            if (!oneLevel.test(val)) {
                input.setCustomValidity(
                  MSG_INVALID_EMAIL_FORMAT
                );
            } else {
                input.setCustomValidity("");
            }
        }
        input.reportValidity();
    }

    get isActionDisabled() {
        return !this.selectedNotificationId;
    }

    handleClosePreview() {
        this._isPreviewOpen = false;
    }

    async handlePreview() {
        try {
            const recResult = await previewTemplate({ caseId: this.recordId, templateId: this.selectedTemplateId });    
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
        console.log('--- [handleSend] targetEmail: ' + this.targetEmail);
        let isValid = true;
        
        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach(input => {
            if (!input.reportValidity()) {
                isValid = false;
            }
        });
        if (!this.targetEmail) {
            isValid = false;
        }
        if (!isValid) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: ERROR_MODAL_TITLE,
                    message: MSG_ENTER_EMAIL_CORRECTLY,
                    variant: 'error',
                })
            );
            return;
        }

        sendManualEmail({
            caseId: this.recordId,
            templateId: this.selectedTemplateId,
            toEmail: this.targetEmail,
            fecNotificationConfigId: this.selectedNotificationId
        })
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
                this.searchTerm = '';
                this.isDropdownOpen = false;
            })
            .catch(error => {
                this.error =  this.label.FEC_Email_Send_Error + ': ' + (error.body ? error.body.message : JSON.stringify(error));
            });
    }
}