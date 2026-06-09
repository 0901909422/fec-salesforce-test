import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchUsers from '@salesforce/apex/FEC_ClearSessionController.searchUsers';
import clearSessions from '@salesforce/apex/FEC_ClearSessionController.clearSessions';

import FEC_Clear_Session_Title from '@salesforce/label/c.FEC_Clear_Session_Title';
import FEC_Clear_Session_Header from '@salesforce/label/c.FEC_Clear_Session_Header';
import FEC_Clear_Session_Subtitle from '@salesforce/label/c.FEC_Clear_Session_Subtitle';
import FEC_Clear_Session_Search_Placeholder from '@salesforce/label/c.FEC_Clear_Session_Search_Placeholder';
import FEC_Clear_Session_No_Users from '@salesforce/label/c.FEC_Clear_Session_No_Users';
import FEC_Clear_Session_Btn from '@salesforce/label/c.FEC_Clear_Session_Btn';
import FEC_Clear_Session_Processing from '@salesforce/label/c.FEC_Clear_Session_Processing';
import FEC_Clear_Session_Validation_Title from '@salesforce/label/c.FEC_Clear_Session_Validation_Title';
import FEC_Clear_Session_Validation_Msg from '@salesforce/label/c.FEC_Clear_Session_Validation_Msg';
import FEC_Clear_Session_Success_Title from '@salesforce/label/c.FEC_Clear_Session_Success_Title';
import FEC_Clear_Session_Success_Msg from '@salesforce/label/c.FEC_Clear_Session_Success_Msg';
import FEC_Clear_Session_Error_Title from '@salesforce/label/c.FEC_Clear_Session_Error_Title';
import FEC_Clear_Session_Error_Msg from '@salesforce/label/c.FEC_Clear_Session_Error_Msg';

export default class FecClearSessionNew extends NavigationMixin(LightningElement) {
    @api recordId;
    isSending = false;
    searchKeyword = '';
    searchResults = [];
    selectedUsers = [];
    showDropdown = false;
    noResults = false;

    labels = {
        header: FEC_Clear_Session_Header,
        subtitle: FEC_Clear_Session_Subtitle,
        searchPlaceholder: FEC_Clear_Session_Search_Placeholder,
        noUsers: FEC_Clear_Session_No_Users,
        btnLabel: FEC_Clear_Session_Btn,
        processing: FEC_Clear_Session_Processing
    };

    @wire(CurrentPageReference)
    pageRef;

    connectedCallback() {
        document.title = FEC_Clear_Session_Title;
    }

    get hasSelectedUsers() { return this.selectedUsers.length > 0; }

    handleSearchChange(event) {
        this.searchKeyword = event.target.value;
    }

    handleSearchKeyup() {
        const kw = this.searchKeyword.trim();
        if (kw.length < 2) { this.showDropdown = false; return; }
        searchUsers({ keyword: kw })
            .then(results => {
                this.searchResults = results;
                this.noResults = results.length === 0;
                this.showDropdown = true;
            })
            .catch(() => { this.showDropdown = false; });
    }

    handleSelectUser(event) {
        const id = event.currentTarget.dataset.id;
        const name = event.currentTarget.dataset.name;
        const email = event.currentTarget.dataset.email;
        if (!this.selectedUsers.find(u => u.id === id)) {
            this.selectedUsers = [...this.selectedUsers, { id, name, email }];
        }
        this.searchKeyword = '';
        this.showDropdown = false;
    }

    handleRemoveUser(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedUsers = this.selectedUsers.filter(u => u.id !== id);
    }

    handleClearSession() {
        if (this.selectedUsers.length === 0) {
            this.dispatchEvent(new ShowToastEvent({
                title: FEC_Clear_Session_Validation_Title,
                message: FEC_Clear_Session_Validation_Msg,
                variant: 'warning'
            }));
            return;
        }
        this.isSending = true;
        const userIds = this.selectedUsers.map(u => u.id);
        clearSessions({ userIds })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Clear_Session_Success_Title,
                    message: FEC_Clear_Session_Success_Msg,
                    variant: 'success'
                }));
                this.selectedUsers = [];
                this.isSending = false;
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: { objectApiName: 'FEC_Clear_Session__c', actionName: 'list' },
                    state: { filterName: 'All_Clear_Sessions' }
                });
            })
            .catch(e => {
                const msg = e?.body?.message || FEC_Clear_Session_Error_Msg;
                this.dispatchEvent(new ShowToastEvent({
                    title: FEC_Clear_Session_Error_Title,
                    message: msg,
                    variant: 'error'
                }));
                this.isSending = false;
            });
    }
}
