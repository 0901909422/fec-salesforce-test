// 1. Actions dùng chung cho Header
export const HEADER_ACTIONS = [
    { label: 'Lọc', name: 'filter_action' }
];

// 2. Định nghĩa cột cho bảng Chờ xử lý (Pending/Uploaded)
export const COLUMNS_PENDING = [
    { label: 'Trường liên kết dữ liệu', fieldName: 'accountNumber', type: 'text', sortable: true, actions: HEADER_ACTIONS },
    { label: 'Tên trường dữ liệu', fieldName: 'dataLabel', type: 'text', sortable: true, actions: HEADER_ACTIONS },
    { label: 'Status', fieldName: 'status', type: 'text', sortable: true, actions: HEADER_ACTIONS },
    
    // CỘT HÀNH ĐỘNG 1: Edit Icon
    { 
        type: 'button-icon', 
        fixedWidth: 50, 
        typeAttributes: { 
            iconName: 'utility:edit', 
            name: 'edit', 
            variant: 'bare', 
            alternativeText: 'Chỉnh sửa'
        } 
    }
];

// 3. Định nghĩa cột cho bảng Đã xử lý (Processed)
export const COLUMNS_PROCESSED = [
    { 
        label: 'Trường liên kết dữ liệu', fieldName: 'accountNumber', type: 'text', sortable: true,
        actions: HEADER_ACTIONS 
    }, 
    { 
        label: 'Tên trường dữ liệu', fieldName: 'dataLabel', type: 'text', sortable: true, wrapText: true, 
        actions: HEADER_ACTIONS 
    }, 
    { 
        label: 'Tình trạng yêu cầu', fieldName: 'status', type: 'text', sortable: true,
        actions: HEADER_ACTIONS 
    },
    { 
        label: 'Is Active', fieldName: 'isActive', type: 'boolean', sortable: true, 
        actions: HEADER_ACTIONS 
    },
    { 
        label: 'Ngày bắt đầu', fieldName: 'startDate', type: 'text', sortable: true,
        actions: HEADER_ACTIONS 
    },
    { 
        label: 'End date', fieldName: 'endDate', type: 'text', sortable: true,
        actions: HEADER_ACTIONS 
    },
    { type: 'button', initialWidth: 100, typeAttributes: { label: 'Lịch sử', name: 'view_history', variant: 'brand-outline' }},
    { type: 'button-icon', fixedWidth: 50, typeAttributes: { iconName: 'utility:edit', name: 'edit', variant: 'bare' }}
];

export const HISTORY_COLUMNS = [
    { label: 'Trường thay đổi', fieldName: 'field', type: 'text', sortable: true, actions: HEADER_ACTIONS },
    { label: 'Giá trị cũ', fieldName: 'oldValue', type: 'text', actions: HEADER_ACTIONS },
    { label: 'Giá trị mới', fieldName: 'newValue', type: 'text', actions: HEADER_ACTIONS },
    { label: 'Người thay đổi', fieldName: 'changedBy', type: 'text', sortable: true, actions: HEADER_ACTIONS },
    { 
        label: 'Thời gian', fieldName: 'changeDate', type: 'datetime', sortable: true,
        actions: HEADER_ACTIONS
    } 
];

// 5. Các hằng số cấu hình khác
export const ACCOUNT_LINKAGE_OPTIONS = [
    { label: 'Select..', value: '' },
    { label: 'Số CIF', value: 'CIF' },
    { label: 'Số CMND/CCCD', value: 'ID_CARD' },
    { label: 'Số Hợp đồng', value: 'CONTRACT_NO' },
    { label: 'Số tài khoản', value: 'ACCOUNT_NO' },
    { label: 'Mã hồ sơ', value: 'APPLICATION_ID' },
    { label: 'Primary Phone Number', value: 'PHONE' }
];

export const DEFAULT_FORM_DATA = {
    accountLinkage: '', fieldCode: '', dataLabel: '', isActive: true,
    startDate: new Date().toISOString().substring(0, 10), endDate: ''
};