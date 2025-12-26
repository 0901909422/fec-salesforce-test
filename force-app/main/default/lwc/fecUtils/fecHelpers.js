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