import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { IsConsoleNavigation, getFocusedTabInfo, closeTab, openTab } from 'lightning/platformWorkspaceApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {
  publish,
  MessageContext,
} from "lightning/messageService";

import IS_MODE_EDIT from "@salesforce/messageChannel/FEC_Case_Mode__c";
import CREATE_CASE_INTERNAL from '@salesforce/label/c.FEC_Create_Case_Btn_Label';
import FEC_No_Permission_Msg from '@salesforce/label/c.FEC_No_Permission_Msg';
import getCurrentUserProfileName from '@salesforce/apex/FEC_SearchController.getCurrentUserProfileName';
import { PROFILE_RELEVANT_DEPTS } from 'c/fec_CommonConst';

export default class Fec_CreateCaseInListView extends NavigationMixin(LightningElement) {
    @api recordId;

    isShowModal = true;
    isCreating = false;
    showSkip = true;
    fullName = '';
    nationalId = '';
    labels = { CREATE_CASE_INTERNAL };
    newCaseId;
    currentTabId;
    _userProfile;

    @wire(IsConsoleNavigation) isConsoleNavigation;
    @wire(MessageContext) messageContext;
    @wire(getCurrentUserProfileName)
    wiredProfile({ data }) {
        if (data) {
            this._userProfile = data;
        }
    }

    async connectedCallback() {
        try {
            const { tabId } = await getFocusedTabInfo();
            this.currentTabId = tabId;
        } catch (e) {}
        // Check profile on every mount
    try {
            const profile = await getCurrentUserProfileName();
            this._userProfile = profile;
            if (profile === PROFILE_RELEVANT_DEPTS) {
                this.isShowModal = false;
                this.dispatchEvent(new ShowToastEvent({ title: 'Lỗi', message: FEC_No_Permission_Msg, variant: 'error' }));
                // Get current tab BEFORE navigating
                let tabToClose = this.currentTabId;
                if (!tabToClose) {
                    try { const { tabId } = await getFocusedTabInfo(); tabToClose = tabId; } catch(e) {}
                }
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: { objectApiName: 'Case', actionName: 'list' }
                });
                setTimeout(async () => {
                    try { if (tabToClose) await closeTab(tabToClose); } catch(e) {}
                }, 3000);
            }
        } catch(e) {}
    }

    // ----------------------
    // Utility functions
    // ----------------------
    async handleCloseTab() {
        if (!this.isConsoleNavigation) return;
        const { tabId } = await getFocusedTabInfo();
        await closeTab(tabId);
    }

    async handleCloseModal(event) {
        this.isShowModal = false;
        this.newCaseId = event.detail.recordId;
        await this.handleClose();
    }

    async handleSkipWithoutRecord(event) {
        this.isShowModal = false;
        this.newCaseId = event.detail.recordId;
        await this.handleClose();
    }

    async handleCreateSuccess(event) {
        this.isShowModal = false;
        await this.handleCloseButtonCancel();
    }

    async handleClose() {
        this.isShowModal = false;

        let tabToClose = this.currentTabId;
        if (!tabToClose) {
            try {
                const { tabId } = await getFocusedTabInfo();
                tabToClose = tabId;
            } catch (e) { }
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            }
        });

        await new Promise(resolve => setTimeout(resolve, 2000));

        await openTab({
            recordId: this.newCaseId,
            focus: true,
        });

        setTimeout(async () => {
            await this.handlePublishMessageChanel();
            if (tabToClose) {
                await closeTab(tabToClose);
            }
        }, 1000);
    }

    async handleCloseButtonCancel() {
        this.isShowModal = false;

        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            }
        });

        await this.handleCloseTab();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async handlePublishMessageChanel() {
        const payload = {
            isModeEdit: true,
        };
        publish(this.messageContext, IS_MODE_EDIT, payload);
    }
}