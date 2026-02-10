import { LightningElement, api, track } from 'lwc';
import getSalesInfoByIPPRecord from '@salesforce/apex/FEC_SalesInfoController.getSalesInfoByIPPRecord';

export default class Fec_SalesInfo extends LightningElement {
    @api recordId; // IPP Record Id
    
    @track salesInfo = {};
    @track isLoading = true;
    @track hasError = false;
    @track errorMessage = '';
    
    // Active accordion section - open by default
    activeSections = ['salesInfo'];
    
    // Storage key for accordion state
    get storageKey() {
        return `salesInfo_accordion_${this.recordId}`;
    }
    
    connectedCallback() {
        this.restoreAccordionState();
        this.loadSalesInfo();
    }
    
    restoreAccordionState() {
        try {
            const savedState = localStorage.getItem(this.storageKey);
            if (savedState) {
                this.activeSections = JSON.parse(savedState);
            } else {
                this.activeSections = ['salesInfo'];
            }
        } catch (e) {
            console.error('Error restoring accordion state:', e);
            this.activeSections = ['salesInfo'];
        }
    }
    
    handleAccordionToggle(event) {
        this.activeSections = event.detail.openSections;
        try {
            localStorage.setItem(this.storageKey, JSON.stringify(this.activeSections));
        } catch (e) {
            console.error('Error saving accordion state:', e);
        }
    }
    
    async loadSalesInfo() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        this.hasError = false;
        
        try {
            const result = await getSalesInfoByIPPRecord({ ippRecordId: this.recordId });
            console.log('Sales Info API Result:', result);
            if (result && result.isSuccess) {
                this.salesInfo = result;
                this.hasError = false;
                console.log('Sales Info loaded successfully:', this.salesInfo);
            } else {
                this.hasError = true;
                this.errorMessage = (result && result.errorMessage) || 'Failed to load Sales Info';
                console.error('Sales Info API failed:', this.errorMessage);
            }
        } catch (error) {
            console.error('Error loading Sales Info:', error);
            this.hasError = true;
            this.errorMessage = error.body?.message || error.message || 'Unknown error occurred';
        } finally {
            this.isLoading = false;
        }
    }
    
    @api
    refreshData() {
        this.loadSalesInfo();
    }
    
    // Getters for display
    get hasData() {
        if (this.hasError || !this.salesInfo) {
            return false;
        }
        // Kiểm tra xem có bất kỳ dữ liệu nào không (không chỉ applicationId)
        return this.salesInfo.applicationId || 
               this.salesInfo.ccCode || 
               this.salesInfo.ccName ||
               this.salesInfo.dsaCode ||
               this.salesInfo.dsaName ||
               this.salesInfo.tsaCode ||
               this.salesInfo.tsaName ||
               this.salesInfo.originationChannel ||
               this.salesInfo.disbursementChannel;
    }
    
    get sectionLabel() {
        if (this.hasError) {
            return 'Sales Info - Tải dữ liệu không thành công';
        }
        return 'Sales Info';
    }
    
    get sectionClass() {
        return this.hasError ? 'error-section' : '';
    }
    
    // Sales Info field getters
    get applicationId() {
        return this.salesInfo.applicationId || '-';
    }
    
    get ccCode() {
        return this.salesInfo.ccCode || '-';
    }
    
    get ccName() {
        return this.salesInfo.ccName || '-';
    }
    
    get dsaCode() {
        return this.salesInfo.dsaCode || '-';
    }
    
    get dsaName() {
        return this.salesInfo.dsaName || '-';
    }
    
    get tsaCode() {
        return this.salesInfo.tsaCode || '-';
    }
    
    get tsaName() {
        return this.salesInfo.tsaName || '-';
    }
    
    get originationChannel() {
        return this.salesInfo.originationChannel || '-';
    }
    
    get disbursementChannel() {
        return this.salesInfo.disbursementChannel || '-';
    }
    
    get salesMode() {
        return this.salesInfo.salesMode || '-';
    }
    
    get eSignSource() {
        return this.salesInfo.eSignSource || '-';
    }
}
