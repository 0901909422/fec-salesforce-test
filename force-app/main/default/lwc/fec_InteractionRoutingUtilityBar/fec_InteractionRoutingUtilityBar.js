import { LightningElement, track, wire } from 'lwc';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { IsConsoleNavigation, openTab, getFocusedTabInfo, openSubtab, focusTab } from 'lightning/platformWorkspaceApi';
import { minimizeUtility } from 'lightning/platformUtilityBarApi';
import executeRoutingAssignments from "@salesforce/apex/FEC_InteractionRoutingController.executeRoutingAssignments";
import USER_ID from '@salesforce/user/Id';


const COLUMNS = [
    { label: 'Case Number', fieldName: 'caseUrl', type: 'url', typeAttributes: { label: { fieldName: 'CaseNumber' }, target: '_blank' } },
    { label: 'Channel', fieldName: 'FEC_Channel__c', type: 'text' },
    { label: 'Send To', fieldName: 'FEC_Send_To__c', type: 'text' },
    { label: 'Owner Id', fieldName: 'OwnerId', type: 'text' },
    { label: 'Reply', fieldName: 'FEC_Is_Reply_Interaction_email__c', type: 'boolean' },
    {
        type: 'button',
        fixedWidth: 120,
        typeAttributes: {
            label: 'Open',
            name: 'open_case',
            title: 'Open Case',
            variant: 'brand'
        }
    }
];

export default class FecInteractionRoutingUtilityBar extends LightningElement {
    channelName = '/event/FEC_Interaction_Routed__e';
    subscription = null;

    @track cases = [];
    columns = COLUMNS;

    // Turn on/off auto open
    autoOpenLatest = true;

    // Store IDs to avoid duplicates
    caseIdSet = new Set();

    @wire(IsConsoleNavigation)
    isConsoleNavigation;

    connectedCallback() {
        console.log('Utility Bar LWC connected');
        this.registerErrorListener();
        this.handleSubscribe();
    }

    disconnectedCallback() {
        this.handleUnsubscribe();
    }

    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    registerErrorListener() {
        onError((error) => {
            console.error('EMP API error Routing:', JSON.stringify(error));
        });
        //this.showToast('Streaming Error', 'Failed to receive platform events.', 'error');
    }

    async handleSubscribe() {
        if (this.subscription) {
            console.log('Already subscribed');
            return;
        }

        this.subscription = await subscribe(this.channelName, -1, (event) => {
            console.log('Raw platform event received:', JSON.stringify(event));
            this.handlePlatformEvent(event);
        });

        console.log('Subscribed successfully to:', this.channelName);
    }

    async handleUnsubscribe() {
        if (this.subscription) {
            await unsubscribe(this.subscription);
            this.subscription = null;
        }
    }

    async handlePlatformEvent(event) {
        try {
            console.log('handlePlatformEvent fired');
            const payload = event?.data?.payload;
            console.log('Payload:', JSON.stringify(payload));

            if (!payload) {
                console.warn('Payload is empty');
                return;
            }
            if (payload.OwnerId__c !== USER_ID) {
                return;
            }

            const caseRow = {
                Id: payload.CaseId__c,
                CaseNumber: payload.CaseNumber__c,
                OwnerId: payload.OwnerId__c,
                ParentId: payload.ParentId__c,
                FEC_Channel__c: payload.Channel__c,
                FEC_Send_To__c: payload.SendTo__c,
                FEC_Is_Reply_Interaction_email__c: payload.IsReply__c,
                caseUrl: `/lightning/r/Case/${payload.CaseId__c}/view`
            };

            if (!this.caseIdSet.has(caseRow.Id)) {
                this.caseIdSet.add(caseRow.Id);
                this.cases = [caseRow, ...this.cases];
            }

            this.showToast(
                'New Routed Interaction',
                `Case ${caseRow.CaseNumber} was routed successfully.`,
                'success'
            );

            if (this.autoOpenLatest) {
                await this.openCase(caseRow.Id);
                await this.safeMinimizeUtility();
            }
        } catch (e) {
            console.error('Error handling platform event:', e);
        }
    }

    async handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'open_case' && row?.Id) {
            await this.openCase(row.Id);
        }
    }

    async openCase(caseId) {
        console.log('open 000');
        try {
          

            // Try to open as subtab under current focused tab if possible
            let focusedTab;
            try {
                focusedTab = await getFocusedTabInfo();
            } catch (e) {
                focusedTab = null;
            }
            if (focusedTab?.tabId) {
                console.log('open 333 ' + focusedTab?.tabId );
                const subtabId = await openSubtab(focusedTab.tabId, {
                    pageReference: {
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: caseId,
                            objectApiName: 'Case',
                            actionName: 'view'
                        }
                    },
                    focus: true
                });

                if (subtabId) {
                    await focusTab(subtabId);
                    return;
                }
            }

            // Fallback: open as top-level workspace tab
            
            const tabId = await openTab({
                pageReference: {
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: caseId,
                        objectApiName: 'Case',
                        actionName: 'view'
                    }
                },
                focus: true
            });
            if (tabId) {
                await focusTab(tabId);
            }

        } catch (e) {
            console.error('Error opening Case tab:', e);
            window.open(`/lightning/r/Case/${caseId}/view`, '_blank');
        }
    }

    async safeMinimizeUtility() {
        try {
            await minimizeUtility();
        } catch (e) {
            // Safe to ignore if minimize isn't available in the current context
            console.warn('Could not minimize utility:', e);
        }
    }
    callExecuteRouting() {
        executeRoutingAssignments()
            .then(() => {
            console.log('executeRoutingAssignments success');
            })
            .catch(error => {
            console.error('executeRoutingAssignments error', error);
            });
    }
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}