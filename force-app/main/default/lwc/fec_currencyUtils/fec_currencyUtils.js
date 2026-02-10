/**
 * Định dạng số thành chuỗi tiền tệ có dấu phân cách hàng nghìn
 * @param {Number} value - Giá trị số cần định dạng
 * @param {Number} decimals - Số chữ số thập phân (0 hoặc 2)
 * @returns {String} Chuỗi tiền tệ đã định dạng
 */
export function formatCurrency(value, decimals = 0) {
    if (value === null || value === undefined || isNaN(value)) {
        return '0';
    }
    
    const absValue = Math.abs(value);
    const formattedValue = absValue.toLocaleString('en-US', {
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals
    });
    
    return value < 0 ? `-${formattedValue}` : formattedValue;
}

/**
 * Kiểm tra giá trị có phải số âm hay không
 * @param {Number} value - Giá trị số cần kiểm tra
 * @returns {Boolean} True nếu giá trị là số âm
 */
export function isNegative(value) {
    return value !== null && value !== undefined && !isNaN(value) && value < 0;
}

/**
 * Trả về CSS class cho giá trị tiền tệ (đỏ cho số âm)
 * @param {Number} value - Giá trị số
 * @returns {String} Tên CSS class ('currency-negative' cho số âm, chuỗi rỗng cho số dương)
 */
export function getCurrencyClass(value) {
    return isNegative(value) ? 'currency-negative' : '';
}

/**
 * Kiểm tra xem một giá trị có phải là số (number) không
 * @param {*} value - Giá trị cần kiểm tra
 * @returns {Boolean} True nếu là số hợp lệ
 */
function isNumericValue(value) {
    // Bỏ qua null, undefined, boolean, string không phải số
    if (value === null || value === undefined || typeof value === 'boolean') {
        return false;
    }
    
    // Nếu đã là number type
    if (typeof value === 'number') {
        return !isNaN(value) && isFinite(value);
    }
    
    // Nếu là string, kiểm tra xem có thể convert sang number không
    if (typeof value === 'string') {
        // Bỏ qua string rỗng
        if (value.trim() === '') {
            return false;
        }
        // Kiểm tra xem có phải là số hợp lệ không (bao gồm số âm)
        const numValue = Number(value);
        return !isNaN(numValue) && isFinite(numValue);
    }
    
    return false;
}


/**
 * Tự động quét và highlight các giá trị tiền tệ âm cho nhiều records cùng lúc
 * Method này tự động phát hiện tất cả các field có giá trị số âm trong mỗi record
 * 
 * @param {Array<Object>} records - Mảng các record objects từ API
 * @param {Array<String>} excludeFields - (Optional) Danh sách các field cần bỏ qua
 * @returns {Array<Object>} Mảng các records đã được thêm CSS class
 * 
 * @example
 * const records = [
 *   { Id: '001', ippBalance: -1000000, currentBalance: 500000 },
 *   { Id: '002', ippBalance: 2000000, amount: -300000 }
 * ];
 * const processed = autoHighlightNegativeCurrencyForRecords(records);
 */
export function autoHighlightNegativeCurrencyForRecords(records, excludeFields = []) {
    if (!Array.isArray(records) || records.length === 0) {
        return records || [];
    }
    
    return records.map(record => autoHighlightNegativeCurrency(record, excludeFields));
}

/**
 * Định dạng tiền tệ cho ô hiển thị trong datatable
 * Dùng trong custom datatable type để xử lý giá trị âm (highlight đỏ)
 * @param {Number} value - Giá trị số
 * @param {Number} decimals - Số chữ số thập phân (0 hoặc 2)
 * @returns {Object} Object chứa giá trị đã định dạng và CSS class
 */
export function formatCurrencyForTable(value, decimals = 0) {
    return {
        formatted: formatCurrency(value, decimals),
        cssClass: getCurrencyClass(value),
        isNegative: isNegative(value)
    };
}
