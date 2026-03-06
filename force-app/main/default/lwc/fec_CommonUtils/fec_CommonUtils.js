import { getFocusedTabInfo, setTabLabel, setTabIcon } from 'lightning/platformWorkspaceApi';
import { STR_EMPTY, MSG_PHONE_ONLY_NUMBERS, MSG_PHONE_FORMAT_0_OR_84, MSG_INVALID_NATIONAL_ID_OR_PASSPORT, MSG_NATIONAL_ID_9_OR_12_CHARS, MSG_PASSPORT_1_LETTER_7_DIGITS, MSG_PASSPORT_START_UPPERCASE_THEN_7, MSG_PASSPORT_1_UPPERCASE_FOLLOWED_BY_7, MSG_PASSPORT_1_LETTER_7_DIGITS_ONLY, MSG_NATIONAL_ID_9_OR_12_DIGITS, MSG_NATIONAL_ID_9_OR_12_DIGITS_ONLY, MSG_NATIONAL_ID_PASSPORT_RULES, MSG_INVALID_NATIONAL_ID, MSG_NATIONAL_ID_DIGITS_ONLY_9_OR_12, MSG_INVALID_EMAIL_FORMAT } from 'c/fec_CommonConst';

const formatDate = (curr) => {
  if (!curr) {
    return null;
  }

  curr = new Date(curr);
  const year = curr.getFullYear();
  const month = String(curr.getMonth() + 1).padStart(2, "0"); // Months are zero-indexed
  const day = String(curr.getDate()).padStart(2, "0");

  return `${day}/${month}/${year}`;
};

/**
 * Format date-time as DD/MM/YYYY, HH:mm:ss (e.g. 28/12/2025, 13:20:10)
 */
const formatDateTime = (curr) => {
  if (!curr) {
    return null;
  }

  curr = new Date(curr);
  const year = curr.getFullYear();
  const month = String(curr.getMonth() + 1).padStart(2, "0");
  const day = String(curr.getDate()).padStart(2, "0");
  const h = String(curr.getHours()).padStart(2, "0");
  const m = String(curr.getMinutes()).padStart(2, "0");
  

  return `${day}/${month}/${year}, ${h}:${m}`;
};

const mask = (s, keepStart = 4, keepEnd = 4) => {
  if (!s) return STR_EMPTY;
  s = String(s);

  const len = s.length;

  if (len <= keepStart + keepEnd) {
    return "*".repeat(len);
  }

  const hiddenLength = len - keepStart - keepEnd;

  return (
    s.slice(0, keepStart) + "*".repeat(hiddenLength) + s.slice(len - keepEnd)
  );
};

// const formatDateVNI = (d) => {
//   if (!d) return "";
//   const date = new Date(d);
//   return `${date.getDate().toString().padStart(2, "0")}/${(date.getMonth() + 1).toString().padStart(2, "0")}/${date.getFullYear()}`;
// };
/**
 * ISO → DD/MM/YYYY (VN display)
 * SAFE: no Date object
 */
const formatDateVNI = (iso) => {
  if (!iso || typeof iso !== "string") return STR_EMPTY;

  const parts = iso.split("-");
  if (parts.length !== 3) return STR_EMPTY;

  const [y, m, d] = parts;
  return `${d}/${m}/${y}`;
};

/**
 * ISO → DD/MM/YYYY (display)
 */
const formatToDDMMYYYY = (iso) => {
  if (!iso || typeof iso !== "string") return STR_EMPTY;

  const parts = iso.split("-");
  if (parts.length !== 3) return STR_EMPTY;

  const [y, m, d] = parts;
  if (!y || !m || !d) return STR_EMPTY;

  return `${d}/${m}/${y}`;
};

/**
 * Parse DD/MM/YYYY -> YYYY-MM-DD
 * Validate calendar
 */
const parseDateVNI = (s) => {
  if (!s || typeof s !== "string") return STR_EMPTY;

  const trimmed = s.trim();
  if (!trimmed) return STR_EMPTY;

  const parts = trimmed.split("/");
  if (parts.length !== 3) return STR_EMPTY;

  let [day, month, year] = parts.map((p) => parseInt(p, 10));

  if (!day || !month || !year) return STR_EMPTY;

  // basic range
  if (year < 1000 || year > 9999) return STR_EMPTY;
  if (month < 1 || month > 12) return STR_EMPTY;
  if (day < 1) return STR_EMPTY;

  // ===== REAL CALENDAR CHECK =====
  const daysInMonth = new Date(year, month, 0).getDate();
  if (day > daysInMonth) return STR_EMPTY;

  // format
  const y = String(year);
  const m = String(month).padStart(2, "0");
  const d = String(day).padStart(2, "0");

  return `${y}-${m}-${d}`;
};

const maskWorkPhone = (phone) => {
  if (phone.length < 7) {
    return phone;
  }

  let first = phone.substring(0, 4);
  let last = phone.substring(phone.length - 3);

  return first + "***" + last;
};

const maskValue = (value, showFull) => {
  if (!value) return STR_EMPTY;
  if (showFull) return value;

  const v = value.trim();

  /* =====================
   * PASSPORT ID (bắt đầu bằng chữ)
   * Hiển thị: 2 ký tự đầu + 3 ký tự cuối
   * ===================== */
  if (/^[A-Za-z]/.test(v)) {
    if (v.length <= 5) return v;
    return v.substring(0, 2) + "*".repeat(v.length - 5) + v.slice(-3);
  }

  /* =====================
   * PHONE NUMBER (10 số)
   * Hiển thị: 4 số đầu + 3 số cuối
   * Ví dụ: 0906***678
   * ===================== */
  if (/^\d{10}$/.test(v)) {
    return v.substring(0, 4) + "*".repeat(v.length - 7) + v.slice(-3);
  }

  /* =====================
   * CCCD (toàn số, > 6)
   * Hiển thị: 3 số đầu + 3 số cuối
   * ===================== */
  if (/^\d+$/.test(v)) {
    if (v.length <= 6) return v;
    return v.substring(0, 3) + "*".repeat(v.length - 6) + v.slice(-3);
  }

  return v;
};

/* =========================
 * PHONE VALIDATION
 * - Bắt đầu bằng 0: đúng 10 ký tự.
 * - Bắt đầu bằng 84: đúng 11 ký tự.
 * ========================= */
const validateUpdatedInfoPhone = (phone) => {
  if (phone == null || typeof phone !== "string") return null;

  const trimmed = phone.trim();
  if (trimmed === STR_EMPTY) return null;

  if (!/^\d+$/.test(trimmed)) return MSG_PHONE_ONLY_NUMBERS;

  if (!/^(0\d{9}|84\d{9})$/.test(trimmed))
    return MSG_PHONE_FORMAT_0_OR_84;

  return null;
};

/**
 * Giới hạn chuỗi nhập số điện thoại khi gõ:
 * - Bắt đầu bằng 84 → tối đa 11 ký tự.
 * - Bắt đầu bằng 0 → tối đa 10 ký tự.
 * - Chỉ giữ lại ký tự số.
 * @param {string} value
 * @returns {string}
 */
const applyPhoneInputMaxLength = (value) => {
  if (value == null || typeof value !== "string") return STR_EMPTY;
  const cleaned = String(value).replace(/\D/g, STR_EMPTY);
  if (cleaned.startsWith("84")) return cleaned.slice(0, 11);
  if (cleaned.startsWith("0")) return cleaned.slice(0, 10);
  return cleaned.slice(0, 11);
};

/* =========================
 * EMAIL VALIDATION
 * - Phải có đúng một @
 * - Sau @ bắt buộc có ít nhất một dấu chấm (domain.tld)
 * - TLD (phần sau dấu chấm cuối) chỉ 2-5 chữ cái (a-zA-Z), ví dụ .com, .vn
 * ========================= */
const EMAIL_TLD_2_5 = "[a-zA-Z]{2,5}";
const EMAIL_LOCAL = "[a-zA-Z0-9._%+-]+";
const EMAIL_DOMAIN = "[a-zA-Z0-9.-]+";
const EMAIL_PART_1 = `${EMAIL_LOCAL}@${EMAIL_DOMAIN}\\.${EMAIL_TLD_2_5}`;
const EMAIL_PART_2 = `${EMAIL_LOCAL}@${EMAIL_DOMAIN}\\.${EMAIL_TLD_2_5}\\.${EMAIL_TLD_2_5}`;

const UPDATED_INFO_EMAIL_REGEX = new RegExp(
  "^\\s*(" + EMAIL_PART_1 + "|" + EMAIL_PART_2 + ")\\s*$",
);

const TLD_ONLY_LETTERS_REGEX = /^[a-zA-Z]{2,5}$/;

const validateUpdatedInfoEmail = (value) => {
  if (value == null || typeof value !== "string") {
    return { valid: true };
  }

  const trimmed = value.trim();
  if (trimmed === STR_EMPTY) {
    return { valid: true };
  }

  const atIdx = trimmed.indexOf("@");
  if (atIdx === -1) {
    return { valid: false, message: MSG_INVALID_EMAIL_FORMAT };
  }
  const afterAt = trimmed.slice(atIdx + 1);
  const lastDotIdx = afterAt.lastIndexOf(".");
  if (lastDotIdx === -1) {
    return { valid: false, message: MSG_INVALID_EMAIL_FORMAT };
  }
  const tld = afterAt.slice(lastDotIdx + 1);
  if (!TLD_ONLY_LETTERS_REGEX.test(tld)) {
    return { valid: false, message: MSG_INVALID_EMAIL_FORMAT };
  }
  if (!UPDATED_INFO_EMAIL_REGEX.test(trimmed)) {
    return { valid: false, message: MSG_INVALID_EMAIL_FORMAT };
  }

  return { valid: true };
};

/**
 * Validate National ID (CMND/CCCD) hoặc Passport.
 * - CMND: 9 chữ số
 * - CCCD: 12 chữ số
 * - Passport: 1 chữ hoa (A-Z) + đúng 7 chữ số (vd: D1234567)
 * @param {string} value
 * @returns {{ isValid: boolean, message?: string, type?: string }}
 */
const validateIdNumber = (value) => {
  if (value == null || typeof value !== "string") {
    return { isValid: false, message: MSG_INVALID_NATIONAL_ID_OR_PASSPORT };
  }
  const trimmedValue = value.trim();

  const nationalIdRegex = /^\d{9}$|^\d{12}$/;
  const passportRegex = /^[A-Z]\d{7}$/;

  if (nationalIdRegex.test(trimmedValue)) {
    return {
      isValid: true,
      type: "National ID",
      message: MSG_NATIONAL_ID_9_OR_12_CHARS,
    };
  }

  if (passportRegex.test(trimmedValue)) {
    return {
      isValid: true,
      type: "Passport",
      message: MSG_PASSPORT_1_LETTER_7_DIGITS,
    };
  }

  // Phân nhánh message theo từng trường hợp invalid
  if (trimmedValue === STR_EMPTY) {
    return { isValid: false, message: MSG_INVALID_NATIONAL_ID_OR_PASSPORT };
  }
  // Bắt đầu bằng chữ → coi như đang nhập Passport (bắt buộc chữ hoa + 7 số)
  if (/^[A-Za-z]/.test(trimmedValue)) {
    const rest = trimmedValue.slice(1).replace(/\D/g, STR_EMPTY);
    if (/^[a-z]/.test(trimmedValue)) {
      return {
        isValid: false,
        message: MSG_PASSPORT_START_UPPERCASE_THEN_7,
      };
    }
    if (rest.length < 7) {
      return {
        isValid: false,
        message: MSG_PASSPORT_1_UPPERCASE_FOLLOWED_BY_7,
      };
    }
    if (rest.length > 7) {
      return {
        isValid: false,
        message: MSG_PASSPORT_1_LETTER_7_DIGITS_ONLY,
      };
    }
    return {
      isValid: false,
      message: MSG_PASSPORT_START_UPPERCASE_THEN_7,
    };
  }
  // Toàn số → đang nhập CMND/CCCD
  if (/^\d+$/.test(trimmedValue)) {
    const len = trimmedValue.length;
    if (len < 9) {
      return {
        isValid: false,
        message: MSG_NATIONAL_ID_9_OR_12_DIGITS,
      };
    }
    if (len > 12) {
      return {
        isValid: false,
        message: MSG_NATIONAL_ID_9_OR_12_DIGITS_ONLY,
      };
    }
    return {
      isValid: false,
      message: MSG_NATIONAL_ID_9_OR_12_DIGITS,
    };
  }
  // Có ký tự không phải số (và không phải dạng Passport)
  return {
    isValid: false,
    message: MSG_NATIONAL_ID_PASSPORT_RULES,
  };
};

/**
 * Validate CMND/CCCD (chỉ số, không có Passport).
 * - CMND: 9 chữ số
 * - CCCD: 12 chữ số
 * @param {string} value
 * @returns {{ isValid: boolean, message?: string }}
 */
const validateNationalId = (value) => {
  if (value == null || typeof value !== "string") {
    return { isValid: false, message: MSG_INVALID_NATIONAL_ID };
  }
  const trimmedValue = value.trim();
  const nationalIdRegex = /^\d{9}$|^\d{12}$/;

  if (nationalIdRegex.test(trimmedValue)) {
    return {
      isValid: true,
      message: MSG_NATIONAL_ID_9_OR_12_CHARS,
    };
  }

  // Phân nhánh message theo từng trường hợp invalid (chỉ CMND/CCCD)
  if (trimmedValue === STR_EMPTY) {
    return { isValid: false, message: MSG_INVALID_NATIONAL_ID };
  }
  if (!/^\d+$/.test(trimmedValue)) {
    return {
      isValid: false,
      message: MSG_NATIONAL_ID_DIGITS_ONLY_9_OR_12,
    };
  }
  const len = trimmedValue.length;
  if (len < 9) {
    return {
      isValid: false,
      message: MSG_NATIONAL_ID_9_OR_12_DIGITS,
    };
  }
  if (len > 12) {
    return {
      isValid: false,
      message: MSG_NATIONAL_ID_9_OR_12_DIGITS_ONLY,
    };
  }
  return {
    isValid: false,
    message: MSG_NATIONAL_ID_9_OR_12_DIGITS,
  };
};

/**
 * Chỉ giữ lại ký tự hợp lệ cho National ID/Passport khi nhập liệu.
 * - National ID: chỉ số (0-9), tối đa 12 ký tự
 * - Passport: 1 chữ hoa (A-Z) + đúng 7 số, tối đa 8 ký tự (vd: D1234567)
 * @param {string} value
 * @returns {string}
 */
const validateUpdatedInfoNationalID = (value) => {
  if (value == null || typeof value !== "string") return STR_EMPTY;
  const v = String(value);

  const firstLetterMatch = v.match(/^[A-Z]/);
  if (firstLetterMatch) {
    const firstChar = firstLetterMatch[0];
    const restDigits = v.slice(1).replace(/\D/g, STR_EMPTY).slice(0, 7);
    return firstChar + restDigits;
  }

  return v.replace(/\D/g, STR_EMPTY).slice(0, 12);
};

// Cặp Original/Updated để kiểm tra "chưa cập nhật" khi submit
const ORIGINAL_UPDATED_FIELD_PAIRS = [
  {
    original: "FEC_Original_Info_Phone_Number__c",
    updated: "FEC_Updated_Info_Phone_Number__c",
  },
  {
    original: "FEC_Original_Info_First_Name__c",
    updated: "FEC_Updated_Info_First_Name__c",
  },
  {
    original: "FEC_Original_Info_Middle_Name__c",
    updated: "FEC_Updated_Info_Middle_Name__c",
  },
  {
    original: "FEC_Original_Info_Last_Name__c",
    updated: "FEC_Updated_Info_Last_Name__c",
  },
  {
    original: "FEC_Original_Info_Email__c",
    updated: "FEC_Updated_Info_Email__c",
  },
  {
    original: "FEC_Original_Info_Date_of_Birth__c",
    updated: "FEC_Updated_Info_Date_of_Birth__c",
  },
  {
    original: "FEC_Original_Info_Gender__c",
    updated: "FEC_Updated_Info_Gender__c",
  },
  {
    original: "FEC_Original_Info_National_ID__c",
    updated: "FEC_Updated_Info_National_ID__c",
  },
  {
    original: "FEC_Original_Info_Date_of_Issue__c",
    updated: "FEC_Updated_Info_Date_of_Issue__c",
  },
  {
    original: "FEC_Original_Info_Place_of_Issue__c",
    updated: "FEC_Updated_Info_Place_of_Issue__c",
  },
];

const _normalizeForCompare = (v) => {
  if (v == null) return STR_EMPTY;
  if (typeof v !== "string") return String(v).trim();
  return v.trim();
};

// true = mọi cặp (chỉ cặp đang hiển thị) đều original === updated → chặn submit
const checkNoUpdateInSubmit = (getOriginalValue, getUpdatedValue, options) => {
  const presentSet = options?.presentUpdatedApiNames;
  const pairsToCheck =
    presentSet != null &&
    (Set.prototype.isPrototypeOf(presentSet) || Array.isArray(presentSet))
      ? ORIGINAL_UPDATED_FIELD_PAIRS.filter((p) =>
          Set.prototype.isPrototypeOf(presentSet)
            ? presentSet.has(p.updated)
            : presentSet.includes(p.updated),
        )
      : ORIGINAL_UPDATED_FIELD_PAIRS;

  if (pairsToCheck.length === 0) return false;

  for (const pair of pairsToCheck) {
    const orig = _normalizeForCompare(getOriginalValue(pair.original));
    const upd = _normalizeForCompare(getUpdatedValue(pair.updated));
    if (orig !== upd) return false;
  }
  return true;
};

const isOnlyNumber = (text) => {
  return /^[0-9]+$/.test(text);
};

/* =========================
 * CONSOLE TAB HELPER
 * ========================= */
/**
 * Set Console Tab Label & Icon
 * @param {string} label
 * @param {string} icon (vd: 'standard:case')
 */
const setConsoleTab = async (label, icon) => {
  try {
    const tabInfo = await getFocusedTabInfo();
    const { tabId } = tabInfo;

    if (label) {
      await setTabLabel(tabId, label);
    }

    if (icon) {
      await setTabIcon(tabId, icon, {
        iconAlt: label || "Tab",
      });
    }
  } catch (e) {
   console.error(e);
  }
};

const urlCmpWithRecordId = (cmp, recordId) => {
  return `/lightning/cmp/c__${cmp}?c__recordId=${recordId}`;
}

/* ================= NEGATIVE HELPER ================= */
const isNegative = (value) => {
  if (value === null || value === undefined || value === '') {
    return false;
  }

  if (typeof value === 'number') {
    return value < 0;
  }

  const cleaned = value.toString().replace(/,/g, '').trim();

  if (cleaned === '' || isNaN(cleaned)) {
    return false;
  }

  return Number(cleaned) < 0;
};

const formatNumber = (value) => {
  if (value === null || value === undefined) return '';
  try {
    return new Intl.NumberFormat('en-US').format(value);
  } catch {
    return value;
  }
}

export {
  formatDate,
  formatDateTime,
  mask,
  formatDateVNI,
  formatToDDMMYYYY,
  parseDateVNI,
  maskWorkPhone,
  maskValue,
  validateUpdatedInfoPhone,
  applyPhoneInputMaxLength,
  validateUpdatedInfoEmail,
  validateIdNumber,
  validateNationalId,
  validateUpdatedInfoNationalID,
  checkNoUpdateInSubmit,
  isOnlyNumber,
  setConsoleTab,
  urlCmpWithRecordId,
  isNegative,
  formatNumber
};