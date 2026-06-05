import LightningModal from 'lightning/modal';
import { api, track } from 'lwc';
import searchInternalUsers from '@salesforce/apex/FEC_Notification.searchInternalUsers';

import { 
    SEARCH_BY_EMAIL, 
    
} from 'c/fec_CommonConst';

export default class Fec_UserSearchModal extends LightningModal {
    @api initialSearchTerm;
    @track searchResults = [];
    searchTerm = '';
    selectedUserEmail = '';
    SEARCH_BY_EMAIL = SEARCH_BY_EMAIL;
    
    columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Username', fieldName: 'Username' },
        { label: 'Email', fieldName: 'Email' }
    ];

    connectedCallback() {
        if (this.initialSearchTerm) {
            this.searchTerm = this.initialSearchTerm;
            this.handleSearch(); // Tự động gọi API tìm kiếm khi Modal vừa mở lên
        }
    }

    handleSearchTermChange(event) {
        this.searchTerm = event.target.value;
    }

    handleKeyup(event) {
        if (event.keyCode === 13) {
            this.handleSearch();
        }
    }

    handleSearch() {
        searchInternalUsers({ searchTerm: this.searchTerm })
            .then(result => {
                this.searchResults = result;
            })
            .catch(error => {
                console.error('Error searching users', error);
            });
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        this.selectedUserEmail = selectedRows.length > 0 ? selectedRows[0].Email : '';
    }

    handleCancel() {
        this.close(); 
    }

    handleSelect() {
        this.close(this.selectedUserEmail); 
    }
}