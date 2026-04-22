/**
 * @description LWC Component quản lý danh sách và form tạo/sửa FEC Channel.
 * Tích hợp tính năng xem lịch sử cấu hình (Config History).
 * @date 2026-03-17
 * @author DAT NGO
 */
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
    FIELD_PROCESS_CHANGE_STATUS,
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
    LABEL_TOAST_ERROR_GENERIC,
    LABEL_ERROR_INVALID_RECORD_ID
} from 'c/fecConstants';

const COLUMNS = [
    { label: LABEL_COL_NAME, fieldName: FIELD_NAME, sortable: true },
    { label: LABEL_COL_CHANNEL_ID, fieldName: FIELD_CHANNEL_ID, sortable: true },
    { label: LABEL_COL_CHANNEL_VN_NAME, fieldName: FIELD_CHANNEL_VN_NAME, sortable: true },
    { label: LABEL_COL_CHANNEL_STATUS, fieldName: FIELD_CHANNEL_STATUS, sortable: true },
    { label: 'Process Status', fieldName: FIELD_PROCESS_CHANGE_STATUS, sortable: true },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: LABEL_ACTION_EDIT, name: ACTION_EDIT },
                { label: LABEL_ACTION_DELETE, name: ACTION_DELETE }
            ]
        },
        fixedWidth: 80
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

    // Add spinner property to manage loading state
    @track showSpinner = false;

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
            // KIỂM TRA ĐIỀU KIỆN XÓA TẠI ĐÂY
            if (row[FIELD_PROCESS_CHANGE_STATUS] !== 'New') {
                showLog('handleRowAction', 'Delete blocked. Status is not New: ' + row[FIELD_PROCESS_CHANGE_STATUS]);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Cảnh báo',
                    message: 'Chỉ được phép xóa bản ghi có Process Status là "New".',
                    variant: 'warning'
                }));
                return; // Dừng lại, không gọi hàm xóa
            }
            this.handleDelete(row.Id);
        }
    }

    // --- HÀM XỬ LÝ CLICK TOGGLE ---
    handleToggleHistory() {
        showLog('handleToggleHistory', 'START');
        this.isHistoryVisible = !this.isHistoryVisible;
    }

    refreshHistoryPanel() {
        showLog('refreshHistoryPanel', 'START');
        // Tìm component history thông qua data-id
        const historyComp = this.template.querySelector('[data-id="historyComponent"]');
        if (historyComp) {
            // Gọi hàm được @api expose bên trong fecConfigHistory
            historyComp.refreshData();
            showLog('refreshHistoryPanel', 'Triggered refreshData on child component');
        }
    }

    handleSubmit(event) {
        event.preventDefault(); // Chặn hành vi lưu mặc định
        showLog('handleSubmit', 'START');

        const fields = event.detail.fields;
        let isValid = true;

        // Khai báo các trường bắt buộc cần kiểm tra khoảng trắng
        const requiredFields = [this.fieldName, this.fieldChannelVnName];
        
        // Channel ID chỉ bắt buộc khi tạo mới (chưa có selectedId)
        if (!this.selectedId) {
            requiredFields.push(this.fieldChannelId);
        }

        // Quét kiểm tra và làm sạch dữ liệu
        for (let field of requiredFields) {
            let val = fields[field];
            if (val && String(val).trim() === '') {
                isValid = false;
                break;
            }
            if (val) {
                fields[field] = String(val).trim(); // Trim sạch 2 đầu
            }
        }

        if (!isValid) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Lỗi',
                message: 'Các trường bắt buộc không được để trống hoặc chỉ chứa khoảng trắng.',
                variant: VARIANT_ERROR
            }));
            showLog('handleSubmit', 'RETURN: Validation Failed');
            return;
        }

        // Nếu hợp lệ, bật spinner và submit thủ công
        this.showSpinner = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
        showLog('handleSubmit', 'RETURN: Submitted to Server');
    }

    async handleSuccess(event) {
        showLog('handleSuccess', 'START');

        // 1. Hiển thị thông báo thành công
        this.dispatchEvent(new ShowToastEvent({
            title: 'Thành công',
            message: 'Bản ghi đã được lưu thành công.',
            variant: 'success',
        }));

        // 2. Gọi refreshApex ngay lập tức để cập nhật bảng
        try {
            await refreshApex(this.wiredResult);
        } catch (error) {
            console.error('Error refreshing apex:', error);
        }

        // 3. MẤU CHỐT: Dùng setTimeout để tránh lỗi "Sorry to interrupt"
        // Trì hoãn việc destroy component Form khỏi DOM khoảng 100ms
        setTimeout(() => {
            this.selectedId = '';
            this.showForm = false;
            this.showSpinner = false;

            // Refresh History Panel nếu nó đang mở
            if (this.isHistoryVisible) {
                this.refreshHistoryPanel();
            }
        }, 100);

        showLog('handleSuccess', 'RETURN');
    }

    async handleCancel() {
        this.selectedId = '';
        this.showForm = false;
        await refreshApex(this.wiredResult);
    }

    async handleDelete(id) {
        showLog('handleDelete', 'START with ID: ' + id);
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
                this.showSpinner = true; 
                await deleteChannel({ recordId: id });

                // 1. Tắt spinner NGAY LẬP TỨC sau khi xóa thành công trên server
                this.showSpinner = false; 

                // 2. Thông báo và Refresh (Hai cái này chạy sau không ảnh hưởng đến UI chính)
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Thành công',
                    message: 'Đã xóa bản ghi.',
                    variant: 'success'
                }));

                // Refresh Datatable
                await refreshApex(this.wiredResult);

                // Refresh History Panel
                if (this.isHistoryVisible) {
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
        this.showSpinner = false; // Đảm bảo tắt loading khi có lỗi
        
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
}