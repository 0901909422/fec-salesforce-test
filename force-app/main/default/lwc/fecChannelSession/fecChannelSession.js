import { LightningElement, wire, track } from 'lwc';
import getChannels from '@salesforce/apex/FEC_ChannelController.getChannels';
import deleteChannel from '@salesforce/apex/FEC_ChannelController.deleteChannel';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { showLog } from 'c/fecMDMUtils';
import { 
    FIELD_CHANNEL_ID, 
    FIELD_CHANNEL_VN_NAME, 
    FIELD_CHANNEL_STATUS, 
    FIELD_NAME, 
    VARIANT_SUCCESS, 
    VARIANT_ERROR, 
    OBJECT_MDM_CHANNEL,
    ACTION_EDIT,
    ACTION_DELETE,
    LABEL_COL_CHANNEL_ID,
    LABEL_COL_CHANNEL_VN_NAME,
    LABEL_COL_CHANNEL_STATUS,
    LABEL_COL_NAME,
    LABEL_ACTION_EDIT,
    LABEL_ACTION_DELETE,
    LABEL_BUTTON_SAVE_CHANNEL,
    LABEL_BUTTON_ADD_CHANNEL,
    LABEL_BUTTON_CANCEL_EDIT,
    LABEL_BUTTON_CANCEL,
    LABEL_CONFIRM_DELETE_CHANNEL,
    LABEL_TOAST_SAVE_SUCCESS,
    LABEL_TOAST_DELETE_SUCCESS,
    LABEL_TOAST_ERROR_GENERIC,
    LABEL_ERROR_INVALID_RECORD_ID
} from 'c/fecConstants';

const COLUMNS = [
    { label: LABEL_COL_NAME, fieldName: FIELD_NAME, sortable: true },
    { label: LABEL_COL_CHANNEL_ID, fieldName: FIELD_CHANNEL_ID, sortable: true },
    { label: LABEL_COL_CHANNEL_VN_NAME, fieldName: FIELD_CHANNEL_VN_NAME, sortable: true },
    { label: LABEL_COL_CHANNEL_STATUS, fieldName: FIELD_CHANNEL_STATUS, sortable: true },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: LABEL_ACTION_EDIT, name: ACTION_EDIT },
                { label: LABEL_ACTION_DELETE, name: ACTION_DELETE }
            ]
        }
    }
];

export default class FecChannelSession extends LightningElement {
    @track channels = [];
    @track filteredChannels = [];
    @track selectedId = ''; // QUAN TRỌNG: Khởi tạo chuỗi rỗng để @wire không bị chặn vì undefined
    @track showForm = false;
    @track sortBy;
    @track sortDirection;
    @track searchTerm = '';

    // --- BỔ SUNG STATE CHO TÍNH NĂNG TOGGLE HISTORY ---
    @track isHistoryVisible = false; // Mặc định ĐÓNG panel History khi mới vào trang

    // Getter tính toán kích thước cột chính (Left Panel)
    get mainPanelSize() {
        return this.isHistoryVisible ? 9 : 12;
    }

    // UX: Icon cái đồng hồ trực quan khi đóng, đổi thành dấu X khi mở
    get toggleHistoryIcon() {
        return this.isHistoryVisible ? 'utility:close' : 'utility:history';
    }

    get toggleTitle() {
        return this.isHistoryVisible ? 'Đóng Lịch sử' : 'Xem Lịch sử';
    }

    // UX: Call to Action rõ ràng (Đổi chữ linh hoạt)
    get toggleHistoryLabel() {
        return this.isHistoryVisible ? 'Đóng Lịch sử' : 'Xem Lịch sử';
    }

    // Getter thay đổi variant nút bấm
    get toggleButtonVariant() {
        return this.isHistoryVisible ? 'neutral' : 'brand-outline';
    }

    columns = COLUMNS;
    wiredResult;

    // expose labels and constants to template
    labelSaveChannel = LABEL_BUTTON_SAVE_CHANNEL;
    labelAddChannel = LABEL_BUTTON_ADD_CHANNEL;
    labelCancelEdit = LABEL_BUTTON_CANCEL_EDIT;
    labelCancel = LABEL_BUTTON_CANCEL;
    labelTitle = LABEL_COL_CHANNEL_ID;
    objectApiName = OBJECT_MDM_CHANNEL;
    fieldChannelId = FIELD_CHANNEL_ID;
    fieldName = FIELD_NAME;
    fieldChannelVnName = FIELD_CHANNEL_VN_NAME;
    fieldChannelStatus = FIELD_CHANNEL_STATUS;

    // --- TIỆN ÍCH LOG ---
    showLogCustom(methodName, message) {
        console.log(`[fecChannelSession][${methodName}]: ${message}`);
    }

    get defaultChannelStatus() {
        // Return true for new records, undefined for existing records to allow form to load value
        return this.selectedId ? undefined : true;
    }

    get buttonLabel() {
        // When the add form is opened, always show 'Save Channel' on the button
        if (this.showForm) {
            return LABEL_BUTTON_SAVE_CHANNEL;
        }
        return LABEL_BUTTON_ADD_CHANNEL;
    }

    handleShowForm() {
        this.selectedId = null;
        this.showForm = true;
    }

    @wire(getChannels)
    wiredData(result) {
        this.wiredResult = result;
        if (result.data) {
            this.channels = result.data;
            this.applySearch(); // Quan trọng: Đổ data mới nhất ra UI
            showLog('Load Channels Success', result.data);
        } else if (result.error) {
            showLog('Load Channels Error', result.error);
        }
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.applySearch();
    }

    applySearch() {
        if (!this.searchTerm || this.searchTerm.trim() === '') {
            // No search term, display all channels
            this.filteredChannels = [...this.channels];
        } else {
            // Filter channels by Name or Channel ID (case-insensitive)
            const searchKey = this.searchTerm.toLowerCase().trim();
            this.filteredChannels = this.channels.filter(channel => {
                const name = (channel[FIELD_NAME] || '').toLowerCase();
                const channelId = (channel[FIELD_CHANNEL_ID] || '').toLowerCase();
                return name.includes(searchKey) || channelId.includes(searchKey);
            });
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;
        if (actionName === ACTION_EDIT) {
            this.selectedId = row.Id;
            this.showForm = true;
            // Optionally, scroll to form or focus first input for better UX
        } else if (actionName === ACTION_DELETE) {
            this.handleDelete(row.Id);
        }
    }

    // --- HÀM XỬ LÝ CLICK TOGGLE ---
    handleToggleHistory() {
        this.showLogCustom('handleToggleHistory', 'START');
        this.isHistoryVisible = !this.isHistoryVisible;
        
        /* ĐÃ XÓA đoạn mã setTimeout gọi refreshHistoryPanel() ở đây.
           Bởi vì: Khi this.isHistoryVisible = true, thẻ <c-fec-config-history> mới được đưa vào DOM.
           Lúc này, @wire bên trong nó sẽ tự động nhận giá trị selectedId (là '' hoặc ID thực) và tự gọi server lần đầu tiên rất chuẩn xác.
        */
    }

    // --- BỔ SUNG HÀM REFRESH HISTORY ---
    refreshHistoryPanel() {
        this.showLogCustom('refreshHistoryPanel', 'START');
        // Tìm component history thông qua data-id
        const historyComp = this.template.querySelector('[data-id="historyComponent"]');
        if (historyComp) {
            // Gọi hàm được @api expose bên trong fecConfigHistory
            historyComp.refreshData();
            this.showLogCustom('refreshHistoryPanel', 'Triggered refreshData on child component');
        }
    }

    async handleSuccess(event) {
        this.showLogCustom('handleSuccess', 'START');
        
        // 1. Hiển thị thông báo thành công
        const evt = new ShowToastEvent({
            title: 'Thành công',
            message: 'Bản ghi đã được lưu thành công.',
            variant: 'success',
        });
        this.dispatchEvent(evt);
        
        // 2. Đóng form và reset ID về chuỗi rỗng
        this.selectedId = '';
        this.showForm = false;
        
        // 3. Quan trọng nhất: Gọi refreshApex để cập nhật Datatable
        try {
            await refreshApex(this.wiredResult);
            this.showLogCustom('handleSuccess', 'refreshApex completed');
        } catch(error) {
            console.error('Error refreshing apex:', error);
        }
        
        // 4. Refresh History Panel nếu nó đang mở
        if (this.isHistoryVisible) {
            this.refreshHistoryPanel();
        }
    }

    async handleCancel() {
        this.selectedId = '';
        this.showForm = false;
        await refreshApex(this.wiredResult);
    }

    async handleDelete(id) {
        this.showLogCustom('handleDelete', 'START with ID: ' + id);
        if (!id) {
            this.dispatchEvent(new ShowToastEvent({
                title: LABEL_TOAST_ERROR_GENERIC,
                message: LABEL_ERROR_INVALID_RECORD_ID,
                variant: 'error'
            }));
            return;
        }
        // Show confirmation dialog and disable UI during delete operation
        if (confirm(LABEL_CONFIRM_DELETE_CHANNEL)) {
            try {
                this.showSpinner = true; // Add spinner to indicate processing
                await deleteChannel({ recordId: id });
                
                // Hiển thị thông báo xóa thành công
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Thành công',
                    message: 'Đã xóa bản ghi.',
                    variant: 'success'
                }));
                
                // Refresh Datatable
                await refreshApex(this.wiredResult);
                
                // Refresh History Panel
                if(this.isHistoryVisible) {
                    this.refreshHistoryPanel();
                }
            } catch (error) {
                const msg = error?.body?.message || LABEL_TOAST_ERROR_GENERIC;
                this.dispatchEvent(new ShowToastEvent({
                    title: LABEL_TOAST_ERROR_GENERIC,
                    message: msg,
                    variant: 'error'
                }));
            } finally {
                this.showSpinner = false; // Hide spinner after operation
            }
        }
    }

    handleError(event) {
        const errorDetail = event?.detail?.detail || LABEL_TOAST_ERROR_GENERIC;
        
        // Extract user-friendly error message from Apex error
        let userMessage = LABEL_TOAST_ERROR_GENERIC;
        
        if (errorDetail) {
            const errorMsg = String(errorDetail).toLowerCase();
            
            // Map technical errors to user-friendly messages based on field names
            if (errorMsg.includes('required') || errorMsg.includes('required_field_missing')) {
                userMessage = 'Please fill in all required fields (Name, Channel ID, Channel Name VN, Status).';
            } else if (errorMsg.includes('duplicate') || errorMsg.includes('duplicate_value')) {
                userMessage = 'This Channel ID already exists. Please use a different value.';
            } else if (errorMsg.includes('invalid') || errorMsg.includes('invalid_field_value')) {
                userMessage = 'One or more fields contain invalid data. Please check and try again.';
            } else if (errorMsg.includes('update') && errorMsg.includes('failed')) {
                userMessage = 'Failed to update the channel. Please check your data and try again.';
            } else if (errorMsg.includes('insert') && errorMsg.includes('failed')) {
                userMessage = 'Failed to create the channel. Please check your data and try again.';
            } else {
                // For other errors, extract first sentence only
                const firstSentence = errorDetail.split('.')[0];
                userMessage = firstSentence ? firstSentence + '.' : LABEL_TOAST_ERROR_GENERIC;
            }
        }
        
        this.dispatchEvent(new ShowToastEvent({ title: LABEL_TOAST_ERROR_GENERIC, message: userMessage, variant: VARIANT_ERROR }));
    }

    // Sort handler
    handleSort(event) {
        const { fieldName: sortBy, sortDirection } = event.detail;
        this.sortBy = sortBy;
        this.sortDirection = sortDirection;
        this.sortData(sortBy, sortDirection);
    }

    sortData(fieldName, direction) {
        const parseData = JSON.parse(JSON.stringify(this.filteredChannels));
        const keyValue = (a) => {
            return a[fieldName];
        };
        const isReverse = direction === 'asc' ? 1 : -1;
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : '';
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });
        this.filteredChannels = parseData;
    }

    // Add spinner property to manage loading state
    @track showSpinner = false;
}