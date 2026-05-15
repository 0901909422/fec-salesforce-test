import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import LightningConfirm from 'lightning/confirm';
import getAllNfuCodes from '@salesforce/apex/FEC_NfuCodeController.getAllNfuCodes';
import saveNfuCode from '@salesforce/apex/FEC_NfuCodeController.saveNfuCode';
import deleteNfuCode from '@salesforce/apex/FEC_NfuCodeController.deleteNfuCode';
import seedNfuCodes from '@salesforce/apex/FEC_NfuCodeController.seedNfuCodes';

export default class FecNfuCodeList extends LightningElement {
    @track codeList = [];
    @track isModalOpen = false;
    @track formCode = '';
    @track formReasonVN = '';
    @track formActive = true;
    editRecordId = null;
    isLoading = false;
    wiredResult;
    searchTerm = '';
    @track allCodes = [];
    currentPage = 1;
    pageSize = 10;

    get modalTitle() {
        return this.editRecordId ? 'Edit NFU Code' : 'New NFU Code';
    }

    get hasCodes() {
        return this.pagedCodeList && this.pagedCodeList.length > 0;
    }

    @wire(getAllNfuCodes)
    wiredCodes(result) {
        this.wiredResult = result;
        if (result.data) {
            this.allCodes = result.data;
            this.applySearch();
        }
    }

    applySearch() {
        let filtered;
        if (!this.searchTerm) {
            filtered = [...this.allCodes];
        } else {
            const key = this.searchTerm.toLowerCase();
            filtered = this.allCodes.filter(c =>
                (c.Name || '').toLowerCase().includes(key) ||
                (c.FEC_Reason_VN__c || '').toLowerCase().includes(key)
            );
        }
        this.codeList = filtered;
        this.currentPage = 1;
    }

    get totalRecords() {
        return this.codeList.length;
    }

    get pagedCodeList() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.codeList.slice(start, start + this.pageSize);
    }

    handlePageChange(event) {
        this.currentPage = event.detail.page;
    }

    handlePageSizeChange(event) {
        this.pageSize = event.detail.pageSize;
        this.currentPage = 1;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.applySearch();
    }

    handleNew() {
        this.editRecordId = null;
        this.formCode = '';
        this.formReasonVN = '';
        this.formActive = true;
        this.isModalOpen = true;
    }

    handleEdit(event) {
        const id = event.currentTarget.dataset.id;
        const rec = this.allCodes.find(c => c.Id === id);
        if (!rec) return;
        this.editRecordId = id;
        this.formCode = rec.Name || '';
        this.formReasonVN = rec.FEC_Reason_VN__c || '';
        this.formActive = rec.FEC_Active__c;
        this.isModalOpen = true;
    }

    async handleDelete(event) {
        const id = event.currentTarget.dataset.id;
        const confirmed = await LightningConfirm.open({
            message: 'Delete this NFU Code?', variant: 'header',
            label: 'Confirm Delete', theme: 'warning'
        });
        if (!confirmed) return;
        this.isLoading = true;
        try {
            await deleteNfuCode({ recordId: id });
            this.showToast('Success', 'NFU Code deleted', 'success');
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.showToast('Error', e.body?.message || 'Delete failed', 'error');
        } finally { this.isLoading = false; }
    }

    handleFormInput(event) {
        const field = event.target.dataset.field;
        if (field === 'code') this.formCode = event.target.value;
        else if (field === 'reasonVN') this.formReasonVN = event.target.value;
        else if (field === 'active') this.formActive = event.target.checked;
    }

    async handleSave() {
        if (!this.formCode || !this.formCode.trim()) {
            this.showToast('Error', 'NFU Code is required', 'error');
            return;
        }
        this.isLoading = true;
        try {
            await saveNfuCode({
                codeName: this.formCode.trim(),
                reasonVN: this.formReasonVN || '',
                isActive: this.formActive,
                recordId: this.editRecordId
            });
            this.showToast('Success', 'NFU Code saved', 'success');
            this.isModalOpen = false;
            await refreshApex(this.wiredResult);
        } catch (e) {
            this.showToast('Error', e.body?.message || 'Save failed', 'error');
        } finally { this.isLoading = false; }
    }

    handleCancel() { this.isModalOpen = false; }

    async handleSeedData() {
        this.isLoading = true;
        try {
            const count = await seedNfuCodes();
            if (count > 0) {
                this.showToast('Success', `Seeded ${count} NFU codes from Pega`, 'success');
                await refreshApex(this.wiredResult);
            } else {
                this.showToast('Info', 'NFU codes already exist, no seed needed', 'info');
            }
        } catch (e) {
            this.showToast('Error', e.body?.message || 'Seed failed', 'error');
        } finally { this.isLoading = false; }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}