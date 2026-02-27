import { ShowToastEvent } from 'lightning/platformShowToastEvent';
/**
 * Formats datetime string to local format (DD/MM/YYYY HH:MM:SS)
 * @param {string} timeString - ISO datetime string or timestamp
 * @return {string} - Formatted datetime in DD/MM/YYYY HH:MM:SS format
 */
const formatDatetimeLocal = (timeString) => {
    const dateObj = new Date(timeString);
    const day = String(dateObj.getDate()).padStart(2, '0');
    const month = String(dateObj.getMonth() + 1).padStart(2, '0');
    const year = dateObj.getFullYear();
    const hours = String(dateObj.getHours()).padStart(2, '0');
    const minutes = String(dateObj.getMinutes()).padStart(2, '0');
    const seconds = String(dateObj.getSeconds()).padStart(2, '0');

    const result = `${day}/${month}/${year} ${hours}:${minutes}:${seconds}`;
    return result;
}

/**
 * Formats datetime string to custom format
 * @param {string} timeString - ISO datetime string
 * @param {boolean} onlyNumber - If true, returns YYYYMMDDhhmmss, else YYYYMMDDThhmm.0 GMT
 * @return {string} - Formatted datetime string
 */
const formatDatetime = (timeString, onlyNumber) => {
    const d = new Date(timeString);
    const year = "" + (d.getUTCFullYear());
    const month = ("" + (d.getUTCMonth() + 1)).padStart(2, "0");
    const day = ("" + d.getUTCDate()).padStart(2, "0");
    const hour = ("" + d.getUTCHours()).padStart(2, "0");
    const min = ("" + d.getUTCMinutes()).padStart(2, "0");
    const second = ("" + d.getUTCSeconds()).padStart(2, "0");

    let result = year + month + day;
    if (!onlyNumber) {
        result += "T";
    }
    result += hour + min + second;
    if (!onlyNumber) {
        result += ".0 GMT";
    }
    return result;
}

/**
 * Executes an asynchronous function with Web Locks API to prevent multi-tab duplication
 * @param {string} lockName - Unique lock identifier (e.g., message ID)
 * @param {Function} callback - Function containing actual logic to execute when lock is acquired
 * @param {boolean} prioritizeActiveTab - Prioritize active tab (default true). Background tabs wait 300ms
 * @return {Promise<boolean>} - Resolves to true if executed successfully, false if blocked by another tab
 */
const executeWithLock = (lockName, callback, prioritizeActiveTab = true) => {
    return new Promise((resolve, reject) => {
        // Xác định thời gian delay để ưu tiên tab đang active
        let delayTime = 0;
        if (prioritizeActiveTab) {
            const isFocused = document.hasFocus();
            delayTime = isFocused ? 0 : 300; // Background tab đợi 300ms
        }

        setTimeout(() => {
            if (navigator && navigator.locks) {
                navigator.locks.request(lockName, { mode: 'exclusive', ifAvailable: true }, async (lock) => {
                    if (!lock) {
                        console.log(`[Lock: ${lockName}] Another tab is processing. Yielded priority.`);
                        resolve(false); // Return false to signal safe blocking
                        return;
                    }

                    try {
                        // If lock acquired, run the actual logic provided
                        await callback();
                        resolve(true);
                    } catch (error) {
                        console.error(`[Lock: ${lockName}] Error executing callback:`, error);
                        reject(error);
                    }
                });
            } else {
                // Fallback if browser doesn't support Web Locks API
                console.warn('Browser does not support Web Locks API, running fallback.');
                callback().then(() => resolve(true)).catch(reject);
            }
        }, delayTime);
    });
}

/**
 * Fetches file from URL and converts to Blob
 * Tests CORS compatibility with file server
 * @param {string} fileUrl - URL of the file to fetch
 * @return {Promise<Blob>} - File blob data
 */
const fetchFileFromUrl = async (fileUrl) => {
    try {
        const response = await fetch(fileUrl);

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        const blob = await response.blob();
        return blob;
    } catch (error) {
        console.error('%cError fetching file:', LOG_ERROR, error);
        throw error;
    }
}

/**
 * Displays toast notification on UI
 * @created: 2025/12/29 long.nguyen.50
 * @param context - Component context (this) to dispatch the event
 * @param {string} title - Toast title
 * @param {string} message - Toast message content
 * @param {string} variant - Toast variant (success, error, warning, info)
 * @return {void}
 */
const showToast = (context, title, message, variant) => {
    console.log('show toast utils')
    // console.log(`showToast: [${variant.toUpperCase()}] ${title} - ${message}`);
    context.dispatchEvent(new ShowToastEvent({ title, message, variant }));
}


/**
 * Chuyển đổi chuỗi Base64 thành Uint8Array
 */
const base64ToUint8Array = (base64) => {
    const binaryString = atob(base64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
        bytes[i] = binaryString.charCodeAt(i);
    }
    return bytes;
}

/**
 * Hàm giải mã chính xác theo chuẩn PBEWITHHMACSHA256ANDAES_256 của Java
 * pass: 4mX2SmAeoLy9n8c1zsEpH+L37XrwsCGxvc1tAyOdaTpxgcOQuXitLA==
 */
const decryptDataKYC = async (encryptedBase64, password) => {
    if (!password) {
        throw new Error("SecretKey parameter must not be null or empty.");
    }
    if (!encryptedBase64) return "";
    const encoder = new TextEncoder();
    const decoder = new TextDecoder('utf-8');
    // 1. Chuẩn bị dữ liệu
    const encryptedBytes = base64ToUint8Array(encryptedBase64);
    const passwordBytes = encoder.encode(password);
    const saltBytes = encoder.encode("12345678"); // Salt cứng từ code Java
    // 2. Tạo IV 16-byte từ password (cắt hoặc đệm số 0 giống Java)
    const iv = new Uint8Array(16);
    iv.set(passwordBytes.slice(0, 16));
    try {
        // 3. Import password vào định dạng key của Web Crypto
        const keyMaterial = await window.crypto.subtle.importKey(
            "raw",
            passwordBytes,
            { name: "PBKDF2" },
            false,
            ["deriveBits", "deriveKey"]
        );

        // 4. Tạo khóa AES-256-CBC bằng thuật toán PBKDF2 (HMAC-SHA256, 20 iterations)
        const aesKey = await window.crypto.subtle.deriveKey(
            {
                name: "PBKDF2",
                salt: saltBytes,
                iterations: 20,
                hash: "SHA-256"
            },
            keyMaterial,
            { name: "AES-CBC", length: 256 },
            false,
            ["decrypt"]
        );
        console.log('i')
        // 5. Thực thi giải mã
        const decryptedBuffer = await window.crypto.subtle.decrypt(
            {
                name: "AES-CBC",
                iv: iv
            },
            aesKey,
            encryptedBytes
        );
        console.log("✅ KẾT QUẢ GIẢI MÃ:", decoder.decode(decryptedBuffer));
        // 6. Trả về chuỗi kết quả
        return decoder.decode(decryptedBuffer);

    } catch (error) {
        console.error("Lỗi giải mã:", error);
        return ""; // Hoặc throw error tùy logic xử lý UI của bạn
    }
}







export { formatDatetimeLocal, executeWithLock, fetchFileFromUrl, formatDatetime, showToast, decryptDataKYC };