import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getChatHubInfo from '@salesforce/apex/FEC_ChatHubInitController.getChatHubInfo';
import createCaseOnNewSession from '@salesforce/apex/FEC_ChatHubCaseController.createCaseOnNewSession';
import saveChatHistoryAndAttachment from '@salesforce/apex/FEC_ChatHubCaseController.saveChatHistoryAndAttachment';
import checkExistCaseByExtInteractionID from '@salesforce/apex/FEC_Utils.checkExistCaseByExtInteractionID';
import downloadAndSaveBase64 from '@salesforce/apex/FEC_AttachmentController.downloadAndSaveBase64';
import attachFileToInteractionCase from '@salesforce/apex/FEC_AttachmentController.attachFileToInteractionCase';
import { executeWithLock, fetchFileFromUrl, formatDatetime, showToast, decryptDataKYC } from 'c/fecUtils';

const CHATHUB_URL_KEY = 'https://portal-chathub-uat.fecredit.cloud';
// Log formatting for better console visibility
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
    #secretKey = '4mX2SmAeoLy9n8c1zsEpH+L37XrwsCGxvc1tAyOdaTpxgcOQuXitLA==';

    // --- 1. INITIALIZATION ---
    /**
     * Wire adapter to fetch ChatHub configuration
     * @param {Object} error - Error object if request fails
     * @param {string} data - Configuration data in format: username|url|encrypted_token
     * @return {void}
     */
    @wire(getChatHubInfo)
    wiredChatHubInfo({ error, data }) {
        if (data) {
            console.groupCollapsed(LOG_PREFIX + 'Init Config', LOG_STYLE);
            const parts = data.split('|');
            if (parts.length >= 3) {
                this.chatHubUsername = parts[0];
                const urlChatHub = parts[1];
                const usernameEncrypted = parts[2];
                localStorage.setItem(CHATHUB_URL_KEY, urlChatHub);
                this.updateUsername(this.chatHubUsername);
                // Dynamic Handshake - Encrypt URL with parent origin for security
                const currentOrigin = window.location.origin;
                let finalUrl = this.encryptUrl(urlChatHub, usernameEncrypted);
                finalUrl = finalUrl + '&parentOrigin=' + encodeURIComponent(currentOrigin);
                this.chatHubUrl = finalUrl;
                this.isInitialized = true;
                this.isChatHubVisible = true;
                window.addEventListener('message', this.handleMessage.bind(this));
                console.log('%c✅ Event Listener Added', 'color:green');
            } else {
                console.warn('%c⚠ Invalid Config Format', LOG_WARN);
            }
            // console.groupEnd();
        } else if (error) {
            console.error(LOG_PREFIX + 'Apex Init Error:', LOG_STYLE, error);
        }
    }

    /**
     * Lifecycle hook called when component is removed from DOM
     * Cleans up message event listener
     * @return {void}
     */
    disconnectedCallback() {
        window.removeEventListener('message', this.handleMessage.bind(this));
        console.log(LOG_PREFIX + 'Disconnected - Listener Removed', LOG_STYLE);
    }

    /**
     * Encrypts URL by encoding token in pathname
     * @param {string} strUrl - Base URL
     * @param {string} strToken - Token to encode in URL
     * @return {string} - Encrypted URL or original URL if error occurs
     */
    encryptUrl(strUrl, strToken) {
        try {
            const url = new URL(strUrl);
            url.pathname = encodeURIComponent(strToken);
            return url.toString();
        } catch (e) { return strUrl; }
    }

    // --- 2. HANDLE EVENTS FROM CHATHUB (MAIN SWITCH) ---

    /**
     * Handles postMessage events from ChatHub iframe
     * Validates origin and routes messages to appropriate handlers
     * @param {MessageEvent} event - Event object containing action and data
     * @return {void}
     */
    handleMessage(event) {
        const trustedUrl = localStorage.getItem(CHATHUB_URL_KEY);
        console.log('event: ', event);
        // Log origin for debugging if messages are not received
        // console.log('DEBUG Origin:', event.origin, 'Expected:', trustedUrl);

        // Uncomment the line below when running in Production for security
        // if (!trustedUrl || (event.origin !== new URL(trustedUrl).origin)) return;

        const { action, data } = event.data;

        // Only log events with action (ignore noise from other extensions)
        if (action) {
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
                this.handleSessionHistory(data);
                break;

            case 'pegaCheckIsAgentAvailable':
                this.postMessageToChatHub('isAgentAvailable', true);
                break;

            default:
                if (action) console.warn('%c⚠ Unhandled Action:', LOG_WARN, action);
        }

        if (action) console.groupEnd();
    }

    // --- 3. DETAILED IMPLEMENTATIONS ---

    /**
     * Handles case creation request from ChatHub
     * Creates a new Case record and sends back the Case ID to ChatHub
     * @param {Object} data - Request data containing chat session and customer info
     * @return {void}
     */
    async handleCreateCaseRequest(data) {
        console.log('🚀 Calling Apex: createCaseOnNewSession...');
        console.log('data: ', data);
        if (data.customerInfo.nationalID !== '') {
            const dataNationID = await decryptDataKYC(data.customerInfo.nationalID, this.#secretKey)
            data.customerInfo.nationalID = dataNationID;
        }
        if (data.customerInfo.phoneNumber !== '') {
            const dataPhoneNumber = await decryptDataKYC(data.customerInfo.phoneNumber, this.#secretKey)
            data.customerInfo.phoneNumber = dataPhoneNumber;
        }
        const payload = JSON.stringify(data);
        console.log('payload', payload);
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
                    this.postMessageToChatHub('pegaCsmCaseInfo', response);
                    showToast(this, 'Thành công', `Đã tạo Case tương tác: ${caseId || ''}`, 'success');
                    this.navigateToRecord(caseId);
                }
            })
            .catch(error => {
                console.warn('%c⚠ Apex returned null (Duplicate check or Error)', LOG_WARN, error);
            });
    }

    /**
     * Handles end chat action from ChatHub
     * Requests full session history before closing chat
     * @param {Object} data - Chat session data
     * @return {void}
     */
    handleEndChat(data) {
        if (!this.verifyUsernameAndAgent(data)) {
            return;
        }
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

    /**
     * Processes and saves chat session history
     * Uses Web Locks API to prevent duplicate processing across multiple tabs
     * @param {Array} data - Array of chat history records
     * @return {void}
     */
    handleSessionHistory(data) {
        if (!data || data.length === 0) {
            console.warn('%c⚠ History Data is Empty', LOG_WARN);
            return;
        }
        // Create unique lock identifier for the entire history batch of this session
        const sessionId = data[0].sessionID;
        const lockName = 'LOCK_HISTORY_' + sessionId;

        // Encapsulate Apex call logic
        const processHistoryAction = async () => {
            const payload = JSON.stringify(data);
            try {
                const success = await saveChatHistoryAndAttachment({ strJsonData: payload });
                if (success) {
                    showToast(this, 'Success', 'Chat history saved successfully.', 'success');
                }
            } catch (error) {
                console.error('[FEC-ChatHub] Lỗi gọi saveChatHistoryAndAttachment:', error);
            }
        };

        // Call lock function (true parameter ensures active tab is prioritized)
        executeWithLock(lockName, processHistoryAction, true);
    }

    /**
     * Handles attachment or image message from new chat
     * Validates user and processes file with lock mechanism
     * @param {Object} data - Message data containing file information
     * @return {Promise<void>}
     */
    async saveAttachmentNewMessage(data) {
        if (data && (data.messageType === 'attachment' || data.messageType === 'image')) {
            if (!this.verifyUsernameAndAgent(data)) return;

            const uniqueMessageId = data.sessionID + '_' + data.createdAt;
            const lockName = 'LOCK_FILE_' + uniqueMessageId;

            // Encapsulate file processing logic in arrow function
            const processFileAction = async () => {
                await this.processAndSaveFile(data, uniqueMessageId);
            };

            // Call shared lock function (true parameter maintains active tab priority)
            await executeWithLock(lockName, processFileAction, true);

        }
    }

    /**
     * Processes file attachment and saves to Salesforce
     * Downloads file from URL and attaches to Case
     * @param {Object} data - File data containing URL and metadata
     * @param {string} uniqueMessageId - Unique identifier for the message
     * @return {Promise<void>}
     */
    async processAndSaveFile(data, uniqueMessageId) {
        if (!data.createdAt.includes("GMT")) {
            data.createdAt += " GMT";
        }
        const rawChatHistories = [data];
        const transformResult = this.transformRawDataToChatHistory(rawChatHistories);
        const attachments = transformResult.attachments;

        if (attachments.length > 0) {
            try {
                const caseId = await checkExistCaseByExtInteractionID({ strExtInteractionID: data.sessionID });

                fetchFileFromUrl(data.fileUrl); // Test CORS

                await downloadAndSaveBase64({
                    s3Url: data.fileUrl,
                    interactionCaseId: caseId,
                    fileName: data.fileName,
                    uniqueMessageId: uniqueMessageId
                });

                showToast(this, 'Thành công', 'File đã được tải và lưu vào Case.', 'success');
            } catch (error) {
                showToast(this, 'Lỗi', 'Không thể tải và lưu file.', 'error');
                console.error('Lỗi Apex:', error);
            }
        }
    }

    /**
     * Transforms raw chat data into formatted chat history records
     * Handles filename formatting, URL encoding, and field name capitalization
     * @param {Array} rawChatHistories - Array of raw chat message objects
     * @return {Object} - Object containing formatted chatHistories and attachments arrays
     */
    transformRawDataToChatHistory(rawChatHistories) {
        let chatHistories = rawChatHistories;

        // Sort by creation date in ascending order
        chatHistories.sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt));
        const attachments = [];

        for (var i = 0; i < chatHistories.length; i++) {
            const chat = chatHistories[i];
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
            chatHistories[i].createdAt = formatDatetime(chat.createdAt, false);
        }
        chatHistories = chatHistories.map((data) => {
            return Object.keys(data).reduce((obj, key) => {
                obj[key.charAt(0).toUpperCase() + key.slice(1)] = data[key];
                return obj;
            }, {});
        });
        return {
            chatHistories: chatHistories,
            attachments: attachments
        }
    }

    // --- 4. HELPER FUNCTIONS ---

    /**
     * Sends postMessage to ChatHub iframe
     * @param {string} action - Action identifier for the message
     * @param {Object} data - Data payload to send
     * @return {void}
     */
    postMessageToChatHub(action, data) {
        const iframe = this.template.querySelector('iframe');
        const targetUrl = localStorage.getItem(CHATHUB_URL_KEY);

        console.log(`%c📤 SENDING: ${action}`, 'color: #9c27b0; font-weight: bold;', data);

        if (iframe) {
            // If targetUrl exists, send to specific origin, otherwise send to '*' (mock)
            const target = targetUrl ? targetUrl : '*';
            iframe.contentWindow.postMessage({ action, data }, target);
        } else {
            console.error('%c❌ Iframe not found!', LOG_ERROR);
        }
    }

    /**
     * Navigates to record detail page
     * @created: 2025/12/29 long.nguyen.50
     * @param {string} recordId - ID of the record to open
     * @return {void}
     */
    navigateToRecord(recordId) {
        console.log(`Navigating to record: ${recordId}`);
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Case',
                actionName: 'view'
            }
        });
    }

    /**
     * Updates username in local storage
     * @param {string} username - Username to store
     * @return {void}
     */
    updateUsername(username) {
        localStorage.setItem(this.localStorageUsername, username);
    };

    /**
     * Formats filename by prepending formatted datetime
     * @param {string} filename - Original filename
     * @param {string} time - Timestamp string
     * @param {boolean} onlyNumber - If true, format as YYYYMMDDhhmmss, else YYYYMMDDThhmm.0 GMT
     * @return {string} - Formatted filename with datetime prefix
     */
    formatFilenameWithDateTime(filename, time, onlyNumber = true) {
        const formattedDate = formatDatetime(time, onlyNumber);
        return formattedDate + "_" + filename;
    }

    /**
     * Checks if session ID has been marked for reassignment
     * @param {string} sessionID - Session identifier
     * @return {boolean} - True if session is marked for reassignment
     */
    checkReAssignSessionID(sessionID) {
        const value = localStorage.getItem(PREFIX_INTERACTION_CASE_REASSIGN + sessionID);
        if (value) {
            return true;
        }
        return false;
    }

    /**
     * Marks session ID for reassignment in local storage
     * @param {string} sessionID - Session identifier
     * @return {void}
     */
    addReAssignSessionID(sessionID) {
        localStorage.setItem(PREFIX_INTERACTION_CASE_REASSIGN + sessionID, Date.now());
    }

    /**
     * Removes session ID reassignment marker from local storage
     * @param {string} sessionID - Session identifier
     * @return {void}
     */
    removeReAssignSessionID(sessionID) {
        localStorage.removeItem(PREFIX_INTERACTION_CASE_REASSIGN + sessionID);
    }

    /**
     * Verifies that username and agent information match current user
     * @param {Object} data - Object containing chatSession, agentName, or senderName
     * @return {boolean} - True if verification passes, false otherwise
     */
    verifyUsernameAndAgent(data) {
        if (!data.chatSession && !data.agentName && !data.senderName) {
            return false;
        }
        // Extract agent ID from available fields and add domain if needed
        let agentID = data.chatSession ? data.chatSession.agentID : data.agentName ? data.agentName : data.senderName;
        if (!agentID.includes('@fecredit.com.vn')) {
            agentID += '@fecredit.com.vn.fecdevlong';
        }
        if (this.chatHubUsername && this.chatHubUsername != agentID) {
            console.error('%cERRY EXIT: Username mismatch', LOG_WARN, `Expected: ${this.chatHubUsername}, Got: ${agentID}`);
            return false;
        }
        return true;
    }
}