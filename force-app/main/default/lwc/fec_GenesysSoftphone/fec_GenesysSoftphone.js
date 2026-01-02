/** * Controller xử lý logic Softphone và giao tiếp với IWS Host qua postMessage
* @created      : 2025/12/29 long.nguyen.50
* @modified     : 2026/01/02 long.nguyen.50 (Thêm logging chi tiết)
*/
import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import createInteractionCase from '@salesforce/apex/FEC_CreateCaseHanlder.createInteractionCase';

export default class fec_genesysSoftphone extends NavigationMixin(LightningElement) {
    @track callStatus = 'Đang khởi tạo IWS...';
    @track callerNumber = '';

    // Biến để lưu ID Case tương tác hiện tại
    currentInteractionCaseId = null;

    /** * Khởi tạo component và thiết lập lắng nghe sự kiện
    * @created: 2025/12/29 long.nguyen.50
    */
    connectedCallback() {
        console.log('[fec_genesysSoftphone] connectedCallback: Initializing component...');
        this.setupPostMessageListener();
    }

    /** * Dọn dẹp listener khi component bị gỡ bỏ
    * @created: 2025/12/29 long.nguyen.50
    */
    disconnectedCallback() {
        console.log('[fec_genesysSoftphone] disconnectedCallback: Removing event listener...');
        window.removeEventListener('message', this.handlePostMessage.bind(this));
    }

    get IframeSrc() {
        const strUrl = window.location.origin + '/apex/IWS_Host';
        console.log('[fec_genesysSoftphone] IframeSrc generated:', strUrl);
        return strUrl;
    }

    /** * Thiết lập lắng nghe postMessage từ Visualforce Host
    * @created: 2025/12/29 long.nguyen.50
    */
    setupPostMessageListener() {
        console.log('[fec_genesysSoftphone] setupPostMessageListener: Adding window listener...');
        window.addEventListener('message', this.handlePostMessage.bind(this));
        this.callStatus = 'Đã tải Host. Đang chờ kết nối IWS...';
    }

    /** * Xử lý thông điệp nhận được từ Iframe
    * @param event Đối tượng sự kiện từ postMessage
    * @created: 2025/12/29 long.nguyen.50
    */
    handlePostMessage(event) {
        // Log toàn bộ message nhận được để tracking tín hiệu Genesys
        console.log(`[fec_genesysSoftphone] handlePostMessage received event:`, event);

        const message = event.data;
        if (message.source === 'genesys_host' && message.eventType) {
            const { eventType, data } = message;
            console.log(`[fec_genesysSoftphone] Processing Genesys event: ${eventType}`, JSON.stringify(data));
            
            this.callStatus = `Sự kiện: ${eventType}`;
            this.processGenesysEvent(eventType, data); 
        } else {
            console.log('[fec_genesysSoftphone] handlePostMessage: Ignore message from other sources.');
        }
    }

    /** * Định tuyến xử lý theo loại sự kiện Genesys
    * @param eventType Tên sự kiện (InboundRinging, OutboundEstablished...)
    * @param data Dữ liệu đi kèm sự kiện
    * @created: 2025/12/29 long.nguyen.50
    */
    processGenesysEvent(eventType, data) {
        console.log(`[fec_genesysSoftphone] Routing event: ${eventType}`);
        switch (eventType) {
            case 'InboundRinging':
            case 'OutboundEstablished':
                this.handleNewInteraction(eventType, data);
                break;
            case 'WrapupCall':
                this.handleWrapup(data);
                break;
            default:
                console.warn(`[fec_genesysSoftphone] Event ${eventType} is not implemented.`);
        }
    }

    /** * Xử lý khi có tương tác mới (Tạo Interaction Case)
    * @param eventType Loại sự kiện cuộc gọi
    * @param callData Dữ liệu chi tiết cuộc gọi
    * @created: 2025/12/29 long.nguyen.50
    */
    handleNewInteraction(eventType, callData) {
        console.log("[fec_genesysSoftphone] handleNewInteraction: Preparing DTO for Apex...", JSON.stringify(callData));

        const interactionDto = {
            channel: 'Outbound',
            subChannel: eventType,
            phoneNumber: callData.DNIS || callData.ANI,
            externalInteractionId: callData.GenesysInteractionID,
            nationalId: callData.NationalID,
            accountNumber: callData.CardAccountNum,
            contractNumber: callData.ContractNum,
            transcription: "CPM interaction"
        };

        console.log("[fec_genesysSoftphone] handleNewInteraction: Calling Apex createInteractionCase with DTO:", JSON.stringify(interactionDto));

        createInteractionCase({ jsonInput: JSON.stringify(interactionDto) })
            .then((result) => {
                console.log("[fec_genesysSoftphone] Apex createInteractionCase Success:", JSON.stringify(result));
                this.currentInteractionCaseId = result.caseId;
                
                this.showToast('Thành công', `Đã tạo Case tương tác: ${result.caseNo || ''}`, 'success');
                this.navigateToRecord(result.caseId);
            })
            .catch((error) => {
                const strErrorMessage = error.body ? error.body.message : error.message;
                console.error('[fec_genesysSoftphone] Create Error Details:', strErrorMessage);
                console.error('[fec_genesysSoftphone] Full Error Object:', JSON.stringify(error));
                
                this.showToast('Lỗi hệ thống', strErrorMessage, 'error');
            });
    }

    /** * Xử lý kết thúc cuộc gọi
    * @param wrapupData Dữ liệu wrapup từ Genesys
    * @created: 2025/12/29 long.nguyen.50
    */
    handleWrapup(wrapupData) {
        console.log("[fec_genesysSoftphone] handleWrapup: Resetting interaction state.", JSON.stringify(wrapupData));
        this.showToast('Wrap-up', `Đã gửi dữ liệu Wrap-up (${wrapupData.BusinessResult})`, 'info');
        this.currentInteractionCaseId = null;
    }

    /** * Điều hướng đến trang chi tiết bản ghi
    * @param recordId ID của bản ghi cần mở
    * @created: 2025/12/29 long.nguyen.50
    */
    navigateToRecord(recordId) {
        console.log(`[fec_genesysSoftphone] Navigating to record: ${recordId}`);
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { 
                recordId: recordId, 
                objectApiName: 'Case',
                actionName: 'view' 
            }
        });
    }

    /** * Hiển thị thông báo Toast trên UI
    * @created: 2025/12/29 long.nguyen.50
    */
    showToast(title, message, variant) {
        console.log(`[fec_genesysSoftphone] showToast: [${variant.toUpperCase()}] ${title} - ${message}`);
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    /** * Gửi lệnh điều khiển xuống Genesys Host (VF Page)
    * @param strAction Hành động điều khiển
    * @param objPayload Dữ liệu gửi đi
    * @created: 2026/01/02 long.nguyen.50
    */
    sendEventToGenesys(strAction, objPayload) {
        const iframe = this.template.querySelector('.iws-iframe');
        console.log(`[fec_genesysSoftphone] sendEventToGenesys: Requesting action ${strAction}`, JSON.stringify(objPayload));

        // Chuyển đổi từ lightning.force.com sang vf.force.com
        const vfOrigin = window.location.origin.replace('.sandbox.lightning.force.com', '--c.sandbox.vf.force.com');

        if (iframe && iframe.contentWindow) {
            const message = {
                source: 'lwc_to_genesys',
                action: strAction,
                data: objPayload
            };
            iframe.contentWindow.postMessage(message, vfOrigin);
            console.log('[fec_genesysSoftphone] sendEventToGenesys: Message sent successfully.');
        } else {
            console.error('[fec_genesysSoftphone] sendEventToGenesys: Error - IWS Iframe not ready.');
        }
    }

    // --- LOGGING CHO CÁC HÀM UI ---

    /** * Lấy dữ liệu từ UI và thực hiện cuộc gọi
    * @created: 2026/01/02 long.nguyen.50
    */
    handleCallClick() {
        const inputFields = this.template.querySelector('.fec-phone-input');
        const strPhoneNumber = inputFields ? inputFields.value : '';
        
        console.log(`[fec_genesysSoftphone] handleCallClick: User triggered call to ${strPhoneNumber}`);
        
        if (strPhoneNumber) {
            this.handleMakeCall(strPhoneNumber);
        } else {
            this.showToast('Thông báo', 'Vui lòng nhập số điện thoại để thực hiện cuộc gọi.', 'warning');
        }
    }

    handleSetReady() {
        console.log('[fec_genesysSoftphone] handleSetReady: Agent clicked Ready button.');
        this.sendEventToGenesys('READY', {});
    }

    handleMakeCall(phoneNumber) {
        console.log(`[fec_genesysSoftphone] handleMakeCall: Dialing number ${phoneNumber}`);
        this.sendEventToGenesys('MAKE_CALL', {
            number: phoneNumber,
            params: null
        });
    }
}