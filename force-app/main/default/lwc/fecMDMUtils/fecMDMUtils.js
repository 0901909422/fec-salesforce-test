/**
 * Description: Common Utility for FEC Project
 */
const IS_LOG_ENABLED = true;
/**
 * Description: Hiển thị log và giữ lại các trường null/undefined dưới dạng chuỗi
 */
export const showLog = (title, value) => {
    if (!IS_LOG_ENABLED) return;

    let displayValue;
    if (typeof value === 'object') {
        // Sử dụng replacer để không bỏ sót trường nào
        displayValue = JSON.stringify(value, (k, v) => v === undefined ? 'undefined' : v, 2);
    } else {
        displayValue = value;
    }

    console.log(`%c [LOG] ${title}: \n`, 'color: #0070d2; font-weight: bold;', displayValue);
};