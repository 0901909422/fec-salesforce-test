import { LightningElement, api } from 'lwc';
import loadCardInfo from '@salesforce/apex/FEC_CardInfoController.loadCardInfo';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { autoHighlightNegativeCurrency } from 'c/fec_currencyUtils';
import FEC_Card_Delivery_Label from '@salesforce/label/c.FEC_Card_Delivery_Label';
import FEC_Other_Card_Label from '@salesforce/label/c.FEC_Other_Card_Label';

// Error message constant
const ERROR_MESSAGE = 'Tải dữ liệu không thành công';

export default class Fec_CardInfo extends LightningElement {
    @api recordId;
    
    // Expose ERROR_MESSAGE for template
    ERROR_MESSAGE = ERROR_MESSAGE;

    cardDeliveryData = [];
    otherCardData = [];
    
    // Active accordion sections - mặc định mở cả 2
    activeSections = ['cardDelivery', 'otherCard'];
    
    isCardDeliveryLoading = true;
    isOtherCardLoading = true;
    hasCardDeliveryError = false;
    hasOtherCardError = false;
    cardDeliveryUpdatedTime;
    otherCardUpdatedTime;

    // Platform Event subscription
    subscription = null;
    channelName = '/event/FEC_Card_Info_Refresh__e';

    customLabel = {
        cardDeliveryLabel: FEC_Card_Delivery_Label,
        otherCardLabel: FEC_Other_Card_Label
    }

    // Load data khi component mount (giống IPPDetails)
    connectedCallback() {
        this.restoreAccordionState();
        // Sử dụng loadCardInfo() - method này tự động gọi API và load từ database
        this.loadCardInfoData();
        // Subscribe Platform Event để tự động refresh khi có event
        this.subscribeToPlatformEvent();
        this.registerErrorListener();
    }

    disconnectedCallback() {
        this.unsubscribeFromPlatformEvent();
    }

    // Load data từ loadCardInfo() - method này tự động gọi API và load từ database
    // Chỉ gọi API nếu chưa có dữ liệu trong database
    loadCardInfoData() {
        this.isCardDeliveryLoading = true;
        this.isOtherCardLoading = true;
        this.hasCardDeliveryError = false;
        this.hasOtherCardError = false;
        
        
        loadCardInfo({ caseId: this.recordId })
            .then(result => {
                this.handleCardInfoResult(result);
            })
            .catch(error => {
                this.handleCardInfoError(error);
            });
    }

    // Refresh Card Info (load lại từ database hoặc API nếu chưa có)
    refreshCardInfoData() {
        this.isCardDeliveryLoading = true;
        this.isOtherCardLoading = true;
        this.hasCardDeliveryError = false;
        this.hasOtherCardError = false;
        
        // Clear cached data trước khi load lại
        this.cardDeliveryData = [];
        this.otherCardData = [];
        
        
        loadCardInfo({ caseId: this.recordId })
            .then(result => {
                this.handleCardInfoResult(result);
                this.showToast('Success', 'Card information has been refreshed', 'success');
            })
            .catch(error => {
                this.handleCardInfoError(error);
                this.showToast('Error', 'Failed to refresh: ' + (error.body?.message || error.message), 'error');
            });
    }

    // Helper method: Xử lý kết quả từ loadCardInfo/refreshCardInfo
    handleCardInfoResult(result) {
        
        // Map Card Delivery DTO sang format cho table
        if (result && result.cardDeliveries && result.cardDeliveries.length > 0) {
            this.cardDeliveryData = result.cardDeliveries.map(dto => {
                return {
                    FEC_Card_Number__c: dto.cardNumber,
                    FEC_Issue_Date__c: dto.issueDate,
                    FEC_Type_of_Issue__c: dto.typeOfIssue,
                    FEC_Delivery_Status__c: dto.deliveryStatus,
                    FEC_Delivery_Date__c: dto.deliveryDate,
                    FEC_Recipient__c: dto.recipient,
                    FEC_Tracking_Number__c: dto.trackingNumber,
                    FEC_Delivery_Note__c: dto.deliveryNote
                };
            }).map(record => autoHighlightNegativeCurrency(record));
        } else {
            this.cardDeliveryData = [];
        }
        
        // Map Other Card DTO sang format cho table
        if (result && result.otherCards && result.otherCards.length > 0) {
            this.otherCardData = result.otherCards.map(dto => {
                return {
                    FEC_Cardholder__c: dto.cardholder,
                    FEC_Card_Number__c: dto.cardNumber,
                    FEC_Plastic_ID__c: dto.plasticId,
                    FEC_Expiry_Date__c: dto.expiryDate,
                    FEC_Embossing_Name__c: dto.embossingName,
                    FEC_Card_Activation_Date__c: dto.cardActivationDate,
                    FEC_Issue_Date__c: dto.issueDate,
                    FEC_Block_Code__c: dto.blockCode,
                    FEC_Gender__c: dto.gender
                };
            }).map(record => autoHighlightNegativeCurrency(record));
        } else {
            this.otherCardData = [];
        }
        
        this.hasCardDeliveryError = false;
        this.hasOtherCardError = false;
        this.cardDeliveryUpdatedTime = new Date();
        this.otherCardUpdatedTime = new Date();
        this.isCardDeliveryLoading = false;
        this.isOtherCardLoading = false;
    }

    // Helper method: Xử lý lỗi từ loadCardInfo/refreshCardInfo
    handleCardInfoError(error) {
        this.hasCardDeliveryError = true;
        this.hasOtherCardError = true;
        this.cardDeliveryData = [];
        this.otherCardData = [];
        this.isCardDeliveryLoading = false;
        this.isOtherCardLoading = false;
    }

    // Storage key for accordion state
    get storageKey() {
        return `cardInfo_accordion_${this.recordId}`;
    }

    // Khôi phục trạng thái accordion từ localStorage
    restoreAccordionState() {
        try {
            const savedState = localStorage.getItem(this.storageKey);
            if (savedState) {
                this.activeSections = JSON.parse(savedState);
            } else {
                this.activeSections = ['cardDelivery', 'otherCard'];
            }
        } catch (e) {
            this.activeSections = ['cardDelivery', 'otherCard'];
        }
    }

    // Handle accordion toggle - Card Delivery
    handleCardDeliveryToggle() {
        const index = this.activeSections.indexOf('cardDelivery');
        if (index > -1) {
            this.activeSections = this.activeSections.filter(s => s !== 'cardDelivery');
        } else {
            this.activeSections = [...this.activeSections, 'cardDelivery'];
        }
        this.saveAccordionState();
    }

    // Handle accordion toggle - Other Card
    handleOtherCardToggle() {
        const index = this.activeSections.indexOf('otherCard');
        if (index > -1) {
            this.activeSections = this.activeSections.filter(s => s !== 'otherCard');
        } else {
            this.activeSections = [...this.activeSections, 'otherCard'];
        }
        this.saveAccordionState();
    }

    // Save accordion state to localStorage
    saveAccordionState() {
        try {
            localStorage.setItem(this.storageKey, JSON.stringify(this.activeSections));
        } catch (e) {
            // Silent error
        }
    }

    // Check if section is open
    get isCardDeliveryOpen() {
        return this.activeSections.includes('cardDelivery');
    }

    get isOtherCardOpen() {
        return this.activeSections.includes('otherCard');
    }

    // Icon name for accordion chevron
    get cardDeliveryIconName() {
        return this.isCardDeliveryOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    get otherCardIconName() {
        return this.isOtherCardOpen ? 'utility:chevrondown' : 'utility:chevronright';
    }

    // Section class for custom accordion
    get cardDeliverySectionClass() {
        let classes = 'slds-accordion__section';
        if (this.isCardDeliveryOpen) {
            classes += ' slds-is-open';
        }
        return classes;
    }

    get otherCardSectionClass() {
        let classes = 'slds-accordion__section';
        if (this.isOtherCardOpen) {
            classes += ' slds-is-open';
        }
        return classes;
    }

    // Content class for accordion content
    get cardDeliveryContentClass() {
        return this.isCardDeliveryOpen 
            ? 'slds-accordion__content' 
            : 'slds-accordion__content slds-hide';
    }

    get otherCardContentClass() {
        return this.isOtherCardOpen 
            ? 'slds-accordion__content' 
            : 'slds-accordion__content slds-hide';
    }

    // Cấu hình cột cho Card Delivery
    cardDeliveryColumns = [
        { label: 'Card Number', fieldName: 'FEC_Card_Number__c' },
        { label: 'Issue Date', fieldName: 'FEC_Issue_Date__c', type: 'date' },
        { label: 'Type of Issue', fieldName: 'FEC_Type_of_Issue__c' },
        { label: 'Delivery Status', fieldName: 'FEC_Delivery_Status__c' },
        { label: 'Delivery Date', fieldName: 'FEC_Delivery_Date__c', type: 'date' },
        { label: 'Recipient', fieldName: 'FEC_Recipient__c' },
        { label: 'Tracking Number', fieldName: 'FEC_Tracking_Number__c' },
        { label: 'Delivery Note', fieldName: 'FEC_Delivery_Note__c' }
    ];

    // Cấu hình cột cho Other Card
    otherCardColumns = [
        { label: 'Card Holder', fieldName: 'FEC_Cardholder__c' },
        { label: 'Card Number', fieldName: 'FEC_Card_Number__c' },
        { label: 'Plastic ID', fieldName: 'FEC_Plastic_ID__c' },
        { label: 'Expiry Date', fieldName: 'FEC_Expiry_Date__c', type: 'date' },
        { label: 'Embossing Name', fieldName: 'FEC_Embossing_Name__c' },
        { label: 'Card Activation Date', fieldName: 'FEC_Card_Activation_Date__c', type: 'date' },
        { label: 'Issue Date', fieldName: 'FEC_Issue_Date__c', type: 'date' },
        { label: 'Block Code', fieldName: 'FEC_Block_Code__c' },
        { label: 'Gender', fieldName: 'FEC_Gender__c' }
    ];

    // Refresh lại dữ liệu từ API (force refresh)
    // Method này có thể được gọi từ bên ngoài component (ví dụ: từ parent component)
    @api
    refreshData() {
        this.refreshCardInfoData();
    }

    // =====================================================
    // PLATFORM EVENT SUBSCRIPTION
    // =====================================================

    /**
     * Subscribe to Platform Event để tự động refresh Card Info khi có event
     */
    subscribeToPlatformEvent() {
        if (this.subscription) {
            return; // Đã subscribe rồi
        }
        
        subscribe(this.channelName, -1, (message) => {
            this.handlePlatformEvent(message);
        }).then(response => {
            this.subscription = response;
        }).catch(error => {
            // Silent error
        });
    }

    /**
     * Unsubscribe from Platform Event khi component bị destroy
     */
    unsubscribeFromPlatformEvent() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {
                this.subscription = null;
            });
        }
    }

    /**
     * Handle incoming Platform Event
     * Chỉ refresh nếu event liên quan đến Case hiện tại
     */
    handlePlatformEvent(message) {
        const eventCaseId = message.data.payload.FEC_Case_Id__c;
        // Chỉ refresh nếu event liên quan đến Case hiện tại
        if (eventCaseId === this.recordId) {
            // Tự động refresh từ API (force refresh)
            this.refreshCardInfoData();
        }
    }

    /**
     * Register error listener cho EMP API
     */
    registerErrorListener() {
        onError(error => {
        });
    }


    // Toast notification
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}