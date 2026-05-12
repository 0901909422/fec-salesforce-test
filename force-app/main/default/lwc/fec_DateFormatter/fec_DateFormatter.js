import { STR_EMPTY } from 'c/fec_CommonConst';
import { formatDate, formatDateTime } from 'c/fec_CommonUtils';

/**
 * Format date field from multiple formats (YYYYMMDD, YYYYMMDDTHHmmss.SSS GMT, ISO)
 * Automatically detects if time component exists and formats accordingly.
 * @param {*} raw - Raw date value (YYYYMMDD, YYYYMMDDTHHmmss, ISO, etc.)
 * @returns {string} Formatted date string (DD/MM/YYYY or DD/MM/YYYY, HH:mm:ss)
 */
const formatDateField = (raw) => {
    if (!raw || String(raw).trim() === STR_EMPTY) {
        return STR_EMPTY;
    }
    
    const rawStr = String(raw).trim();
    let dateObj = null;
    let hasTime = false;
    
    // Format: YYYYMMDD (8 ký tự số) - parse giống YYYYMMDDTHHmmss, giờ mặc định 00:00:00
    if (/^\d{8}$/.test(rawStr)) {
        const y = rawStr.substring(0, 4);
        const m = rawStr.substring(4, 6);
        const d = rawStr.substring(6, 8);
        const h = '00';
        const min = '00';
        const s = '00';
        dateObj = new Date(`${y}-${m}-${d}T${h}:${min}:${s}`);
        hasTime = true;
    }
    // Format: YYYYMMDDTHHmmss.SSS GMT hoặc YYYYMMDDTHHmmss - có giờ
    else if (/^\d{8}T\d{6}/.test(rawStr)) {
        const y = rawStr.substring(0, 4);
        const m = rawStr.substring(4, 6);
        const d = rawStr.substring(6, 8);
        const h = rawStr.substring(9, 11);
        const min = rawStr.substring(11, 13);
        const s = rawStr.substring(13, 15);
        dateObj = new Date(`${y}-${m}-${d}T${h}:${min}:${s}`);
        hasTime = true;
    }
    // Format chuẩn ISO hoặc các format khác - kiểm tra có giờ không
    else {
        dateObj = new Date(rawStr);
        // Kiểm tra xem có time component không (giờ khác 00:00:00)
        hasTime = rawStr.includes('T') || rawStr.includes(':') || 
                 (dateObj.getHours() !== 0 || dateObj.getMinutes() !== 0 || dateObj.getSeconds() !== 0);
    }
    
    // Kiểm tra date hợp lệ và format
    if (dateObj && !isNaN(dateObj.getTime())) {
        const formatted = hasTime ? formatDateTime(dateObj) : formatDate(dateObj);
        return formatted || raw;
    }
    
    return raw;
};

export { formatDateField };