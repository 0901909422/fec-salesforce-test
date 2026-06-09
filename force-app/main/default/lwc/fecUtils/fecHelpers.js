// --- HÀM HỖ TRỢ SORT ---
export const sortData = (data, field, direction) => {
    let parseData = [...data];
    const isReverse = direction === 'asc' ? 1 : -1;
    parseData.sort((a, b) => {
        let aValue = a[field];
        let bValue = b[field];
        if (typeof aValue === 'boolean' || typeof bValue === 'boolean') {
             aValue = aValue ? 1 : 0;
             bValue = bValue ? 1 : 0;
        } else {
             aValue = aValue ? String(aValue).toLowerCase() : '';
             bValue = bValue ? String(bValue).toLowerCase() : '';
        }
        return (aValue < bValue) ? -1 * isReverse : (aValue > bValue) ? 1 * isReverse : 0;
    });
    return parseData;
};

export const formatDateDDMMYYYY = (isoString) => {
    if (!isoString) return '';
    const date = new Date(isoString);
    
    // Lấy ngày, tháng, năm và đảm bảo luôn có 2 chữ số (padding 0)
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0'); // Tháng trong JS bắt đầu từ 0
    const year = date.getFullYear();

    return `${day}/${month}/${year}`;
}

export const formatString = (str, ...args) => {
    return str.replace(/{(\d+)}/g, (match, number) => {
        return typeof args[number] !== 'undefined' ? args[number] : match;
    });
}

export const getTomorrowDate = () => {
    const today = new Date();
    const tomorrow = new Date(today);
    // Cộng thêm 1 ngày
    tomorrow.setDate(tomorrow.getDate() + 1); 
    return tomorrow.toISOString().split('T')[0];
}

export const convertExcelToTimestamp = (value) => {
    if (!value) return null;

    let date;
    // Trường hợp 1: Excel trả về số (Serial Number)
    if (typeof value === 'number') {
        // Logic convert: (Value - 25569) * 86400 * 1000
        // 25569 là độ lệch ngày giữa Excel (1900) và Unix (1970)
        date = new Date(Math.round((value - 25569) * 86400 * 1000));
    } 
    // Trường hợp 2: Excel trả về String (VD: "10/25/2023")
    else {
        date = new Date(value);
    }

    // Kiểm tra xem date có hợp lệ không
    if (isNaN(date.getTime())) {
        return null; 
    }

    return date.toISOString(); // Trả về dạng: "2024-01-20T12:00:00.000Z"
}