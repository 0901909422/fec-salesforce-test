/****************************************************************************************
 * File Name    : Fec_GetNextWork.js
 * Author       : Quangdv7
 * Date         : 2025-12-07
 * Description  : Call data object Case
 * Modification Log
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2025-12-07     Quangdv7             Create
 
****************************************************************************************/

import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAllUserQueues from '@salesforce/apex/FEC_GetNextWorkController.getAllUserQueues';
import getOldestCase from '@salesforce/apex/FEC_GetNextWorkController.getOldestCase';
import takeOwnership from '@salesforce/apex/FEC_GetNextWorkController.takeOwnership';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import TITLE_MODEL_QUEUE from '@salesforce/label/c.Title_button_Get_Next_Work';
import TITLE_SELECT_QUEUE from '@salesforce/label/c.title_Select_Queue';
import TITLE_QUEUE from '@salesforce/label/c.title_Queue';
import TITLE_INFORMATION_QUEUE from '@salesforce/label/c.title_Information_Queue';
import MESSAGE_WARNING from '@salesforce/label/c.messenger_Warning';
import TITLE_TOAST_EVENT from '@salesforce/label/c.title_Toast_Event';
import MESSAGE_TOAST_EVENT from '@salesforce/label/c.messager_Toast_Event';

import { IsConsoleNavigation, getFocusedTabInfo, closeTab, openTab } from 'lightning/platformWorkspaceApi';

export default class Fec_GetNextWork extends NavigationMixin(LightningElement) {
    @track selectedQueue = '';
    isShowModal = true;

    queueOptions = [];
    isLoadingQueues = false;
    queuesError;

    labels = {
        TITLE_MODEL_QUEUE,
        TITLE_SELECT_QUEUE,
        TITLE_QUEUE,
        TITLE_INFORMATION_QUEUE,
        MESSAGE_WARNING,
        TITLE_TOAST_EVENT,
        MESSAGE_TOAST_EVENT
    };

    newCaseId;
    currentTabId; 

    @wire(IsConsoleNavigation) isConsoleNavigation;

    async connectedCallback() {                    
        try {
            const { tabId } = await getFocusedTabInfo();
            this.currentTabId = tabId;
        } catch (e) {}
    }

    /**
    * @description get data Queue
    * @Date 2025/12/07
    * @param getAllUserQueues
    * @return data
    */
    @wire(getAllUserQueues)
    wiredQueues({ data, error }) {
        if (data) {
            this.queueOptions = data;
            this.queuesError = undefined;
        } else if (error) {
            this.queuesError = error;
            this.queueOptions = [];
        }
    }

    /**
    * @description handleQueueChange
    * @Date 2025/12/07
    * @param event
    * @return null
    */
    handleQueueChange(event) {
        this.selectedQueue = event.detail.value;
    }

    /**
    * @description handleCloseTab
    * @Date 2025/12/07
    * @param event
    * @return null
    */
    async handleCloseTab() {
        if (!this.isConsoleNavigation) return;
        const { tabId } = await getFocusedTabInfo();
        await closeTab(tabId);
    }

    /**
    * @description closeTab
    * @Date 2025/12/07
    * @param tabId
    * @return null
    */
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

    /**
    * @description handleCancel
    * @Date 2025/12/07
    * @param 
    * @return null
    */
    async handleCancel() {
        this.isShowModal = false;
        await this.handleCloseButtonCancel();    
    }

    /**
    * @description handleClose
    * @Date 2025/12/07
    * @param 
    * @return null
    */
    async handleClose() {
        this.isShowModal = false;

        let tabToClose = this.currentTabId;
        if (!tabToClose) {
            try {
                const { tabId } = await getFocusedTabInfo();
                tabToClose = tabId;
            } catch (e) {}
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
            if (tabToClose) {
                await closeTab(tabToClose);
            }
        }, 1000);
    }

    /**
    * @description handleGet
    * @Date 2025/12/07
    * @param queueId
    * @return null
    */
    async handleGet() {
        if (!this.selectedQueue) {
            this.toastWarning(this, this.labels.MESSAGE_WARNING);
            return;
        }

        try {
            const caseId = await getOldestCase({ queueId: this.selectedQueue });
            if (!caseId) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: this.labels.TITLE_TOAST_EVENT,
                        message: this.labels.MESSAGE_TOAST_EVENT,
                        variant: 'info'
                    })
                );
                return;
            }

            await takeOwnership({ caseId });

            this.newCaseId = caseId;              
            await this.handleClose(); 

        } catch (error) {
            this.toastError(this, error);
        }
    }


    showToast(component, { title, message, variant = 'info', mode = 'dismissible' }) {
        component.dispatchEvent(new ShowToastEvent({ title, message, variant, mode }));
    }

    toastSuccess(component, message, title = 'Success') {
        this.showToast(component, { title, message, variant: 'success' });
    }

    toastWarning(component, message, title = 'Warning') {
        this.showToast(component, { title, message, variant: 'warning' });
    }

    toastError(component, error, title = 'Error') {
        const message = (error?.body?.message) || error?.message || (typeof error === 'string' ? error : 'Unexpected error');
        this.showToast(component, { title, message, variant: 'error' });
    }

}