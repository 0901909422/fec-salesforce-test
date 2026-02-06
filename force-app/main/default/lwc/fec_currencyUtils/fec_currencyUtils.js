/**
 * Currency formatting utilities for FEC CSM
 * Provides consistent currency formatting across all LWC components
 * 
 * Format Requirements:
 * - Thousands separator with comma (e.g., 1,000,000)
 * - Support 0 or 2 decimal places (e.g., 1,102,372.90 or 1,918,207)
 * - Negative numbers displayed in red with (-) sign in front (e.g., -1,573,000)
 * - Red highlighting only applies on record detail screens, NOT on list views
 */

/**
 * Format a number as currency with thousands separators
 * @param {Number} value - The numeric value to format
 * @param {Number} decimals - Number of decimal places (0 or 2)
 * @returns {String} Formatted currency string
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
 * Check if a value is negative
 * @param {Number} value - The numeric value to check
 * @returns {Boolean} True if the value is negative
 */
export function isNegative(value) {
    return value !== null && value !== undefined && !isNaN(value) && value < 0;
}

/**
 * Get CSS class for currency value (red for negative)
 * @param {Number} value - The numeric value
 * @returns {String} CSS class name ('currency-negative' for negative, empty string for positive)
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
 * Tự động quét và highlight các giá trị tiền tệ âm trong record
 * Method này tự động phát hiện tất cả các field có giá trị số âm và thêm CSS class
 * Không cần phải chỉ định danh sách fields - hệ thống tự động quét
 * 
 * @param {Object} record - Record object từ API cần được xử lý
 * @param {Array<String>} excludeFields - (Optional) Danh sách các field cần bỏ qua (ví dụ: ['Id', 'CreatedDate'])
 * @returns {Object} Record đã được thêm CSS class cho các field tiền tệ âm
 * 
 * @example
 * const record = { 
 *   Id: '001', 
 *   ippBalance: -1000000, 
 *   currentBalance: 500000,
 *   name: 'Test',
 *   amount: -50000
 * };
 * const processed = autoHighlightNegativeCurrency(record);
 * // Kết quả: { 
 * //   Id: '001', 
 * //   ippBalance: -1000000, ippBalanceClass: 'currency-negative',
 * //   currentBalance: 500000, currentBalanceClass: '',
 * //   name: 'Test',
 * //   amount: -50000, amountClass: 'currency-negative'
 * // }
 */
export function autoHighlightNegativeCurrency(record, excludeFields = []) {
    if (!record || typeof record !== 'object') {
        return record;
    }
    
    // Danh sách các field mặc định cần bỏ qua (không phải là giá trị tiền tệ)
    const defaultExcludeFields = [
        'Id', 
        'attributes', 
        'CreatedDate', 
        'LastModifiedDate',
        'SystemModstamp',
        'CreatedById',
        'LastModifiedById',
        'OwnerId'
    ];
    
    // Kết hợp danh sách exclude
    const allExcludeFields = [...defaultExcludeFields, ...excludeFields];
    
    // Tạo bản sao của record để không modify object gốc
    const processedRecord = { ...record };
    
    // Duyệt qua tất cả các keys trong record
    Object.keys(record).forEach(fieldName => {
        // Bỏ qua các field trong danh sách exclude
        if (allExcludeFields.includes(fieldName)) {
            return;
        }
        
        // Bỏ qua các field đã có suffix 'Class' (để tránh xử lý lại)
        if (fieldName.endsWith('Class')) {
            return;
        }
        
        // Bỏ qua các field đã có suffix 'Formatted' (để tránh xử lý lại)
        if (fieldName.endsWith('Formatted')) {
            return;
        }
        
        const fieldValue = record[fieldName];
        
        // Kiểm tra xem giá trị có phải là số không
        if (isNumericValue(fieldValue)) {
            // Convert sang number nếu là string
            const numValue = typeof fieldValue === 'string' ? Number(fieldValue) : fieldValue;
            
            // Kiểm tra xem có phải số âm không
            if (isNegative(numValue)) {
                // Tự động thêm CSS class cho field này
                const classFieldName = fieldName + 'Class';
                processedRecord[classFieldName] = 'currency-negative';
            }
        }
    });
    
    return processedRecord;
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
 * Format currency for datatable cell renderer
 * Used in custom datatable type for handling negative values
 * @param {Number} value - The numeric value
 * @param {Number} decimals - Number of decimal places (0 or 2)
 * @returns {Object} Object with formatted value and CSS class
 */
export function formatCurrencyForTable(value, decimals = 0) {
    return {
        formatted: formatCurrency(value, decimals),
        cssClass: getCurrencyClass(value),
        isNegative: isNegative(value)
    };
}