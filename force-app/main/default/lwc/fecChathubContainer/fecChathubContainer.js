import { LightningElement, track, wire } from 'lwc';
import getChatHubInfo from '@salesforce/apex/FEC_ChatHubInitController.getChatHubInfo';
import createCaseOnNewSession from '@salesforce/apex/FEC_ChatHubCaseController.createCaseOnNewSession';
import saveChatHistoryAndAttachment from '@salesforce/apex/FEC_ChatHubCaseController.saveChatHistoryAndAttachment';

const CHATHUB_URL_KEY = 'chathub_url';
// Định dạng log để dễ nhìn trong Console
const LOG_PREFIX = '%c[FEC-ChatHub] '; 
const LOG_STYLE = 'color: #fff; background: #0070d2; padding: 2px 5px; border-radius: 4px; font-weight: bold;';
const LOG_INFO = 'color: #0070d2; font-weight: bold;';
const LOG_WARN = 'color: #ff9900; font-weight: bold;';
const LOG_ERROR = 'color: #c23934; font-weight: bold;';

export default class FecChathubContainer extends LightningElement {
    @track isChatHubVisible = false;
    @track isInitialized = false;
    @track chatHubUrl = '';
    @track chatHubUsername = '';
    
    // --- 1. KHỞI TẠO ---
    @wire(getChatHubInfo)
    wiredChatHubInfo({ error, data }) {
        if (data) {
            console.groupCollapsed(LOG_PREFIX + 'Init Config', LOG_STYLE);
            console.log('Raw Data:', data);
            
            const parts = data.split('|');
            if (parts.length >= 3) {
                this.chatHubUsername = parts[0];
                const urlChatHub = parts[1];
                const usernameEncrypted = parts[2];
                
                localStorage.setItem(CHATHUB_URL_KEY, urlChatHub);
                
                // Dynamic Handshake
                const currentOrigin = window.location.origin;
                let finalUrl = this.encryptUrl(urlChatHub, usernameEncrypted);
                finalUrl = finalUrl + '&parentOrigin=' + encodeURIComponent(currentOrigin);
                
                console.log('ChatHub URL:', finalUrl);
                this.chatHubUrl = finalUrl;

                this.isInitialized = true;
                this.isChatHubVisible = true;
                
                window.addEventListener('message', this.handleMessage.bind(this));
                console.log('%c✅ Event Listener Added', 'color:green');
            } else {
                console.warn('%c⚠ Invalid Config Format', LOG_WARN);
            }
            console.groupEnd();
        } else if (error) {
            console.error(LOG_PREFIX + 'Apex Init Error:', LOG_STYLE, error);
        }
    }
    
    disconnectedCallback() {
        window.removeEventListener('message', this.handleMessage.bind(this));
        console.log(LOG_PREFIX + 'Disconnected - Listener Removed', LOG_STYLE);
    }

    encryptUrl(strUrl, strToken) {
        try {
            const url = new URL(strUrl);
            url.pathname = encodeURIComponent(strToken);
            return url.toString();
        } catch (e) { return strUrl; }
    }

    // --- 2. XỬ LÝ SỰ KIỆN TỪ CHATHUB (MAIN SWITCH) ---

    handleMessage(event) {
        const trustedUrl = localStorage.getItem(CHATHUB_URL_KEY);
        
        // Log Origin để debug nếu không nhận được tin nhắn
        // console.log('DEBUG Origin:', event.origin, 'Expected:', trustedUrl);

        // Uncomment dòng dưới khi chạy Production để bảo mật
        // if (!trustedUrl || (event.origin !== new URL(trustedUrl).origin)) return;

        const { action, data } = event.data;
        
        // Chỉ log những event có action (bỏ qua rác từ các extension khác)
        if(action) {
            console.group(LOG_PREFIX + '📩 RECEIVED: ' + action, LOG_STYLE);
            console.log('%cPayload:', LOG_INFO, JSON.parse(JSON.stringify(data || {})));
        }

        switch (action) {
            case 'createCaseRequest':
                this.handleCreateCaseRequest(data);
                break;

            case 'newChatRequest':
                this.handleNewChatRequest(data);
                break;

            case 'endChat':
                this.handleEndChat(data);
                break;

            case 'sessionHistoryById': 
                this.handleSessionHistory(data);
                break;
            
            case 'pegaCheckIsAgentAvailable':
                 // Log nhẹ cho heartbeat (không cần group)
                 // console.debug('💓 Heartbeat check');
                 this.postMessageToChatHub('isAgentAvailable', true);
                 break;

            default:
                if(action) console.warn('%c⚠ Unhandled Action:', LOG_WARN, action);
        }
        
        if(action) console.groupEnd();
    }

    // --- 3. IMPLEMENT CHI TIẾT ---

    async handleCreateCaseRequest(data) {
        try {
            console.log('🚀 Calling Apex: createCaseOnNewSession...');
            const payload = JSON.stringify(data);
            
            const caseId = await createCaseOnNewSession({ strJsonData: payload });

            if (caseId) {
                console.log('%c✅ Case Found/Created: ' + caseId, 'color:green; font-weight:bold');
                
                const responsePayload = {
                    sessionID: data.chatSession.sessionID,
                    pegaID: caseId,
                    chatChannel: data.chatSession.chatChannel
                };
                this.postMessageToChatHub('pegaCsmCaseInfo', responsePayload);
            } else {
                console.warn('%c⚠ Apex returned null (Duplicate check or Error)', LOG_WARN);
            }
        } catch (error) {
            console.error('%c❌ Error in handleCreateCaseRequest:', LOG_ERROR, error);
        }
    }

    async handleNewChatRequest(data) {
        console.log('🔄 Processing New Chat Request...');

        // 1. Áp dụng logic Transform giống Pega (Xử lý file/image và time)
        const processedData = this.transformRawDataToChatHistory(data);
        console.log('Transformed Data:', processedData);
        
        const transformedData = {
            chatSession: {
                sessionID: data.sessionID,
                chatChannel: data.chatChannel,
                agentID: data.agentName || this.chatHubUsername,
                chatID: data.chatID,
                lastMessage: processedData.message
            },
            customerInfo: {
                customerName: data.senderName,
                phoneNumber: '', 
                nationalID: '',
                kYCStatus: 'Unknown'
            }
        };

        console.log('Transformed Payload:', transformedData);
        await this.handleCreateCaseRequest(transformedData);
    }

    /**
     * Xử lý messageType là attachment/image và format ngày tháng
     */
    transformRawDataToChatHistory(chatData) {
        // Clone object để không ảnh hưởng data gốc
        let chat = JSON.parse(JSON.stringify(chatData));

        if (chat.messageType === "attachment" || chat.messageType === "image") {
            // Logic: Tạo tên file có timestamp prefix
            const formattedFileName = this.formatFilenameWithDateTime(chat.fileName || 'unknown_file', chat.createdAt);
            
            // Logic: Encode URL
            const fileUrl = encodeURI(chat.message);

            // Cập nhật lại object
            chat.fileName = formattedFileName;
            chat.fileUrl = fileUrl;
            // Logic: Đổi message thành tên file để hiển thị trong Case Subject/Description
            chat.message = "[" + formattedFileName + "]";
        }

        // Logic: Format lại thời gian
        chat.createdAt = this.formatDatetime(chat.createdAt, false);

        return chat;
    }

    formatFilenameWithDateTime(filename, time) {
        const formattedDate = this.formatDatetime(time, true);
        return formattedDate + "_" + filename;
    }

    /**
     * Output: YYYYMMDDThhmmss.0 GMT
     */
    formatDatetime(timeString, onlyNumber) {
        const d = new Date(timeString);
        
        // Lưu ý: Pega dùng getUTC... nên ta cũng dùng UTC để khớp
        const year = "" + (d.getUTCFullYear());
        const month = ("" + (d.getUTCMonth() + 1)).padStart(2, "0");
        const day = ("" + d.getUTCDate()).padStart(2, "0");
        const hour = ("" + d.getUTCHours()).padStart(2, "0");
        const min = ("" + d.getUTCMinutes()).padStart(2, "0");
        const second = ("" + d.getUTCSeconds()).padStart(2, "0");

        let result = year + month + day;
        if (!onlyNumber) {
            result += "T";
        }
        result += hour + min + second;
        if (!onlyNumber) {
            result += ".0 GMT";
        }
        return result;
    }

    handleEndChat(data) {
        console.log('➤ End Chat Triggered. Requesting Full History...');
        
        const historyRequest = {
            chatID: data.chatID,
            sessionID: data.sessionID,
            selectedFilter: "all",
            selectedChannel: "newest", 
            page: 1,
            size: 1000
        };

        this.postMessageToChatHub('pegaGetSessionHistory', historyRequest);
    }

    async handleSessionHistory(data) {
        if (!data || data.length === 0) {
            console.warn('%c⚠ History Data is Empty', LOG_WARN);
            return;
        }

        console.log(`➤ Saving ${data.length} messages to Salesforce...`);
        try {
            const payload = JSON.stringify(data);
            const success = await saveChatHistoryAndAttachment({ strJsonData: payload });
            
            if (success) {
                console.log('%c✅ History Saved Successfully', 'color:green; font-weight:bold');
            } else {
                console.error('%c❌ Save Failed (Check Apex Debug Log)', LOG_ERROR);
            }
        } catch (error) {
            console.error('%c❌ Error calling saveChatHistoryAndAttachment:', LOG_ERROR, error);
        }
    }

    // --- 4. HELPER ---

    postMessageToChatHub(action, data) {
        const iframe = this.template.querySelector('iframe');
        const targetUrl = localStorage.getItem(CHATHUB_URL_KEY);

        console.log(`%c📤 SENDING: ${action}`, 'color: #9c27b0; font-weight: bold;', data);

        if (iframe) {
            // Nếu có targetUrl thì gửi đích danh, nếu không (mock) thì gửi '*'
            const target = targetUrl ? targetUrl : '*';
            iframe.contentWindow.postMessage({ action, data }, target);
        } else {
            console.error('%c❌ Iframe not found!', LOG_ERROR);
        }
    }
}