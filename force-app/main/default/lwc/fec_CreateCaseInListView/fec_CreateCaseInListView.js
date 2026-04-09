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

export default class Fec_CreateCaseInListView extends NavigationMixin(LightningElement) {
    @api recordId;

    // Modal & state
    isShowModal = true;
    isCreating = false;
    showSkip = true;

    // Selected data
    fullName = '';
    nationalId = '';
    labels = {
        CREATE_CASE_INTERNAL
    }
    newCaseId;
    currentTabId;

    @wire(IsConsoleNavigation) isConsoleNavigation;

    @wire(MessageContext)
    messageContext;

    async connectedCallback() {
        try {
            const { tabId } = await getFocusedTabInfo();
            this.currentTabId = tabId;
        } catch (e) {}
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
        this.newCaseId = event.detail.recordId;
        await this.handleClose();
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