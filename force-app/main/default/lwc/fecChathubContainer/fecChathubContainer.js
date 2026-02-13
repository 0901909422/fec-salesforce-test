import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getChatHubInfo from '@salesforce/apex/FEC_ChatHubInitController.getChatHubInfo';
import createCaseOnNewSession from '@salesforce/apex/FEC_ChatHubCaseController.createCaseOnNewSession';
import saveChatHistoryAndAttachment from '@salesforce/apex/FEC_ChatHubCaseController.saveChatHistoryAndAttachment';
import checkExistCaseByExtInteractionID from '@salesforce/apex/FEC_Utils.checkExistCaseByExtInteractionID';
import downloadAndSaveBase64 from '@salesforce/apex/FEC_AttachmentController.downloadAndSaveBase64';
import formatDateTimeToString from '@salesforce/apex/FEC_Utils.formatDateTimeToString';

const CHATHUB_URL_KEY = 'https://portal-chathub-uat.fecredit.cloud';
// Định dạng log để dễ nhìn trong Console
const LOG_PREFIX = '%c[FEC-ChatHub] ';
const LOG_STYLE = 'color: #fff; background: #0070d2; padding: 2px 5px; border-radius: 4px; font-weight: bold;';
const LOG_INFO = 'color: #0070d2; font-weight: bold;';
const LOG_WARN = 'color: #ff9900; font-weight: bold;';
const LOG_ERROR = 'color: #c23934; font-weight: bold;';
const PREFIX_INTERACTION_CASE_REASSIGN = "CHATHUB_IC_RS_";
export default class FecChathubContainer extends LightningElement {
    @track isChatHubVisible = false;
    @track isInitialized = false;
    @track chatHubUrl = '';
    @track chatHubUsername = '';
    @track localStorageUsername = "chathub_username";

    // --- 1. KHỞI TẠO ---
    @wire(getChatHubInfo)
    wiredChatHubInfo({ error, data }) {
        if (data) {
            // console.groupCollapsed(LOG_PREFIX + 'Init Config', LOG_STYLE);
            // console.log('Raw Data:', data);

            const parts = data.split('|');
            if (parts.length >= 3) {
                this.chatHubUsername = parts[0];
                // console.log('this.chatHubUsername: ' + this.chatHubUsername);
                const urlChatHub = parts[1];
                const usernameEncrypted = parts[2];

                localStorage.setItem(CHATHUB_URL_KEY, urlChatHub);
                this.updateUsername(this.chatHubUsername);
                // Dynamic Handshake
                const currentOrigin = window.location.origin;
                let finalUrl = this.encryptUrl(urlChatHub, usernameEncrypted);
                finalUrl = finalUrl + '&parentOrigin=' + encodeURIComponent(currentOrigin);

                // console.log('ChatHub URL:', finalUrl);
                this.chatHubUrl = finalUrl;

                this.isInitialized = true;
                this.isChatHubVisible = true;

                window.addEventListener('message', this.handleMessage.bind(this));
                // console.log('%c✅ Event Listener Added', 'color:green');
            } else {
                // console.warn('%c⚠ Invalid Config Format', LOG_WARN);
            }
            // console.groupEnd();
        } else if (error) {
            console.error(LOG_PREFIX + 'Apex Init Error:', LOG_STYLE, error);
        }
    }

    disconnectedCallback() {
        window.removeEventListener('message', this.handleMessage.bind(this));
        // console.log(LOG_PREFIX + 'Disconnected - Listener Removed', LOG_STYLE);
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
        console.log('event: ', event);
        // Log Origin để debug nếu không nhận được tin nhắn
        // console.log('DEBUG Origin:', event.origin, 'Expected:', trustedUrl);

        // Uncomment dòng dưới khi chạy Production để bảo mật
        // if (!trustedUrl || (event.origin !== new URL(trustedUrl).origin)) return;

        const { action, data } = event.data;

        // Chỉ log những event có action (bỏ qua rác từ các extension khác)
        if (action) {
            // console.group(LOG_PREFIX + '📩 RECEIVED: ' + action, LOG_STYLE);
            console.log(LOG_PREFIX + '📩 RECEIVED: ' + action, LOG_STYLE);
            console.log('%cPayload:', LOG_INFO, JSON.parse(JSON.stringify(data || {})));
        }

        switch (action) {
            case 'createCaseRequest':
                this.handleCreateCaseRequest(data);
                break;

            case 'newChatRequest':
                this.saveAttachmentNewMessage(data);
                break;

            case 'endChat':
                this.handleEndChat(data);
                break;

            case 'sessionHistoryById':
                // console.log('CHAY VAO EVENT SESSION HISTORY BY ID');
                this.handleSessionHistory(data);
                break;

            case 'pegaCheckIsAgentAvailable':
                this.postMessageToChatHub('isAgentAvailable', true);
                break;

            default:
            // if (action) console.warn('%c⚠ Unhandled Action:', LOG_WARN, action);
        }

        // if (action) console.groupEnd();
    }

    // --- 3. IMPLEMENT CHI TIẾT ---

    handleCreateCaseRequest(data) {
        console.log('🚀 Calling Apex: createCaseOnNewSession...');
        console.log('data: ', data);
        const payload = JSON.stringify(data);
        if (!this.verifyUsernameAndAgent(data)) {
            return;
        }

        createCaseOnNewSession({ strJsonData: payload })
            .then(caseId => {
                if (caseId) {
                    // Send back the Case ID (PegaID) to ChatHub
                    const response = {
                        sessionID: data.chatSession.sessionID,
                        pegaID: caseId,
                        chatChannel: data.chatSession.chatChannel
                    };
                    // console.log('response create case: ', response);
                    this.postMessageToChatHub('pegaCsmCaseInfo', response);
                    this.showToast('Thành công', `Đã tạo Case tương tác: ${caseId || ''}`, 'success');
                    this.navigateToRecord(caseId);
                }
            })
            .catch(error => {
                // console.warn('%c⚠ Apex returned null (Duplicate check or Error)', LOG_WARN, error);
            });
    }

    handleEndChat(data) {
        //new code
        // console.log('handleEndChat data: ');
        // console.log(data);
        if (!this.verifyUsernameAndAgent(data)) {
            return;
        }
        //
        // console.log('➤ End Chat Triggered. Requesting Full History...');

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

    handleSessionHistory(data) {
        if (!data || data.length === 0) {
            // console.warn('%c⚠ History Data is Empty', LOG_WARN);
            return;
        }

        // console.log(`handleSessionHistory data:`);
        // console.log(data);
        // console.log(`➤ Saving ${data.length} messages to Salesforce...`);
        const payload = JSON.stringify(data);


        // Note: Chưa save attachemnt
        saveChatHistoryAndAttachment({ strJsonData: payload })
            .then(success => {
                if (success) {
                    this.showToast('Success', 'Chat history saved successfully.', 'success');
                }
            })
            .catch(error => {
                // console.error('%c❌ Error calling saveChatHistoryAndAttachment:', LOG_ERROR, error);
            });
    }

    async saveAttachmentNewMessage(data) {
        // console.log('data attachment: ');
        // console.log(data);
        if (data && (data.messageType === 'attachment' || data.messageType === 'image')) {
            if (!this.verifyUsernameAndAgent(data)) {
                return;
            }

            if (!data.createdAt.includes("GMT")) {
                data.createdAt += " GMT";
            }
            // console.log('data attachment 1 layer: ');
            // console.log(data);
            const rawChatHistories = [data];
            const result = this.transformRawDataToChatHistory(rawChatHistories);
            // console.log(result)
            const chatHistories = result.chatHistories;
            const attachments = result.attachments;

            const attachmentsCopy = attachments.slice();

            // console.log('attachmentsCopy: ');
            // console.log(attachmentsCopy.length);
            // console.log(attachmentsCopy[0]);
            if (attachmentsCopy.length > 0) {
                // a
                // console.log('sessionID for checking exist case: ' + data.sessionID);
                // Chỗ này đang check dùng sessionID check trên Case salesforce thế nào
                const result = await checkExistCaseByExtInteractionID({ strExtInteractionID: data.sessionID });
                // console.log('Result checkExistCaseByExtInteractionID: ');
                // console.log(result);
                // const date = new Date(data.createdAt);
                // const stringDateConvert = await formatDateTimeToString({dtDateTime:date.toISOString()});
                // console.log('stringDateConvert: ' + stringDateConvert);
                // const fileName = stringDateConvert + data.fileName;
                // console.log('fileName: ' + fileName);

                // test xem các link s3 có chặn CORS không
                this.fetchFileFromUrl(data.fileUrl);
                //
                downloadAndSaveBase64({
                    s3Url: data.fileUrl,
                    interactionCaseId: result,
                    fileName: data.fileName,
                })
                    .then(() => {
                        this.showToast('Thành công', 'File đã được tải và lưu vào Case.', 'success');
                        console.log('attachment Thành công!');
                    })
                    .catch(error => {
                        this.showToast('Lỗi', 'Không thể tải và lưu file.', 'error');
                        // console.error('Lỗi Apex:', error);
                    });
            }
        }
    }

    transformRawDataToChatHistory(rawChatHistories) {
        let chatHistories = rawChatHistories;

        chatHistories.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
        // console.log('chathistorys: ');
        // console.log(chatHistories.length);
        const attachments = [];

        for (var i = 0; i < chatHistories.length; i++) {
            const chat = chatHistories[i];
            // console.log('chat');
            // console.log(chat);
            if (chat.messageType === "attachment" || chat.messageType === "image") {
                const attachment_obj = {
                    FileName: this.formatFilenameWithDateTime(chat.fileName, chat.createdAt, false),
                    FileUrl: encodeURI(chat.message)
                };

                attachments.push(attachment_obj);
                chatHistories[i].fileName = attachment_obj.FileName;
                chatHistories[i].fileUrl = attachment_obj.FileUrl;
                chatHistories[i].message = "[" + attachment_obj.FileName + "]"
                if (chatHistories[i].fileUrl.length > 1000) {
                    alert('File URL ' + chatHistories[i].fileUrl + ' exceeded max length 1000 characters. Please contact administrator');
                }
            }
            // console.log('formatDatetime for chat.createdAt: ' + chat.createdAt);
            chatHistories[i].createdAt = this.formatDatetime(chat.createdAt, false);
        }
        chatHistories = chatHistories.map((data) => {
            return Object.keys(data).reduce((obj, key) => {
                obj[key.charAt(0).toUpperCase() + key.slice(1)] = data[key];
                return obj;
            }, {});
        });
        // console.log('result transform');
        // console.log({
        //     chatHistories: chatHistories,
        //     attachments: attachments
        // })
        return {
            chatHistories: chatHistories,
            attachments: attachments
        }
    }

    // --- 4. HELPER ---


    // new code test CORS
    async fetchFileFromUrl(fileUrl) {
        try {
            // console.log('Fetching file from URL: ' + fileUrl);
            const response = await fetch(fileUrl);

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const blob = await response.blob();
            // console.log('File fetched successfully. Size: ' + blob.size + ' bytes');
            return blob;
        } catch (error) {
            // console.error('%cError fetching file:', LOG_ERROR, error);
            throw error;
        }
    }


    postMessageToChatHub(action, data) {
        const iframe = this.template.querySelector('iframe');
        const targetUrl = localStorage.getItem(CHATHUB_URL_KEY);

        // console.log(`%c📤 SENDING: ${action}`, 'color: #9c27b0; font-weight: bold;', data);

        if (iframe) {
            // Nếu có targetUrl thì gửi đích danh, nếu không (mock) thì gửi '*'
            const target = targetUrl ? targetUrl : '*';
            iframe.contentWindow.postMessage({ action, data }, target);
        } else {
            // console.error('%c❌ Iframe not found!', LOG_ERROR);
        }
    }

    /** * Điều hướng đến trang chi tiết bản ghi
    * @param recordId ID của bản ghi cần mở
    * @created: 2025/12/29 long.nguyen.50
    */
    navigateToRecord(recordId) {
        // console.log(`Navigating to record: ${recordId}`);
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
        // console.log(`showToast: [${variant.toUpperCase()}] ${title} - ${message}`);
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    updateUsername(username) {
        localStorage.setItem(this.localStorageUsername, username);
    };

    formatFilenameWithDateTime(filename, time, onlyNumber = true) {
        const formattedDate = this.formatDatetime(time, onlyNumber);
        return formattedDate + "_" + filename;
    }
    formatDatetime(timeString, onlyNumber) {
        const d = new Date(timeString);
        // console.log('formatDatetime input: ' + timeString);
        // console.log('formatDatetime date object: ' + d);
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
        // console.log('formatDatetime result: ' + result);
        return result;
    }

    checkReAssignSessionID(sessionID) {
        const value = localStorage.getItem(PREFIX_INTERACTION_CASE_REASSIGN + sessionID);
        if (value) {
            return true;
        }
        return false;
    }

    addReAssignSessionID(sessionID) {
        localStorage.setItem(PREFIX_INTERACTION_CASE_REASSIGN + sessionID, Date.now());
    }

    removeReAssignSessionID(sessionID) {
        localStorage.removeItem(PREFIX_INTERACTION_CASE_REASSIGN + sessionID);
    }

    verifyUsernameAndAgent(data) {
        // console.log('vao this.verifyUsernameAndAgent: ');
        if (!data.chatSession && !data.agentName && !data.senderName) {
            return false;
        }
        let agentID = data.chatSession ? data.chatSession.agentID : data.agentName ? data.agentName : data.senderName;
        if (!agentID.includes('@fecredit.com.vn')) {
            agentID += '@fecredit.com.vn.fecdevlong';
        }
        // console.log('agentID after append domain: ' + agentID);
        if (this.chatHubUsername && this.chatHubUsername != agentID) {
            // console.error('%cERRY EXIT: Username mismatch', LOG_WARN, `Expected: ${this.chatHubUsername}, Got: ${agentID}`);
            return false;
        }
        return true;
    }
}