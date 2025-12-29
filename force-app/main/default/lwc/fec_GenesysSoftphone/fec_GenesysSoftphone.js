import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import createInteractionCase from '@salesforce/apex/FEC_CreateCaseHanlder.createInteractionCase';

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
                this.handleNewInteraction(eventType, data);
                break;
            case 'WrapupCall':
                this.handleWrapup(data);
                break;
            // ... các case khác giữ nguyên ...
            default:
                console.warn(`Sự kiện Genesys chưa được xử lý: ${eventType}`);
        }
    }

    /** * Xử lý khi có tương tác mới (Inbound Call)
    * @param callData Dữ liệu từ IWS postMessage
    */
    handleNewInteraction(eventType, callData) {
        console.log("Dữ liệu cuộc gọi mới:", JSON.stringify(callData));

        // 1. Chuẩn bị DTO mapping với FEC_InteractionCaseDTO trong Apex
        const interactionDto = {
            channel: 'Genesys',
            subChannel: eventType,
            phoneNumber: callData.DNIS,
            externalInteractionId: callData.GenesysInteractionID, // ID từ Genesys
            nationalId: callData.NationalID ,
            accountNumber: callData.CardAccountNum ,
            contractNumber: callData.ContractNum ,
            transcription: "CPM interaction"
        };

        // 2. Gọi Apex để tạo record
        createInteractionCase({ dto: interactionDto })
            .then((result) => {
                // result là đối tượng FEC_InteractionCaseResponse { caseId, linkId, caseNo }
                this.currentInteractionCaseId = result.caseId;
                
                this.showToast('Thành công', `Đã tạo Case tương tác: ${result.caseNo || ''}`, 'success');

                // 3. Tự động điều hướng đến Case vừa tạo
                this.navigateToRecord(result.caseId);
            })
            .catch((error) => {
                this.showToast('Lỗi tạo Case', error.body.message, 'error');
                console.error('Error creating interaction case:', error);
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