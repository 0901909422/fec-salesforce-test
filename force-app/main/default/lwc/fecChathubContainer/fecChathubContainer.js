import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { EnclosingUtilityId, minimize, getInfo, updateUtility, onUtilityClick } from 'lightning/platformUtilityBarApi';
import { notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { IsConsoleNavigation, getAllTabInfo, refreshTab } from 'lightning/platformWorkspaceApi';
import { publish, MessageContext } from 'lightning/messageService';
import FEC_CHAT_UPDATE from '@salesforce/messageChannel/FecChatUpdate__c';

import getChatHubInfo from '@salesforce/apex/FEC_ChatHubInitController.getChatHubInfo';
import createCaseOnNewSession from '@salesforce/apex/FEC_ChatHubCaseController.createCaseOnNewSession';
import saveChatHistoryAndAttachment from '@salesforce/apex/FEC_ChatHubCaseController.saveChatHistoryAndAttachment';
import checkExistCaseByExtInteractionID from '@salesforce/apex/FEC_Utils.checkExistCaseByExtInteractionID';
import updateOldCaseInteractionId from '@salesforce/apex/FEC_ChatHubCaseController.updateOldCaseInteractionId';
import downloadAndSaveBase64 from '@salesforce/apex/FEC_AttachmentController.downloadAndSaveBase64';
import { executeWithLock, fetchFileFromUrl, formatDatetime, showToast, decryptDataKYC } from 'c/fecChathubUtils';
import FEC_CHATHUB_STATUS from '@salesforce/messageChannel/FecChatHubStatus__c';
import { subscribe, APPLICATION_SCOPE } from 'lightning/messageService';

const CHATHUB_URL_KEY = 'https://portal-chathub-uat.fecredit.cloud';
// Log formatting for better console visibility
const LOG_PREFIX = '%c[FEC-ChatHub] ';
const LOG_STYLE = 'color: #fff; background: #0070d2; padding: 2px 5px; border-radius: 4px; font-weight: bold;';
const LOG_INFO = 'color: #0070d2; font-weight: bold;';
const LOG_WARN = 'color: #ff9900; font-weight: bold;';
const LOG_ERROR = 'color: #c23934; font-weight: bold;';
const PREFIX_INTERACTION_CASE_REASSIGN = "CHATHUB_IC_RS_";

export default class FecChathubContainer extends NavigationMixin(LightningElement) {
    // ===== CLASS PROPERTIES & VARIABLES =====

    // --- UI State Properties (Reactive) ---
    @track isChatHubVisible = false;
    @track isInitialized = false;
    @track chatHubUrl = '';
    @track chatHubUsername = '';

    // --- Wire Adapters ---\
    utilityId;
    @wire(EnclosingUtilityId)
    wiredUtilityId(value) {
        if (value) {
            this.utilityId = value;
            this.registerUtilityClickListener();
        }
    }
    @wire(IsConsoleNavigation) isConsoleNavigation;

    // --- Configuration & Constants ---
    #secretKey = '4mX2SmAeoLy9n8c1zsEpH+L37XrwsCGxvc1tAyOdaTpxgcOQuXitLA==';
    localStorageUsername = "chathub_username";

    // --- Drag & Drop Variables ---
    isDragging = false;
    dragElement = null;
    startX = 0;
    startY = 0;
    panelWidth = 0;
    panelHeight = 0;
    initialRight = 0;
    initialBottom = 0;

    // --- Resize Variables ---
    isResizing = false;
    isResizerAttached = false;
    injectedResizers = [];
    resizeDirection = null;
    resizeStartX = 0;
    resizeStartY = 0;
    initialWidth = 0;
    initialHeight = 0;
    resizeElement = null;
    resizeTimeout = null;

    // --- Event Management ---
    isEventAttached = false;
    isObserverAttached = false;
    panelObserver = null;
    restoreTimeout = null;
    boundHandleMouseMove = null;
    boundHandleMouseUp = null;
    boundInitResize = null;
    boundHandleWindowResize = null;
    _handleResizeMove = null;
    _handleResizeUp = null;

    @wire(MessageContext) messageContext;
    // ===== WIRE ADAPTERS =====

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
            console.groupEnd();
        } else if (error) {
            console.error(LOG_PREFIX + 'Apex Init Error:', LOG_STYLE, error);
        }
    }

    // ===== LIFECYCLE HOOKS =====

    /**
     * Constructor - Initializes bound event handlers
     * @return {void}
     */
    constructor() {
        super();
        this.boundHandleMouseMove = this.handleMouseMove.bind(this);
        this.boundHandleMouseUp = this.handleMouseUp.bind(this);
        this.boundInitResize = this.initResize.bind(this);
        this.boundHandleWindowResize = this.handleWindowResize.bind(this);
    }

    /**
     * connectedCallback - Lifecycle hook when component is inserted into DOM
     * @return {void}
     */
    connectedCallback() {
        // Attach mousemove and mouseup to document (entire page)
        document.addEventListener('mousemove', this.boundHandleMouseMove, { capture: true });
        document.addEventListener('mouseup', this.boundHandleMouseUp, { capture: true });
        window.addEventListener('resize', this.boundHandleWindowResize);

        localStorage.removeItem('FEC_ChatHub_Right');
        localStorage.removeItem('FEC_ChatHub_Bottom');
        localStorage.removeItem('FEC_ChatHub_Width');
        localStorage.removeItem('FEC_ChatHub_Height');

        this.subscription = subscribe(
            this.messageContext,
            FEC_CHATHUB_STATUS,
            (message) => {
                if (message.action === 'STATUS_CHANGED_FROM_UTILITY') {
                    // Post event to iframe to update status when changed from Utility Bar
                    this.postMessageToChatHub('pegaUpdateStatus', message.newStatusId);
                }
            },
            { scope: APPLICATION_SCOPE }
        );
    }

    /**
      * renderedCallback - Lifecycle hook after component is rendered
      * @return {void}
      */
    async renderedCallback() {
        if (!this.isEventAttached) {
            const targetElement = this.template.querySelector('[data-id="containerChathub"]');
            const parentElement = targetElement ? targetElement.closest('.oneUtilityBarPanel') : null;

            if (parentElement) {
                // Find Salesforce default header
                const sfHeader = parentElement.querySelector('.slds-utility-panel__header');

                if (sfHeader) {
                    sfHeader.style.cursor = 'grab';

                    sfHeader.addEventListener('mousedown', (e) => {
                        // Ignore if user clicked on the minimize button (icon in top right)
                        if (e.target.closest('button')) return;

                        this.handleMouseDown(e);
                    }, { capture: true });

                    // Override the Close Tab action (prevent click event bubbling to Salesforce)
                    sfHeader.addEventListener('click', (e) => {
                        // Allow Salesforce to handle minimize button
                        if (e.target.closest('button')) return;

                        // Prevent tab collapse action from header
                        e.stopPropagation();
                        e.preventDefault();
                    }, { capture: true });

                    this.isEventAttached = true;
                }

                // --- NEW LOGIC: INJECT 4 RESIZE HANDLES ON OUTER BORDER ---
                if (!this.isResizerAttached) {
                    this.isResizerAttached = true;

                    // Define edges with inline styles
                    const edges = [
                        { dir: 'top', cursor: 'ns-resize', css: 'top: -4px; left: 0; width: 100%; height: 8px;' },
                        { dir: 'bottom', cursor: 'ns-resize', css: 'bottom: -4px; left: 0; width: 100%; height: 8px;' },
                        { dir: 'left', cursor: 'ew-resize', css: 'top: 0; left: -4px; width: 8px; height: 100%;' },
                        { dir: 'right', cursor: 'ew-resize', css: 'top: 0; right: -4px; width: 8px; height: 100%;' },

                        { dir: 'top-left', cursor: 'nwse-resize', css: 'top: -6px; left: -6px; width: 12px; height: 12px;' },
                        { dir: 'top-right', cursor: 'nesw-resize', css: 'top: -6px; right: -6px; width: 12px; height: 12px;' },
                        { dir: 'bottom-left', cursor: 'nesw-resize', css: 'bottom: -6px; left: -6px; width: 12px; height: 12px;' },
                        { dir: 'bottom-right', cursor: 'nwse-resize', css: 'bottom: -6px; right: -6px; width: 12px; height: 12px;' }
                    ];

                    edges.forEach(edge => {
                        const resizer = document.createElement('div');
                        // Apply styles directly as element is outside Shadow DOM
                        resizer.style.cssText = `position: absolute; z-index: 999999; cursor: ${edge.cursor}; ${edge.css}; background: transparent;`;
                        resizer.setAttribute('data-dir', edge.dir);

                        // Listen for mousedown event
                        resizer.addEventListener('mousedown', this.boundInitResize, { capture: true });

                        // Append directly to `.oneUtilityBarPanel`
                        parentElement.appendChild(resizer);

                        // Save for cleanup later
                        this.injectedResizers.push(resizer);
                    });
                }

                // --- NEW LOGIC: MONITOR SALESFORCE STYLE CHANGES ---
                if (!this.isObserverAttached) {
                    this.isObserverAttached = true;
                    this.panelObserver = new MutationObserver((mutations) => {
                        mutations.forEach((mutation) => {
                            if (mutation.attributeName === 'style') {
                                const currentBottom = parentElement.style.bottom;

                                // Conditions:
                                // 1. Has bottom value
                                // 2. Doesn't contain "-" (not when Salesforce hides tab: -800px)
                                // 3. User is not dragging/resizing
                                if (currentBottom && !currentBottom.includes('-') && !this.isDragging && !this.isResizing) {
                                    const savedBottom = localStorage.getItem('FEC_ChatHub_Bottom');

                                    // If Salesforce's bottom differs from saved value, reapply our state
                                    if (savedBottom && parseInt(currentBottom, 10) !== parseInt(savedBottom, 10)) {
                                        clearTimeout(this.restoreTimeout);
                                        // Delay 50ms to let Salesforce finish overwriting inline styles
                                        this.restoreTimeout = setTimeout(() => {
                                            this.applySavedState();
                                        }, 50);
                                    }
                                }
                            }
                        });
                    });

                    // Start monitoring 'style' attribute changes
                    this.panelObserver.observe(parentElement, { attributes: true, attributeFilter: ['style'] });
                }
            }
            this.applySavedState();
        }
    }

    /**
     * disconnectedCallback - Lifecycle hook when component is removed from DOM
     * @return {void}
     */
    disconnectedCallback() {
        window.removeEventListener('message', this.handleMessage.bind(this));
        document.removeEventListener('mousemove', this.boundHandleMouseMove);
        document.removeEventListener('mouseup', this.boundHandleMouseUp);
        window.removeEventListener('resize', this.boundHandleWindowResize);

        // Clean up injected resize handles
        if (this.injectedResizers && this.injectedResizers.length > 0) {
            this.injectedResizers.forEach(resizer => {
                resizer.removeEventListener('mousedown', this.boundInitResize, { capture: true });
                resizer.remove();
            });
            this.injectedResizers = [];
            this.isResizerAttached = false;
        }

        // Clean up Observer
        if (this.panelObserver) {
            this.panelObserver.disconnect();
            this.panelObserver = null;
            this.isObserverAttached = false;
        }
    }

    // ===== MESSAGE HANDLERS & EVENT ROUTING =====

    /**
     * Handles postMessage events from ChatHub iframe
     * Validates origin and routes messages to appropriate handlers
     * @param {MessageEvent} event - Event object containing action and data
     * @return {void}
     */
    handleMessage(event) {
        // Log origin for debugging if messages are not received
        // const trustedUrl = localStorage.getItem(CHATHUB_URL_KEY);
        // console.log('DEBUG Origin:', event.origin, 'Expected:', trustedUrl);

        // Uncomment the line below when running in Production for security
        // if (!trustedUrl || (event.origin !== new URL(trustedUrl).origin)) return;

        console.log('event: ', event);
        const { action, data } = event.data;
        if (action) {
            console.groupCollapsed(LOG_PREFIX + '📩 RECEIVED: ' + action, LOG_STYLE);
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

            case 'getAgentInfomation':
                publish(this.messageContext, FEC_CHATHUB_STATUS, {
                    action: 'INIT_STATUS_FROM_IFRAME',
                    payload: data
                });
                break;
            case 'agentStatusChanged':
                publish(this.messageContext, FEC_CHATHUB_STATUS, {
                    action: 'STATUS_CHANGED_FROM_IFRAME',
                    newStatusId: data
                });
                break;
            default:
                if (action) console.log('%c⚠ Unhandled Action:', LOG_WARN, action);
        }
        if (action) console.groupEnd();
    }

    // ===== DRAG & DROP HANDLERS =====

    /**
     * Handles mouse down on header - initiates dragging
     * @param {MouseEvent} event - Mouse event
     * @return {void}
     */
    handleMouseDown(event) {
        this.isDragging = true;
        this.startX = event.clientX;
        this.startY = event.clientY;

        const targetElement = this.template.querySelector('[data-id="containerChathub"]');
        this.dragElement = targetElement ? targetElement.closest('.oneUtilityBarPanel') : null;

        if (this.dragElement) {
            const style = window.getComputedStyle(this.dragElement);
            this.initialRight = parseInt(style.right, 10) || 0;
            this.initialBottom = parseInt(style.bottom, 10) || 0;

            // SUPPLEMENT: Get panel size to calculate boundary constraints
            const rect = this.dragElement.getBoundingClientRect();
            this.panelWidth = rect.width;
            this.panelHeight = rect.height;
        }

        const iframe = this.template.querySelector('iframe');
        if (iframe) {
            iframe.style.pointerEvents = 'none'; // Lock iframe to prevent mouse errors
        }

        if (event.currentTarget) {
            event.currentTarget.style.cursor = 'grabbing';
        }

        event.preventDefault();
        event.stopImmediatePropagation();
    }

    /**
     * Handles mouse move while dragging
     * Updates panel position with boundary checks
     * @param {MouseEvent} event - Mouse event
     * @return {void}
     */
    handleMouseMove(event) {
        if (!this.isDragging || !this.dragElement) return;

        const dx = event.clientX - this.startX;
        const dy = event.clientY - this.startY;

        // 1. Calculate initial new position
        let newRight = this.initialRight - dx;
        let newBottom = this.initialBottom - dy;

        // 2. Browser viewport dimensions
        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;

        // 3. BOUNDARY LOGIC

        // Bottom boundary:
        // - Cannot go below bottom edge: newBottom >= 0
        // - Cannot go above top edge: newBottom <= (viewport height - panel height)
        const maxBottom = viewportHeight - this.panelHeight;
        newBottom = Math.max(0, Math.min(newBottom, maxBottom));

        // Right boundary:
        // - Cannot go past right edge: newRight >= 0
        // - Cannot go past left edge: newRight <= (viewport width - panel width)
        const maxRight = viewportWidth - this.panelWidth;
        newRight = Math.max(0, Math.min(newRight, maxRight));

        // 4. Apply constrained position
        this.dragElement.style.right = `${newRight}px`;
        this.dragElement.style.bottom = `${newBottom}px`;

        // 5. Prevent unwanted events
        event.preventDefault();
        event.stopImmediatePropagation();
    }

    /**
     * Handles mouse up - ends dragging
     * Saves position to localStorage
     * @param {MouseEvent} event - Mouse event
     * @return {void}
     */
    handleMouseUp(event) {
        if (this.isDragging) {
            const iframe = this.template.querySelector('iframe');
            if (iframe) {
                iframe.style.pointerEvents = 'auto'; // Unlock iframe
            }

            // Return cursor to normal state on header
            const targetElement = this.template.querySelector('[data-id="containerChathub"]');
            const parentElement = targetElement ? targetElement.closest('.oneUtilityBarPanel') : null;
            if (parentElement) {
                const sfHeader = parentElement.querySelector('.slds-utility-panel__header');
                if (sfHeader) sfHeader.style.cursor = 'grab';
            }
            if (this.dragElement) {
                localStorage.setItem('FEC_ChatHub_Right', this.dragElement.style.right);
                localStorage.setItem('FEC_ChatHub_Bottom', this.dragElement.style.bottom);
            }
            this.dragElement = null;
            this.isDragging = false;
            event.preventDefault();
            event.stopImmediatePropagation();
        }
    }

    // ===== RESIZE HANDLERS =====

    /**
     * Initiates resize operation when user clicks on resize handles
     * @param {MouseEvent} event - Mouse event
     * @return {void}
     */
    initResize(event) {
        event.stopPropagation();
        event.preventDefault();

        this.isResizing = true;
        this.resizeDirection = event.target.getAttribute('data-dir'); // Get resize direction (top, bottom, left, right)

        this.resizeStartX = event.clientX;
        this.resizeStartY = event.clientY;

        const targetElement = this.template.querySelector('[data-id="containerChathub"]');
        this.resizeElement = targetElement ? targetElement.closest('.oneUtilityBarPanel') : null;

        if (this.resizeElement) {
            // Get current size and position of Utility Panel
            const style = window.getComputedStyle(this.resizeElement);
            this.initialWidth = parseFloat(style.width) || this.resizeElement.offsetWidth;
            this.initialHeight = parseFloat(style.height) || this.resizeElement.offsetHeight;
            this.initialRight = parseFloat(style.right) || 0;
            this.initialBottom = parseFloat(style.bottom) || 0;

            // 🛑 Disable Salesforce default animation to prevent jitter
            this.resizeElement.style.setProperty('transition', 'none', 'important');

            // Disable iframe mouse events to prevent lag during resize
            const iframe = this.template.querySelector('iframe');
            if (iframe) iframe.style.pointerEvents = 'none';

            // Bind functions for cleanup (if not already bound in constructor)
            this._handleResizeMove = this.handleResizeMove.bind(this);
            this._handleResizeUp = this.handleResizeUp.bind(this);

            document.addEventListener('mousemove', this._handleResizeMove);
            document.addEventListener('mouseup', this._handleResizeUp);
        }
    }

    /**
     * Handles mouse move during resize
     * Updates panel dimensions with boundary checks
     * @param {MouseEvent} event - Mouse event
     * @return {void}
     */
    handleResizeMove(event) {
        if (!this.isResizing || !this.resizeElement) return;

        let dx = event.clientX - this.resizeStartX;
        let dy = event.clientY - this.resizeStartY;

        // Remove Salesforce default maxHeight/maxWidth constraints
        this.resizeElement.style.maxHeight = 'none';
        this.resizeElement.style.maxWidth = 'none';

        const viewportWidth = window.innerWidth;
        const viewportHeight = window.innerHeight;

        // Minimum dimensions
        const MIN_WIDTH = 350;
        const MIN_HEIGHT = 700;

        if (this.resizeDirection.includes('top')) {
            let newHeight = this.initialHeight - dy;
            let maxHeight = viewportHeight - this.initialBottom;
            newHeight = Math.max(MIN_HEIGHT, Math.min(newHeight, maxHeight));
            this.resizeElement.style.height = `${newHeight}px`;
        }
        else if (this.resizeDirection.includes('bottom')) {
            let maxDy = this.initialBottom;
            let minDy = MIN_HEIGHT - this.initialHeight;
            dy = Math.max(minDy, Math.min(dy, maxDy));
            this.resizeElement.style.height = `${this.initialHeight + dy}px`;
            this.resizeElement.style.bottom = `${this.initialBottom - dy}px`;
        }

        // --- HANDLE HORIZONTAL RESIZE (LEFT / RIGHT) ---
        if (this.resizeDirection.includes('left')) {
            let newWidth = this.initialWidth - dx;
            let maxWidth = viewportWidth - this.initialRight;
            newWidth = Math.max(MIN_WIDTH, Math.min(newWidth, maxWidth));
            this.resizeElement.style.width = `${newWidth}px`;
        }
        else if (this.resizeDirection.includes('right')) {
            let maxDx = this.initialRight;
            let minDx = MIN_WIDTH - this.initialWidth;
            dx = Math.max(minDx, Math.min(dx, maxDx));
            this.resizeElement.style.width = `${this.initialWidth + dx}px`;
            this.resizeElement.style.right = `${this.initialRight - dx}px`;
        }
        // Prevent browser text selection during fast mouse drag
        event.preventDefault();
    }

    /**
     * Handles mouse up - ends resizing
     * Saves new dimensions to localStorage
     * @param {MouseEvent} event - Mouse event
     * @return {void}
     */
    handleResizeUp(event) {
        if (this.isResizing) {
            this.isResizing = false;

            const iframe = this.template.querySelector('iframe');
            if (iframe) iframe.style.pointerEvents = 'auto';

            // Save dimensions and position before ending resize
            if (this.resizeElement) {
                // 🟢 Re-enable animation for Salesforce when mouse is released
                this.resizeElement.style.removeProperty('transition');

                localStorage.setItem('FEC_ChatHub_Width', this.resizeElement.style.width);
                localStorage.setItem('FEC_ChatHub_Height', this.resizeElement.style.height);
                localStorage.setItem('FEC_ChatHub_Right', this.resizeElement.style.right);
                localStorage.setItem('FEC_ChatHub_Bottom', this.resizeElement.style.bottom);
            }

            document.removeEventListener('mousemove', this._handleResizeMove);
            document.removeEventListener('mouseup', this._handleResizeUp);
            this.resizeElement = null;

            if (event) {
                event.preventDefault();
                event.stopImmediatePropagation();
            }
        }
    }

    /**
     * Handles window resize event
     * Reapplies saved state with delay to allow Salesforce to complete its layout
     * @return {void}
     */
    handleWindowResize() {
        // Clear old timeout if resize events occur continuously
        if (this.resizeTimeout) {
            clearTimeout(this.resizeTimeout);
        }

        // Delay 100ms to let Salesforce finish overwriting layout
        // Then call applySavedState to reclaim position
        this.resizeTimeout = setTimeout(() => {
            if (this.isChatHubVisible) {
                this.applySavedState();
            }
        }, 100);
    }

    // ===== MAIN BUSINESS LOGIC FUNCTIONS =====

    /**
     * Handles case creation request from ChatHub
     * Creates a new Case record and sends back the Case ID to ChatHub
     * @param {Object} data - Request data containing chat session and customer info
     * @return {void}
     */
    async handleCreateCaseRequest(data) {
        if (data.customerInfo.nationalID !== '') {
            const dataNationID = await decryptDataKYC(data.customerInfo.nationalID, this.#secretKey)
            data.customerInfo.nationalID = dataNationID;
        }
        if (data.customerInfo.phoneNumber !== '') {
            const dataPhoneNumber = await decryptDataKYC(data.customerInfo.phoneNumber, this.#secretKey)
            data.customerInfo.phoneNumber = dataPhoneNumber;
        }
        const oldAgentID = data.chatSession.oldAgentID;
        if (this.chatHubUsername && this.chatHubUsername === oldAgentID) {
            await this.updateOldCase(data.chatSession.sessionID, data.chatSession.agentID);
        }
        const payload = JSON.stringify(data);
        if (!this.verifyUsernameAndAgent(data)) {
            return;
        }
        this.notifyIfPanelClosed();
        this.attemptCreateCase(payload, data, 5);
    }

    /**
     * Call Apex to create Case with Retry mechanism to handle Race Condition
     * @param {string} payload - JSON data to send to Apex
     * @param {Object} data - Original data to extract chatSession info
     * @param {number} retriesLeft - Number of remaining retry attempts
     */
    attemptCreateCase(payload, data, retriesLeft) {
        // If chat is re-assigned, first attempt should wait longer (1000ms) to allow Tab A enough time to commit DB.
        // Subsequent retry attempts only need to wait 500ms.
        const isReassigned = data.chatSession.oldAgentID && data.chatSession.oldAgentID !== this.chatHubUsername;
        const delayTime = (isReassigned && retriesLeft === 5) ? 1000 : 500;

        setTimeout(() => {
            createCaseOnNewSession({ strJsonData: payload })
                .then(res => {
                    if (res) {
                        const { caseNo, caseId } = res;
                        // Send back the Case ID (PegaID) to ChatHub
                        const response = {
                            sessionID: data.chatSession.sessionID,
                            pegaID: caseNo,
                            chatChannel: data.chatSession.chatChannel
                        };
                        this.postMessageToChatHub('pegaCsmCaseInfo', response);
                        showToast(this, 'Thành công', `Đã tạo Case tương tác: ${caseNo || ''}`, 'success');
                        this.navigateToRecord(caseId);
                        if (data.chatSession.oldAgentID && data.chatSession.oldAgentID !== this.chatHubUsername) {
                            const historyRequest = {
                                chatID: data.chatSession.chatID,
                                sessionID: data.chatSession.sessionID,
                                selectedFilter: "all",
                                selectedChannel: "newest",
                                page: 1,
                                size: 1000
                            };
                            this.postMessageToChatHub('pegaGetSessionHistory', historyRequest);
                        }
                    }
                })
                .catch(error => {
                    console.log('%c⚠ Error creating Case:', LOG_WARN, error);
                    const errorMsg = error?.body?.message || error?.message || JSON.stringify(error);
                    if (errorMsg.includes('DUPLICATE_VALUE') && retriesLeft > 0) {
                        console.log(`[FEC-ChatHub] Encountered Duplicate key. Waiting for Tab A to complete update... Retrying. ${retriesLeft - 1} attempts remaining.`);
                        this.attemptCreateCase(payload, data, retriesLeft - 1);
                    } else {
                        showToast(this, 'Lỗi', 'Không thể tạo Case tương tác sau nhiều lần thử, vui lòng kiểm tra lại.', 'error');
                    }
                });
        }, delayTime);
    }

    async updateOldCase(extInteractionID, newUsername) {
        try {
            const isUpdated = await updateOldCaseInteractionId({
                strExtInteractionID: extInteractionID,
                newUsername: newUsername
            });

            if (isUpdated) {
                console.log('✅ Update successful with only 1 server trip!');
            } else {
                console.log('⚠ Old Case not found to update.');
            }
        } catch (error) {
            console.error('❌ Error executing updateOldCaseInteractionId:', error);
        }
    }

    /**
     * Handles end chat action from ChatHub
     * Requests full session history before closing chat
     * @param {Object} data - Chat session data
     * @return {void}
     */
    async handleEndChat(data) {
        if (!this.verifyUsernameAndAgent(data)) {
            return;
        }
        localStorage.setItem('endChatActive', true);
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
     * Handles session history request
     * Saves chat history and attachments to Salesforce with duplicate prevention
     * @param {Array} data - Array of chat history records
     * @return {void}
     */
    handleSessionHistory(data) {
        const isEndChat = !!localStorage.getItem('endChatActive');
        if (!data || data.length === 0) {
            console.warn('%c⚠ History Data is Empty', LOG_WARN);
            return;
        }

        const sessionId = data[0].sessionID;
        const lockName = 'LOCK_HISTORY_' + sessionId;

        const processHistoryAction = async () => {
            let dataToProcess = data;
            let isAttachmentOnly = false;
            if (!isEndChat) {
                dataToProcess = data.filter(msg => msg.messageType === 'attachment' || msg.messageType === 'image');
                console.log('Data to process:', dataToProcess);
                if (dataToProcess.length === 0) {
                    return;
                }
                isAttachmentOnly = true;
            }
            const payload = JSON.stringify(dataToProcess);

            try {
                const success = await saveChatHistoryAndAttachment({
                    strJsonData: payload,
                    isAttachmentOnly: isAttachmentOnly
                });
                if (success) {
                    const toastMessage = isAttachmentOnly
                        ? 'File saved successfully.'
                        : 'Chat history saved successfully.';
                    showToast(this, 'Success', toastMessage, 'success');

                    try {
                        const caseId = await checkExistCaseByExtInteractionID({ strExtInteractionID: sessionId });

                        if (caseId && this.isConsoleNavigation) {
                            publish(this.messageContext, FEC_CHAT_UPDATE, { recordId: caseId });
                            const allTabs = await getAllTabInfo();
                            let targetTabId = null;

                            // Loop through all tabs and subtabs to find the Case ID
                            for (const tab of allTabs) {
                                // 1. Check if Case is a Primary Tab
                                if (tab.recordId === caseId) {
                                    targetTabId = tab.tabId;
                                    break;
                                }

                                // 2. Check if Case is a Subtab within this Primary Tab
                                if (tab.subtabs && tab.subtabs.length > 0) {
                                    for (const subtab of tab.subtabs) {
                                        if (subtab.recordId === caseId) {
                                            targetTabId = subtab.tabId; // Get the ID of the subtab
                                            break;
                                        }
                                    }
                                }
                                if (targetTabId) break; // Exit outer loop if found
                            }

                            if (targetTabId) {
                                setTimeout(async () => {
                                    try {
                                        await notifyRecordUpdateAvailable([{ recordId: caseId }]);
                                        await refreshTab(targetTabId, { includeAllSubtabs: true });
                                    } catch (err) {
                                        console.warn('[FEC-ChatHub] Error while refreshing tab:', err);
                                    }
                                }, 50);
                            } else {
                                console.log(`[FEC-ChatHub] Could not find any open tab containing Case ID: ${caseId}`);
                            }
                        }
                    } catch (refreshErr) {
                        console.warn('[FEC-ChatHub] Error calling Workspace API:', refreshErr);
                    }
                }
                if (isEndChat) {
                    localStorage.removeItem('endChatActive');
                }
            } catch (error) {
                if (isEndChat) {
                    localStorage.removeItem('endChatActive');
                }
                console.error('[FEC-ChatHub] Error calling saveChatHistoryAndAttachment:', error);
            }
        };

        executeWithLock(lockName, processHistoryAction, true);
    }

    /**
     * Handles new attachment/image message from chat
     * Processes files with lock mechanism to prevent duplicates
     * @param {Object} data - Message data containing file information
     * @return {Promise<void>}
     */
    async saveAttachmentNewMessage(data) {
        if (!this.verifyUsernameAndAgent(data)) return;
        this.notifyIfPanelClosed();
        if (data && (data.messageType === 'attachment' || data.messageType === 'image')) {

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

                await downloadAndSaveBase64({
                    s3Url: data.fileUrl,
                    interactionCaseId: caseId,
                    fileName: data.fileName,
                    uniqueMessageId: uniqueMessageId
                });

                showToast(this, 'Thành công', 'File đã được tải và lưu vào Case.', 'success');
            } catch (error) {
                showToast(this, 'Lỗi', 'Không thể tải và lưu file.', 'error');
                console.error('Apex: error', error);
            }
        }
    }

    // ===== HELPER & UTILITY FUNCTIONS =====

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
        } catch (e) {
            return strUrl;
        }
    }

    /**
     * Applies saved panel size and position from localStorage
     * Used to restore state after window resize or page refresh
     * @return {void}
     */
    applySavedState() {
        const targetElement = this.template.querySelector('[data-id="containerChathub"]');
        const parentElement = targetElement ? targetElement.closest('.oneUtilityBarPanel') : null;

        if (parentElement) {
            let savedRight = localStorage.getItem('FEC_ChatHub_Right');
            let savedBottom = localStorage.getItem('FEC_ChatHub_Bottom');
            const savedWidth = localStorage.getItem('FEC_ChatHub_Width');
            const savedHeight = localStorage.getItem('FEC_ChatHub_Height');

            // 1. Restore dimensions first
            if (savedWidth) parentElement.style.width = savedWidth;
            if (savedHeight) parentElement.style.height = savedHeight;

            // Remove Salesforce constraints to apply custom size/position
            parentElement.style.maxHeight = 'none';
            parentElement.style.maxWidth = 'none';

            // 2. Restore position with safety logic to prevent off-screen placement
            if (savedRight !== null && savedBottom !== null) {
                savedRight = parseInt(savedRight, 10);
                savedBottom = parseInt(savedBottom, 10);

                const rect = parentElement.getBoundingClientRect();
                const viewportWidth = window.innerWidth;
                const viewportHeight = window.innerHeight;

                const maxRight = Math.max(0, viewportWidth - rect.width);
                const maxBottom = Math.max(0, viewportHeight - rect.height);

                // Constrain coordinates to safe boundaries
                savedRight = Math.max(0, Math.min(savedRight, maxRight));
                savedBottom = Math.max(0, Math.min(savedBottom, maxBottom));

                parentElement.style.right = `${savedRight}px`;
                parentElement.style.bottom = `${savedBottom}px`;
            }
        }
    }

    /**
     * Sends postMessage to ChatHub iframe
     * Communication channel to send actions and data to embedded ChatHub component
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

    /**
     * Navigates to a record detail page
     * Minimizes the ChatHub utility panel before navigation
     * @param {string} recordId - ID of the record to open
     * @return {void}
     */
    navigateToRecord(recordId) {
        if (this.utilityId) {
            minimize(this.utilityId)
                .catch(err => {
                    console.error('[FEC-ChatHub] Error calling minimize:', err);
                });
        }
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
     * Updates username in local storage
     * Stores current agent username for verification purposes
     * @param {string} username - Username to store
     * @return {void}
     */
    updateUsername(username) {
        localStorage.setItem(this.localStorageUsername, username);
    }

    /**
     * Verifies that username and agent information match current user
     * Prevents unauthorized message processing from other agents
     * @param {Object} data - Object containing chatSession, agentName, or senderName
     * @return {boolean} - True if verification passes, false otherwise
     */
    verifyUsernameAndAgent(data) {
        if (!data.chatSession && !data.agentName && !data.senderName) {
            return false;
        }
        // Extract agent ID from available fields and add domain if needed
        let agentID = data.chatSession ? data.chatSession.agentID : data.agentName ? data.agentName : data.senderName;
        if (this.chatHubUsername && this.chatHubUsername != agentID) {
            console.error('%cERRY EXIT: Username mismatch', LOG_WARN, `Expected: ${this.chatHubUsername}, Got: ${agentID}`);
            return false;
        }
        return true;
    }

    /**
     * Checks if session ID has been marked for reassignment
     * Uses localStorage to track reassignment status
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

    async notifyIfPanelClosed() {
        if (!this.utilityId) return;

        try {
            const utilityInfo = await getInfo(this.utilityId);
            if (utilityInfo && !utilityInfo.utilityVisible) {
                this.utilityAttrs = {
                    label: 'ChatHub (new message)',
                    icon: 'alert',
                    highlighted: true
                }
                await updateUtility(this.utilityId, this.utilityAttrs);
            }
        } catch (err) {
            console.warn('[FEC-ChatHub] Error while setting Utility Highlight:', err);
        }
    }

    async clearUtilityHighlight() {
        if (!this.utilityId) return;

        try {
            this.utilityAttrs = {
                label: 'ChatHub',
                icon: 'chat',
                highlighted: true
            }
            await updateUtility(this.utilityId, this.utilityAttrs);
            await updateUtility(this.utilityId, { highlighted: false });
        } catch (err) {
            console.warn('[FEC-ChatHub] Error disabling highlight:', err);
        }
    }

    registerUtilityClickListener() {
        if (!this.utilityId) return;

        onUtilityClick(this.utilityId, (eventInfo) => {
            if (eventInfo.panelVisible) {
                this.clearUtilityHighlight();
            }
        }).catch(err => console.error('[FEC-ChatHub] Error registering utility click:', err));
    }
}