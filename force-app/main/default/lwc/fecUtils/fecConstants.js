// 1. Actions dùng chung cho Header
export const HEADER_ACTIONS = [
    { label: 'Lọc', name: 'filter_action' }
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
