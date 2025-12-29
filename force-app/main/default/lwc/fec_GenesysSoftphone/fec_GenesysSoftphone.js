import { LightningElement, track } from 'lwc';
import { createRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CASE_OBJECT from '@salesforce/schema/Case';

import SUBJECT_FIELD from '@salesforce/schema/Case.Subject';
import STATUS_FIELD from '@salesforce/schema/Case.Status';
import ORIGIN_FIELD from '@salesforce/schema/Case.Origin';
import DESCRIPTION_FIELD from '@salesforce/schema/Case.Description';
// Import các trường custom nếu bạn muốn điền thêm thông tin
import PHONE_FIELD from '@salesforce/schema/Case.SuppliedPhone';

export default class Fec_GenesysSoftphone  extends NavigationMixin(LightningElement) {
    @track callStatus = 'Đang khởi tạo IWS...';
    @track callerNumber = '';

    // Biến để lưu ID Case tương tác hiện tại
    currentInteractionCaseId = null;

    // Khi component được thêm vào trang, bắt đầu kết nối
    connectedCallback() {
        this.setupPostMessageListener();
    }

    // Khi component bị gỡ khỏi trang, dọn dẹp kết nối
    disconnectedCallback() {
        // Dọn dẹp listener
        window.removeEventListener('message', this.handlePostMessage.bind(this));
    }

    get IframeSrc() {
        // Trả về đường dẫn tuyệt đối đến trang Visualforce
        return window.location.origin + '/apex/IWS_Host';
    }

    // =================================================================
    // 1. LẮNG NGHE SỰ KIỆN TỪ IFRAME (PostMessage)
    // =================================================================
    setupPostMessageListener() {
        // Lắng nghe thông điệp từ Iframe (VF Page)
        window.addEventListener('message', this.handlePostMessage.bind(this));
        this.callStatus = 'Đã tải Host. Đang chờ kết nối IWS...';
    }

    handlePostMessage(event) {
        // Chỉ xử lý các thông điệp đến từ miền Salesforce và có định dạng đúng
        // if (event.origin !== window.location.origin) {
        //     return; 
        // }
        console.log(`LWC nhận được sự kiện Genesys từ Iframe:`, JSON.stringify(event));
        const message = event.data;
        if (message.source === 'genesys_host' && message.eventType) {
            const { eventType, data } = message;
            this.callStatus = `Sự kiện: ${eventType}`;
            this.processGenesysEvent(eventType, data); 
        }
    }

    processGenesysEvent(eventType, data) {
        switch (eventType) {
            case 'InboundRinging':
            case 'OutboundEstablished':
                this.handleNewInteraction(data);
                break;
            case 'WrapupCall':
                this.handleWrapup(data);
                break;
            // ... các case khác giữ nguyên ...
            default:
                console.warn(`Sự kiện Genesys chưa được xử lý: ${eventType}`);
        }
    }

    // Xử lý tạo Case cho cuộc gọi (thay thế cho logic cũ trong createInteractionCase)
    handleNewInteraction(callData) {
        console.log("Dữ liệu cuộc gọi mới:", JSON.stringify(callData));
        this.callerNumber = callData.DNIS;

        // >>> GỌI APEX/UI RECORD API ĐỂ TẠO CASE <<<

        const fields = {
            [SUBJECT_FIELD.fieldApiName]: `${callData.AgentID} Call from ${callData.DNIS}`,
            [PHONE_FIELD.fieldApiName]: callData.DNIS,
            [STATUS_FIELD.fieldApiName]: 'New',
            [ORIGIN_FIELD.fieldApiName]: 'Phone',
            [DESCRIPTION_FIELD.fieldApiName]: `Genesys Interaction ID: ${callData.GenesysInteractionID}\nAttach Data: ${callData.AttachDataJSON}`
        };

        const recordInput = { apiName: CASE_OBJECT.objectApiName, fields };

        createRecord(recordInput)
            .then(caseRecord => {
                this.currentInteractionCaseId = caseRecord.id; // Lưu lại ID Case
                this.showToast('Thành công', `Đã tạo Case: ${caseRecord.id}`, 'success');
                this.navigateToRecord(caseRecord.id);
            })
            .catch(error => {
                console.error('LỖI TẠO CASE:', JSON.stringify(error));
                this.showToast('Lỗi', `Lỗi khi tạo Case: ${error.body?.message || 'Lỗi không xác định'}`, 'error');
            });
    }

    // Xử lý Wrap-up (cập nhật Case)
    handleWrapup(wrapupData) {
        // Cập nhật Case hiện tại (hoặc Case có ID = wrapupData.InteractionCaseID)
        // >>> GỌI APEX/UI RECORD API ĐỂ CẬP NHẬT CASE <<<

        // Ví dụ: Gọi Apex để cập nhật trường Business_Result__c
        // updateCase({ caseId: wrapupData.InteractionCaseID, result: wrapupData.BusinessResult });

        this.showToast('Wrap-up', `Đã gửi dữ liệu Wrap-up (${wrapupData.BusinessResult})`, 'info');
        this.currentInteractionCaseId = null; // Reset Case ID sau khi kết thúc
    }

    // Xử lý cập nhật ID Click-to-Call
    handleUpdateCTC(ctcData) {
        // >>> GỌI APEX ĐỂ TÌM VÀ CẬP NHẬT BẢN GHI OUTBOUND <<<

        const action = ctcData.action === 'Set' ? 'Liên kết' : 'Hủy liên kết';
        this.showToast('CTC Update', `${action} thành công CTC ID: ${ctcData.InteractionId}`, 'info');

        // Ví dụ: Gọi Apex
        // updateOutboundRecord({ interactionId: ctcData.InteractionId, genesysId: ctcData.GenesysInteractionID });
    }

    handleNewEmailInteraction(emailData) {
        // Tương tự handleNewInteraction nhưng tạo Case cho Email
        // Ánh xạ emailData vào Case/EmailMessage
    }

    // Hàm tiện ích điều hướng
    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: recordId, actionName: 'view' }
        });
    }

    // Hàm tiện ích Show Toast
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}