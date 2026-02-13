import { LightningElement, api, wire } from 'lwc';
import getChatMessages from '@salesforce/apex/FEC_ChatHistoryController.getChatMessages';
import Id from '@salesforce/user/Id'; // Lấy ID của user đang đăng nhập

export default class ChatHistory extends LightningElement {
    @api recordId;
    currentUserId = Id;
    chatMessages;
    error;

    @wire(getChatMessages, { caseId: '$recordId' })
    wiredMessages({ error, data }) {
        if (data) {
            const messages = data.messages;
            const fileMap = data.fileMap;
            console.log('messages: ', messages);
            console.log('fileMap: ', fileMap);
            console.log('this.messageData: ', data);
            this.chatMessages = messages.map(msg => {
                console.log('msg: ', msg);
                // Logic: Nếu người tạo record là user` hiện tại thì coi là tin nhắn đi (Outbound)
                const isOutbound = msg.FEC_IsAgent__c;


                const isFile = msg.FEC_MessageType__c === 'attachment' || msg.FEC_MessageType__c === 'image';

                let downloadUrl = null;
                let fileName = msg.FEC_Message__c;
                if (isFile) {
                    // Tìm ID file dựa vào tên được lưu trong message
                    const fileId = fileMap[fileName];
                    if (fileId) {
                        downloadUrl = `/sfc/servlet.shepherd/version/download/${fileId}`;
                    }
                }

                return {
                    ...msg,
                    isOutbound,
                    isFile, // Biến cờ để dùng trong HTML
                    isText: !isFile,
                    downloadUrl,
                    fileName,
                    bodyClass: isOutbound ? 'container-chat-history__body--outbound w-full' : 'container-chat-history__body--inbound w-full',
                    itemClass: isOutbound ? 'slds-chat-list__item slds-chat-list__item_outbound' : 'slds-chat-list__item slds-chat-list__item_inbound',
                    bubbleClass: isOutbound ? 'slds-chat-message__text slds-chat-message__text_outbound' : 'slds-chat-message__text slds-chat-message__text_inbound',
                    formattedTime: new Date(msg.FEC_CreatedAt__c).toLocaleString()
                };
            });
        } else if (error) {
            this.error = error;
        }
    }
}