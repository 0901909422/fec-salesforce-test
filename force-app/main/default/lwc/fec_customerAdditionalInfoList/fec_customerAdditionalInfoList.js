import { LightningElement, track } from 'lwc';
import { COLUMNS_PENDING, COLUMNS_PROCESSED, HISTORY_COLUMNS, DEFAULT_FORM_DATA } from 'c/fecUtils';

export default class FecCustomerAdditionalInfoList extends LightningElement {
    @track columnsProcessed = COLUMNS_PROCESSED;
    @track columnsPending = COLUMNS_PENDING;
    @track historyColumns = HISTORY_COLUMNS; 
    
    @track uploadedData = []; 
    @track processedData = []; 
    @track historyData = [];

    originalProcessedData = []; 
    originalUploadedData = [];
    originalHistoryData = [];

    // Sort
    @track processedSortedBy; @track processedSortDirection = 'asc';
    @track uploadedSortedBy; @track uploadedSortDirection = 'asc';
    @track historySortedBy; @track historySortDirection = 'asc';
    
    // Filter
    @track currentFilterTable = ''; 
    @track currentFilterColumn = ''; 
    @track currentFilterLabel = ''; 
    @track filterOptions = [];      
    @track activeFilters = { processed: {}, uploaded: {}, history: {} }; 
    
    // Modal
    @track isHistoryModalOpen = false;
    @track isEditModalOpen = false;
    @track modalTitle = 'Thêm mới Trường Thông Tin';
    @track formData = { ...DEFAULT_FORM_DATA };

    connectedCallback() {
        this.generateMockData();
    }

    generateMockData() {
        const mockProcessed = [
            { id: '11', accountNumber: 'ACC-001', dataLabel: 'Age Proof', status: 'Processed', isActive: true, startDate: '28/11/2023', endDate: '' },
            { id: '12', accountNumber: 'ACC-002', dataLabel: 'Cust Type', status: 'Pending', isActive: true, startDate: '26/11/2020', endDate: '' },
            { id: '13', accountNumber: 'ACC-003', dataLabel: 'Income Proof', status: 'Reuploaded', isActive: false, startDate: '09/07/2025', endDate: '' },
            { id: '14', accountNumber: 'ACC-001', dataLabel: 'Address Proof', status: 'Processed', isActive: true, startDate: '01/01/2023', endDate: '' },
            { id: '15', accountNumber: 'ACC-004', dataLabel: 'ID Card', status: 'Processed', isActive: false, startDate: '01/01/2024', endDate: '' },
        ];
        this.processedData = this.originalProcessedData = [...mockProcessed]; 
        
        const mockUploaded = [
            { id: '1', accountNumber: 'Temp-01', dataLabel: 'Temp Z', status: 'Uploaded'},
            { id: '2', accountNumber: 'Temp-03', dataLabel: 'Temp A', status: 'Pending'},
            { id: '3', accountNumber: 'Temp-02', dataLabel: 'Temp B', status: 'Uploaded'}
        ];
        this.uploadedData = this.originalUploadedData = [...mockUploaded];

        const mockHistory = [
            { id: 'h1', field: 'dataLabel', oldValue: 'Old Name', newValue: 'New Name', changedBy: 'Admin User', changeDate: '2025-12-15T10:00:00Z' },
            { id: 'h2', field: 'field', oldValue: 'isActive', newValue: 'False', changedBy: 'System', changeDate: '2025-12-14T09:30:00Z' }
        ];
        this.historyData = this.originalHistoryData = [...mockHistory];

        this.existingFiles = [
            { id: 'f1', name: 'document_v1.pdf', status: 'Hoàn tất', uploadedBy: 'Admin User', uploadTime: '15:30 15/12/2025' },
            { id: 'f2', name: 'template_02.csv', status: 'Thất bại', uploadedBy: 'User A', uploadTime: '10:00 14/12/2025' }
        ];
    }

    get originalData() {
        if (this.currentFilterTable === 'processed') return this.originalProcessedData;
        if (this.currentFilterTable === 'uploaded') return this.originalUploadedData;
        if (this.currentFilterTable === 'history') return this.originalHistoryData;
        return [];
    }

     // Row Actions
    handleProcessedRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'view_history') this.openHistoryModal(row);
        else if (action === 'edit') this.openEditModal(row);
    }
    
    handleUploadedRowAction(event) {
        const action = event.detail.action.name;
        const row = event.detail.row;
        if (action === 'edit') {
            this.openEditModal(row);
        }
    }
    
    handleReload() { 
        this.generateMockData(); 
        this.activeFilters = { processed: {}, uploaded: {}, history: {} }; 
        this.updateAllColumnsActionState();
    }

    updateAllColumnsActionState() {
        const resetAction = (col) => col.actions ? { ...col, actions: col.actions.map(a => a.name === 'filter_action' ? { ...a, checked: false } : a)} : col;
        this.columnsProcessed = this.columnsProcessed.map(resetAction);
        this.columnsPending = this.columnsPending.map(resetAction);
        this.historyColumns = this.historyColumns.map(resetAction);
    }

    openHistoryModal(){ this.isHistoryModalOpen = true; }
    closeHistoryModal(){ this.isHistoryModalOpen = false; }
    handleAddNew() {
        this.modalTitle = 'Thêm mới Trường Thông Tin';
        this.formData = { ...DEFAULT_FORM_DATA };
        this.isEditModalOpen = true;
    }
    openEditModal(row) {
        this.modalTitle = 'Chỉnh sửa: ' + row.accountNumber;
        this.formData = { ...row, accountLinkage: row.accountNumber.split('-')[1] };
        this.isEditModalOpen = true;
    }
    handleCloseModal() { this.isEditModalOpen = false; }
    handleSaveModal(event) {
        const updatedData = event.detail; // Dữ liệu từ con gửi lên
        console.log('Dữ liệu nhận được từ Modal:', JSON.stringify(updatedData));
        this.handleCloseModal();
    }
}