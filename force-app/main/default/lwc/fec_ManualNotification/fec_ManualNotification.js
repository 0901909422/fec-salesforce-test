import { LightningElement, api, wire, track } from 'lwc';
import { subscribe, unsubscribe, APPLICATION_SCOPE, MessageContext } from 'lightning/messageService';
import IS_MODE_EDIT from '@salesforce/messageChannel/FEC_Case_Mode__c';
import CASE_NOC from '@salesforce/messageChannel/FEC_Case_NOC__c';
import CASE_NOTIFICATION from '@salesforce/messageChannel/FEC_Case_Notification__c';
import getCase from '@salesforce/apex/FEC_CaseEditNOCController.getCase';
import { VIEW_MODE_HANDLING } from 'c/fec_CommonConst';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getAvailableNotifications from '@salesforce/apex/FEC_Notification.getAvailableNotifications';
import sendManualNotification from '@salesforce/apex/FEC_Notification.sendManualNotification';
import sendManualZnsNotification from '@salesforce/apex/FEC_Notification.sendManualZnsNotification';
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
import FEC_ZNS_Message_Send_Error from '@salesforce/label/c.FEC_ZNS_Message_Send_Error';
import FEC_Zalo_Number from '@salesforce/label/c.FEC_Zalo_Number';
import FEC_Select_Zalo_Number_Placeholder from '@salesforce/label/c.FEC_Select_Zalo_Number_Placeholder';
import FEC_Common_No_Results_Label from '@salesforce/label/c.FEC_Common_No_Results_Label';
import FEC_Checking_Mobile_App_Status from '@salesforce/label/c.FEC_Checking_Mobile_App_Status';
import FEC_Customer_Uses_Mobile_App from '@salesforce/label/c.FEC_Customer_Uses_Mobile_App';
import FEC_Customer_Does_Not_Uses_Mobile_App from '@salesforce/label/c.FEC_Customer_Does_Not_Uses_Mobile_App';
import checkUserExist from '@salesforce/apex/FEC_MobileAppNotificationCallout.checkUserExist';
import sendManualMobileAppNotification from '@salesforce/apex/FEC_Notification.sendManualMobileAppNotification';
import FEC_Mobile_App_Noti_Send_Error from '@salesforce/label/c.FEC_Mobile_App_Noti_Send_Error';
import FEC_Mobile_App_Could_Not_Load_Data_Error from '@salesforce/label/c.FEC_Mobile_App_Could_Not_Load_Data_Error';
import { 
    SEARCH_PLACEHOLDER, 
    TARGET_GROUP_INTERNAL_USER,
    SEARCH_INTERNAL_USERS,
    PATTERN_EMAIL_FEC_STRICT,
    MSG_INVALID_EMAIL_FORMAT,
    ERROR_MODAL_TITLE,
    MSG_ENTER_EMAIL_CORRECTLY,
    NOTIFICATION_CHANNEL_SF_APP,
    FEC_SENT_SUCCESS,
    NOTIFICATION_CHANNEL_ZNS,
    NOTIFICATION_CHANNEL_MOBILE_APP
} from 'c/fec_CommonConst';
const PATTERN_ZALO_PHONE = /^(0|\+84)[0-9]{9}$/;

export default class Fec_ManualNotification extends NavigationMixin(LightningElement) {
    @api recordId; 
    @track options = [];
    @track rawNotifications = [];
    @track _record = null;
    @track _isPreviewOpen = false;
    @track channelOptions = [];
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
        FEC_Email_Send_Error: FEC_Email_Send_Error,
        FEC_ZNS_Message_Send_Error: FEC_ZNS_Message_Send_Error,
        FEC_Zalo_Number: FEC_Zalo_Number,
        FEC_Select_Zalo_Number_Placeholder: FEC_Select_Zalo_Number_Placeholder,
        FEC_Common_No_Results_Label: FEC_Common_No_Results_Label,
        FEC_Checking_Mobile_App_Status: FEC_Checking_Mobile_App_Status,
        FEC_Customer_Uses_Mobile_App: FEC_Customer_Uses_Mobile_App,
        FEC_Customer_Does_Not_Uses_Mobile_App: FEC_Customer_Does_Not_Uses_Mobile_App,
        FEC_Mobile_App_Noti_Send_Error: FEC_Mobile_App_Noti_Send_Error,
        FEC_Mobile_App_Could_Not_Load_Data_Error: FEC_Mobile_App_Could_Not_Load_Data_Error
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
    //subscriptionNOC = null;
    subscriptionCaseNotif = null;
    
    @track modeEditCase = false;
    @track isSubmited = true;
    @track interactionViewMode = '';
    
    @track productTypeId = null;
    @track categoryId = null;
    @track subCategoryId = null;
    @track subCodeId = null;
    @track stageId = null;
    @track isDropdownOpen = false;
    @track isSearching = false;
    @track userSearchResults = [];
    @track searchTerm = '';
    searchTimeout;
    @track isSending = false;

    // ZNS state
    @track zaloNumber = '';
    @track zaloSearchTerm = '';
    @track zaloSearchResults = [];
    @track isZaloDropdownOpen = false;
    @track isZaloSearching = false;
    zaloSearchTimeout;
    zaloNumData = [];

    // Mobile App state
    @track isMobileAppUser = false;
    @track isCheckingMobileApp = false;
    @track mobileAppStatusChecked = false;
    @track isMobileAppStatusError = false;
    nationalId = '';
    primaryPhoneNumber = '';

    get isZNSChannel() {
        return this.selectedChannel === NOTIFICATION_CHANNEL_ZNS;
    }

    get isMobileAppChannel() {
        return this.selectedChannel === NOTIFICATION_CHANNEL_MOBILE_APP;
    }

    get isEmailChannel() {
        return !!this.selectedChannel && !this.isZNSChannel && !this.isMobileAppChannel;
    }

    // Getter kiểm tra Select Email Mode
    get isSelectEmailMode() {
        return this.selectedTargetGroup === TARGET_GROUP_INTERNAL_USER || this.selectedChannel === NOTIFICATION_CHANNEL_SF_APP;
    }

    // Getter kiểm tra kết quả rỗng
    get noResults() {
        return this.userSearchResults.length === 0;
    }

    // get isEdit() {
    //     const defaultEdit = (this.modeEditCase || this.interactionViewMode === VIEW_MODE_HANDLING) ? true : false;
    //     return defaultEdit && !this.isSubmited;
    // }

    get noZaloResults() {
        return this.zaloSearchResults.length === 0;
    }

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

            if (res?.FEC_Phone_Number__c) {
                this.zaloNumData.push({
                    Phone: res.FEC_Phone_Number__c
                });
            }
            if (res?.FEC_Account_or_Contract__r?.FEC_Primary_Phone__c) {
                this.zaloNumData.push({
                    Phone: res.FEC_Account_or_Contract__r.FEC_Primary_Phone__c
                });
                this.primaryPhoneNumber = res.FEC_Account_or_Contract__r.FEC_Primary_Phone__c;
            }
            if (res?.FEC_Account_or_Contract__r?.FEC_National_ID_Passport_ID__c) {
                this.nationalId = res.FEC_Account_or_Contract__r.FEC_National_ID_Passport_ID__c;
            }
        } catch(error) {
            console.error('Error fetching Case details in fec_ManualNotification: ', error);
        }
    }

    disconnectedCallback() {
        unsubscribe(this.subscriptionMode);
        this.subscriptionMode = null;

        // unsubscribe(this.subscriptionNOC);
        // this.subscriptionNOC = null;

        if (this.subscriptionCaseNotif) {
            unsubscribe(this.subscriptionCaseNotif);
            this.subscriptionCaseNotif = null;
        }
    }

    subscribeToMessageChannel() {
        this.subscriptionMode = subscribe(
            this.messageContext,
            IS_MODE_EDIT,
            (message) => this.handleModeMessage(message),
            { scope: APPLICATION_SCOPE }
        );

        // this.subscriptionNOC = subscribe(
        //     this.messageContext,
        //     CASE_NOC,
        //     (message) => this.handleNOCMessage(message),
        //     { scope: APPLICATION_SCOPE }
        // );

        this.subscriptionCaseNotif = subscribe(
            this.messageContext,
            CASE_NOTIFICATION,
            (message) => this.handleCaseNotifMessage(message),
            { scope: APPLICATION_SCOPE }
        );
    }

    handleModeMessage(message) {
        if (!message || typeof message.isModeEdit === 'undefined') return;
        this.modeEditCase = message.isModeEdit === true;
    }


    handleCaseNotifMessage(message) {
        if (!message) return;
        if (message.caseId != null && message.caseId !== this.recordId) {
            return;
        }
        this.productTypeId = message?.productTypeId;
        this.categoryId = message?.categoryId;
        this.subCategoryId = message?.subCategoryId;
        this.subCodeId = message?.subCodeId;
        this.stageId = message?.stageId;
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
                subCodeId: this.subCodeId,
                stageId: this.stageId
            });
            console.log('--- [fetchNotifications] data: ' + JSON.stringify(data));
            this.rawNotifications = data;
            this.options = data.map(item => {
                return { label: item.label, value: item.value };
            });
            this.selectedNotificationId = null;
            this.selectedTemplateId = null;
            this.selectedChannel = '';
            this.channelOptions = [];
            this.selectedTargetGroup = '';
            this.targetEmail = '';
            this.searchTerm = '';
            this.isDropdownOpen = false;
            this.userSearchResults = [];
            this.zaloNumber = '';
            this.zaloSearchTerm = '';
            this.zaloSearchResults = [];
            this.isZaloDropdownOpen = false;
            this.isMobileAppUser = false;
            this.mobileAppStatusChecked = false;
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
            this.selectedTargetGroup = selectedItem.targetGroup;
            
            if (selectedItem.channels && selectedItem.channels.length > 0) {
                this.channelOptions = selectedItem.channels.map(ch => {
                    return { label: ch.channelName, value: ch.channelName };
                });
            } else {
                this.channelOptions = [];
            }
            
            this.selectedChannel = '';
            this.selectedTemplateId = null;
            
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

    handleChannelChange(event) {
        this.selectedChannel = event.detail.value;
        const selectedItem = this.rawNotifications.find(item => item.value === this.selectedNotificationId);
        
        if (selectedItem && selectedItem.channels) {
            const selectedChannelObj = selectedItem.channels.find(ch => ch.channelName === this.selectedChannel);
            if (selectedChannelObj) {
                this.selectedTemplateId = selectedChannelObj.templateId;
            }
        }

        // Reset tất cả channel-specific state trước khi xử lý channel mới
        this.targetEmail = '';
        this.searchTerm = '';
        this.isDropdownOpen = false;
        this.userSearchResults = [];
        this.zaloNumber = '';
        this.zaloSearchTerm = '';
        this.zaloSearchResults = [];
        this.isZaloDropdownOpen = false;
        this.isMobileAppUser = false;
        this.mobileAppStatusChecked = false;

        if (this.isZNSChannel || this.isMobileAppChannel) {
            // ZNS và Mobile App không dùng email
        } else if (this.selectedTargetGroup === TARGET_GROUP_INTERNAL_USER || this.selectedChannel === NOTIFICATION_CHANNEL_SF_APP) {
            // Email search mode - targetEmail rỗng, user tự search
        } else {
            this.targetEmail = selectedItem ? selectedItem.targetEmail : '';
        }

        if (this.isMobileAppChannel) {
            this.handleCheckMobileAppStatus();
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
        if ((this.selectedTargetGroup === TARGET_GROUP_INTERNAL_USER || this.selectedChannel === NOTIFICATION_CHANNEL_SF_APP) && event.keyCode === 13) {
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

    // ── ZNS handlers ─────────────────────────────────────────────────────────

    searchZaloContacts = ({ searchTerm }) => {
        const keyword = searchTerm?.trim();

        const result = (this.zaloNumData || []).filter(item => {
            if (!keyword) {
                return true;
            }

            return item.Phone?.includes(keyword);
        });

        return Promise.resolve(result);
    };

    handleZaloSearchFocus() {
        clearTimeout(this.zaloBlurTimeout);
        this.isZaloDropdownOpen = true;
        this.searchZaloContacts({ searchTerm: '' })
            .then(result => {
                this.zaloSearchResults = result;
            })
        .catch(error => {
            console.error('Lỗi tìm kiếm Zalo contacts:', error);
        });
    }

    handleZaloSearchBlur() {
        this.zaloBlurTimeout = setTimeout(() => {
            this.isZaloDropdownOpen = false;
        }, 200);
    }

    handleZaloSearchInput(event) {
        this.zaloSearchTerm = event.target.value;
        this.zaloNumber = '';

        if (!this.zaloSearchTerm) {
            this.isZaloDropdownOpen = false;
            this.zaloSearchResults = [];
            this.isZaloSearching = false;
            return;
        }

        // Nếu user gõ thẳng số điện thoại hợp lệ thì confirm luôn, không cần search
        if (PATTERN_ZALO_PHONE.test(this.zaloSearchTerm.trim())) {
            this.zaloNumber = this.zaloSearchTerm.trim();
            this.isZaloDropdownOpen = false;
            this.zaloSearchResults = [];
            return;
        }

        this.isZaloSearching = true;
        this.isZaloDropdownOpen = true;

        clearTimeout(this.zaloSearchTimeout);
        this.zaloSearchTimeout = setTimeout(() => {
            this.searchZaloContacts({ searchTerm: this.zaloSearchTerm })
                .then(result => {
                    this.zaloSearchResults = result;
                    this.isZaloSearching = false;
                })
                .catch(error => {
                    console.error('Lỗi tìm kiếm Zalo contacts:', error);
                    this.isZaloSearching = false;
                });
        }, 300);
    }

    handleSelectZaloContact(event) {
        clearTimeout(this.zaloBlurTimeout);
        const phone = event.currentTarget.dataset.phone;
        this.zaloNumber = phone;
        this.zaloSearchTerm = phone;
        this.isZaloDropdownOpen = false;

        // Clear trạng thái invalid của lightning-input
        Promise.resolve().then(() => {
            const inputCmp = this.template.querySelector('[data-id="zaloNumberInput"]');

            if (inputCmp) {
                inputCmp.setCustomValidity('');
                inputCmp.reportValidity();
            }
        });
    }

    // ── Mobile App handler ────────────────────────────────────────────────────

    handleCheckMobileAppStatus() {
        this.isCheckingMobileApp = true;
        this.mobileAppStatusChecked = false;
        checkUserExist({ phoneNumber: this.primaryPhoneNumber, nationalId: this.nationalId })
            .then(result => {
                this.isMobileAppUser = result?.isCustomerExist === true;
                this.mobileAppStatusChecked = true;
                this.isCheckingMobileApp = false;
                if (result.httpStatusCode >= 500 && result.httpStatusCode < 600) {
                    this.isMobileAppStatusError = true;
                } else {
                    this.isMobileAppStatusError = false;
                }
                
            })
            .catch(error => {
                console.error('Lỗi kiểm tra Mobile App status:', error);
                this.isMobileAppUser = false;
                this.mobileAppStatusChecked = true;
                this.isCheckingMobileApp = false;
                this.isMobileAppStatusError = true;
            });
    }

    // ─────────────────────────────────────────────────────────────────────────

    get isActionDisabled() {
        if (this.isSending) return true;
        if (!this.selectedNotificationId || !this.selectedChannel) return true;
        if (this.isZNSChannel) return !this.zaloNumber;
        if (this.isMobileAppChannel) return !this.mobileAppStatusChecked || !this.isMobileAppUser;
        return false;
    }

    // Preview chỉ cần channel + templateId, không phụ thuộc Zalo/MobileApp status
    get isPreviewDisabled() {
        return !this.selectedNotificationId || !this.selectedChannel;
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
            lastModifiedDate:       rec.LastModifiedDate,
            isZNSTemplate:          rec.FEC_Is_ZNS_Template__c,
            previewZNSUrl:          rec.FEC_Preview_ZNS_Url__c,
            templateZNSStatus:      rec.FEC_Template_ZNS_Status__c
        };
    }

    handleSend() {
        // ZNS và Mobile App không validate email
        if (!this.isZNSChannel && !this.isMobileAppChannel) {
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

            sendManualNotification({
                caseId: this.recordId,
                templateId: this.selectedTemplateId,
                toEmail: this.targetEmail,
                fecNotificationConfigId: this.selectedNotificationId,
                selectedChannel: this.selectedChannel
            })
                    .then(() => {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: this.label.FEC_MSG_IPP_AddIpp_Default_Success,
                                message: FEC_SENT_SUCCESS,
                                variant: 'success',
                            })
                        );
                        // Reset states
                        this.selectedNotificationId = null; 
                        this.selectedTemplateId = null;
                        this.selectedChannel = '';
                        this.channelOptions = [];
                        this.selectedTargetGroup = '';
                        this.targetEmail = '';
                        this.searchTerm = '';
                        this.isDropdownOpen = false;
                        this.zaloNumber = '';
                        this.zaloSearchTerm = '';
                        this.isZaloDropdownOpen = false;
                        this.zaloSearchResults = [];
                        this.isMobileAppUser = false;
                        this.mobileAppStatusChecked = false;
                    })
                    .catch(error => {
                        this.error =  this.label.FEC_Email_Send_Error + ': ' + (error.body ? error.body.message : JSON.stringify(error));
                    });
        }

        if (this.isZNSChannel) {
            console.log("--Sending ZNS Notification---");
            this.isSending = true;
            sendManualZnsNotification({
                caseId: this.recordId,
                templateId: this.selectedTemplateId,
                toPhoneNumber: this.zaloNumber,
                fecNotificationConfigId: this.selectedNotificationId,
                selectedChannel: this.selectedChannel
            })
                    .then(() => {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: this.label.FEC_MSG_IPP_AddIpp_Default_Success,
                                message: FEC_SENT_SUCCESS,
                                variant: 'success',
                            })
                        );
                        // Reset states
                        this.selectedNotificationId = null; 
                        this.selectedTemplateId = null;
                        this.selectedChannel = '';
                        this.channelOptions = [];
                        this.selectedTargetGroup = '';
                        this.targetEmail = '';
                        this.searchTerm = '';
                        this.isDropdownOpen = false;
                        this.zaloNumber = '';
                        this.zaloSearchTerm = '';
                        this.isZaloDropdownOpen = false;
                        this.zaloSearchResults = [];
                        this.isMobileAppUser = false;
                        this.mobileAppStatusChecked = false;
                    })
                    .catch(error => {
                        this.error =  this.label.FEC_ZNS_Message_Send_Error + ': ' + (error.body ? error.body.message : JSON.stringify(error));
                    }) 
                    .finally(() => {
                        this.isSending = false;
                    });
        }

        if (this.isMobileAppChannel) {
            console.log("--Sending Mobile App Notification---");
            this.isSending = true;
            sendManualMobileAppNotification({
                caseId: this.recordId,
                templateId: this.selectedTemplateId,
                toPhoneNumber: this.primaryPhoneNumber,
                toNationalId: this.nationalId,
                fecNotificationConfigId: this.selectedNotificationId,
                selectedChannel: this.selectedChannel
            })
                    .then(() => {
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: this.label.FEC_MSG_IPP_AddIpp_Default_Success,
                                message: FEC_SENT_SUCCESS,
                                variant: 'success',
                            })
                        );
                        // Reset states
                        this.selectedNotificationId = null; 
                        this.selectedTemplateId = null;
                        this.selectedChannel = '';
                        this.channelOptions = [];
                        this.selectedTargetGroup = '';
                        this.targetEmail = '';
                        this.searchTerm = '';
                        this.isDropdownOpen = false;
                        this.zaloNumber = '';
                        this.zaloSearchTerm = '';
                        this.isZaloDropdownOpen = false;
                        this.zaloSearchResults = [];
                        this.isMobileAppUser = false;
                        this.mobileAppStatusChecked = false;
                    })
                    .catch(error => {
                        this.error =  this.label.FEC_Mobile_App_Noti_Send_Error + ': ' + (error.body ? error.body.message : JSON.stringify(error));
                    }) 
                    .finally(() => {
                        this.isSending = false;
                    });
        }
    }
}