import { LightningElement, wire, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { IsConsoleNavigation, getFocusedTabInfo, closeTab } from 'lightning/platformWorkspaceApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
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

    @wire(IsConsoleNavigation) isConsoleNavigation;

    // ----------------------
    // Utility functions
    // ----------------------
    async closeTab() {
        if (!this.isConsoleNavigation) return;
        const { tabId } = await getFocusedTabInfo();
        await closeTab(tabId);
    }

    async handleCloseModal() {
        this.isShowModal = false;
        await this.handleClose();
    }

    async handleSkipWithoutRecord() {
        this.isShowModal = false;
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

        await this.closeTab();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}