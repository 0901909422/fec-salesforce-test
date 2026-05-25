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

/**
 * Parse giá trị cột ngày thô (API / DD/MM / YYYYMMDD…) thành timestamp để so sánh khi sort.
 * @param {*} v
 * @returns {number|null} epoch ms hoặc null nếu không parse được
 */
const toTimeForDefaultSort = (v) => {
    if (v == null || v === '') return null;
    if (typeof v === 'number' && !Number.isNaN(v)) return v;
    if (typeof v !== 'string') {
        const t = Date.parse(String(v));
        return Number.isNaN(t) ? null : t;
    }
    const s = v.trim();
    if (s === STR_EMPTY) return null;
    let m = s.match(/^(\d{2})\/(\d{2})\/(\d{4})$/);
    if (m) return new Date(+m[3], +m[2] - 1, +m[1]).getTime();
    m = s.match(/^(\d{2})\/(\d{2})\/(\d{4})(?:,\s*|\s+)(\d{2}):(\d{2}):(\d{2})$/);
    if (m) return new Date(+m[3], +m[2] - 1, +m[1], +m[4], +m[5], +m[6]).getTime();
    if (/^\d{8}$/.test(s)) {
        return new Date(+s.substring(0, 4), +s.substring(4, 6) - 1, +s.substring(6, 8)).getTime();
    }
    if (/^\d{8}T\d{6}/.test(s)) {
        return new Date(
            +s.substring(0, 4),
            +s.substring(4, 6) - 1,
            +s.substring(6, 8),
            +s.substring(9, 11),
            +s.substring(11, 13),
            +s.substring(13, 15)
        ).getTime();
    }
    const t = Date.parse(s);
    return Number.isNaN(t) ? null : t;
};

/**
 * Copy mảng object và sort theo trường ngày giảm dần (mới → cũ), dùng trước khi đưa vào bảng paging.
 * @param {object[]} rows
 * @param {string} fieldName
 * @returns {object[]}
 */
const sortByDefaultDateFieldDesc = (rows, fieldName) => {
    if (!Array.isArray(rows) || rows.length <= 1) {
        return Array.isArray(rows) ? [...rows] : [];
    }
    return [...rows].sort((a, b) => {
        const ta = toTimeForDefaultSort(a?.[fieldName]);
        const tb = toTimeForDefaultSort(b?.[fieldName]);
        if (ta != null && tb != null) return tb - ta;
        if (ta == null && tb != null) return 1;
        if (ta != null && tb == null) return -1;
        return 0;
    });
};

export { formatDateField, toTimeForDefaultSort, sortByDefaultDateFieldDesc };