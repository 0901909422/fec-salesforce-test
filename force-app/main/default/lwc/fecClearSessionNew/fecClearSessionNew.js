import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchUsers from '@salesforce/apex/FEC_ClearSessionController.searchUsers';
import clearSessions from '@salesforce/apex/FEC_ClearSessionController.clearSessions';

export default class FecClearSessionNew extends NavigationMixin(LightningElement) {
    @api recordId;
    isSending = false;
    searchKeyword = '';
    searchResults = [];
    selectedUsers = [];
    showDropdown = false;
    noResults = false;

    @wire(CurrentPageReference)
    pageRef;

    connectedCallback() {
        document.title = 'New Clear Session';
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
            this.dispatchEvent(new ShowToastEvent({ title: 'Validation', message: 'Please select at least one user.', variant: 'warning' }));
            return;
        }
        this.isSending = true;
        const userIds = this.selectedUsers.map(u => u.id);
        clearSessions({ userIds })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: 'Success', message: 'Clear session completed.', variant: 'success' }));
                this.selectedUsers = [];
                this.isSending = false;
                // Navigate to list view
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: {
                        objectApiName: 'FEC_Clear_Session__c',
                        actionName: 'list'
                    },
                    state: {
                        filterName: 'All_Clear_Sessions'
                    }
                });
            })
            .catch(e => {
                const msg = e?.body?.message || 'Clear session failed.';
                this.dispatchEvent(new ShowToastEvent({ title: 'Error', message: msg, variant: 'error' }));
                this.isSending = false;
            });
    }
}
