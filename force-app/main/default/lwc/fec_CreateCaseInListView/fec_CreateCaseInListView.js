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
        if (!this.isConsoleNavigation) return;
        const { tabId } = await getFocusedTabInfo();
        this.currentTabId = tabId;
    }

    // ----------------------
    // Utility functions
    // ----------------------
    // async handleCloseTab() {
    //     if (!this.isConsoleNavigation) return;
    //     const { tabId } = await getFocusedTabInfo();
    //     await closeTab(tabId);
    // }

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

    async handleCreateSuccess(){
        this.isShowModal = false;
        await this.handleClose();
    }
    
    async handleClose() {
        this.isShowModal = false;

        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Case',
                actionName: 'list'
            }
        });
        
        // await this.handleCloseTab();

        await openTab({
            recordId: this.newCaseId,
            focus: true,
        });
        setTimeout(async () => {
            await this.handlePublishMessageChanel();
            if (this.currentTabId) {
                closeTab(this.currentTabId);
            }
        }, 3000);
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