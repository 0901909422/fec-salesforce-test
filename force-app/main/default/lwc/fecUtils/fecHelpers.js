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

    return `${day}-${month}-${year}`;
}

export const formatString = (str, ...args) => {
    return str.replace(/{(\d+)}/g, (match, number) => {
        return typeof args[number] !== 'undefined' ? args[number] : match;
    });
}