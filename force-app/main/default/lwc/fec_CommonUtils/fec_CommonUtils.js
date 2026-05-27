import { getFocusedTabInfo, setTabLabel, setTabIcon } from 'lightning/platformWorkspaceApi';
import { STR_EMPTY, LOCALE_VN, MSG_PHONE_ONLY_NUMBERS, MSG_PHONE_FORMAT_0_OR_84, MSG_INVALID_NATIONAL_ID_OR_PASSPORT, MSG_NATIONAL_ID_9_OR_12_CHARS, MSG_PASSPORT_1_LETTER_7_DIGITS, MSG_PASSPORT_START_UPPERCASE_THEN_7, MSG_PASSPORT_1_UPPERCASE_FOLLOWED_BY_7, MSG_PASSPORT_1_LETTER_7_DIGITS_ONLY, MSG_NATIONAL_ID_9_OR_12_DIGITS, MSG_NATIONAL_ID_9_OR_12_DIGITS_ONLY, MSG_NATIONAL_ID_PASSPORT_RULES, MSG_INVALID_NATIONAL_ID, MSG_NATIONAL_ID_DIGITS_ONLY_9_OR_12, MSG_INVALID_EMAIL_FORMAT } from 'c/fec_CommonConst';

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
  const s = String(curr.getSeconds()).padStart(2, "0");

  return `${day}/${month}/${year}, ${h}:${m}:${s}`;
};

/**
 * Format date-time as DD/MM/YYYY HH:mm:ss (VN display)
 */
const formatDateTimeVN = (val) => {
  if (!val) return '';
  const d = new Date(val);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const h = String(d.getHours()).padStart(2, "0");
  const m = String(d.getMinutes()).padStart(2, "0");
  const s = String(d.getSeconds()).padStart(2, "0");

  return `${day}/${month}/${year}, ${h}:${m}:${s}`;
};

/**
 * Format date-time as DD/MM/YYYY, HH:mm (no seconds, VN display)
 */
const formatDateTimeVNShort = (val) => {
  if (!val) return '';
  const d = new Date(val);
  if (isNaN(d.getTime())) return val;
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  const h = String(d.getHours()).padStart(2, "0");
  const m = String(d.getMinutes()).padStart(2, "0");
  return `${day}/${month}/${year}, ${h}:${m}`;
};
/**
 * Format seconds as HH:mm:ss
 */
const formatDuration = (seconds) => {
  if (seconds == null || isNaN(Number(seconds))) return '';
  const n = Math.floor(Number(seconds));
  const h = Math.floor(n / 3600);
  const m = Math.floor((n % 3600) / 60);
  const s = n % 60;
  return [h, m, s].map((x) => String(x).padStart(2, "0")).join(':');
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
 * Flexible date -> DD/MM/YYYY
 * Accepts:
 * - YYYY-MM-DD / YYYY/MM/DD (optionally with time)
 * - DD/MM/YYYY
 * - MM/DD/YYYY (auto-convert to DD/MM/YYYY when ambiguous)
 */
const formatDateFlexibleVN = (input) => {
  if (!input) return STR_EMPTY;
  const raw = String(input).trim();
  if (!raw) return STR_EMPTY;

  const isoLike = raw.match(/^(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[T\s].*)?$/);
  if (isoLike) {
    const [, y, m, d] = isoLike;
    return `${String(d).padStart(2, "0")}/${String(m).padStart(2, "0")}/${y}`;
  }

  const slashLike = raw.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/);
  if (slashLike) {
    const [, p1, p2, y] = slashLike;
    const first = Number(p1);
    const second = Number(p2);
    const day = first > 12 ? first : second;
    const month = first > 12 ? second : first;
    return `${String(day).padStart(2, "0")}/${String(month).padStart(2, "0")}/${y}`;
  }

  const d = new Date(raw);
  if (isNaN(d.getTime())) return raw;
  const day = String(d.getDate()).padStart(2, "0");
  const month = String(d.getMonth() + 1).padStart(2, "0");
  const year = d.getFullYear();
  return `${day}/${month}/${year}`;
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
  if (!phone) return STR_EMPTY;
  const v = String(phone).trim();
  if (v.length < 7) return v;

  if (/^84\d{9,}$/.test(v)) {
    return v.substring(0, 5) + "*".repeat(v.length - 8) + v.slice(-3);
  }

  if (/^02\d{8}$/.test(v)) {
    return v.substring(0, 3) + "*".repeat(v.length - 6) + v.slice(-3);
  }

  if (/^0\d{9}$/.test(v)) {
    return v.substring(0, 4) + "*".repeat(v.length - 7) + v.slice(-3);
  }

  const first = v.substring(0, 4);
  const last = v.substring(v.length - 3);
  return first + "*".repeat(Math.max(0, v.length - 7)) + last;
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
   * PHONE bắt đầu bằng 84 (≥11 số: 84 + ít nhất 9 chữ số)
   * Hiển thị: 5 số đầu + 3 số cuối (chuỗi dài hơn 11 vẫn cùng rule)
   * Ví dụ: 84123***456
   * ===================== */
  if (/^84\d{9,}$/.test(v)) {
    return v.substring(0, 5) + "*".repeat(v.length - 8) + v.slice(-3);
  }

  /* =====================
   * PHONE bắt đầu bằng 0 (10 số)
   * Hiển thị: 4 số đầu + 3 số cuối
   * Ví dụ: 0123***456
   * ===================== */
  if (/^0\d{9}$/.test(v)) {
    return v.substring(0, 4) + "*".repeat(v.length - 7) + v.slice(-3);
  }
  /* =====================
   * LANDLINE bắt đầu bằng 02
   * Hiển thị: 3 số đầu + 3 số cuối
   * Ví dụ: 028*****456
  * ===================== */
  if (/^02\d{8,9}$/.test(v)) {
    return v.substring(0, 3) + "*".repeat(v.length - 6) + v.slice(-3);
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
const normalizePhone = (raw) => {
  if (!raw) {
    return STR_EMPTY;
  }
  let s = String(raw).replace(/\s/g, "");
  if (s.startsWith("+84")) {
    s = "84" + s.substring(3);
  }
  if (/^\d{10}$/.test(s) && s.startsWith("0")) {
    s = "84" + s.substring(1);
  }
  return s;
};

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

/** Tìm option theo raw (label hoặc value, có trim); dùng submit & label→API. */
const findPicklistOptionByRaw = (options, raw) => {
  if (!options || !Array.isArray(options) || options.length === 0) return undefined;
  if (raw == null || raw === STR_EMPTY) return undefined;
  const rawPl = typeof raw === "string" ? raw.trim() : raw;
  let opt = options.find((o) => o.label === raw);
  if (!opt && typeof rawPl === "string") {
    opt = options.find((o) => {
      const lb = o?.label;
      const t =
        typeof lb === "string" ? lb.trim() : String(lb ?? STR_EMPTY).trim();
      return t === rawPl;
    });
  }
  if (!opt) {
    opt = options.find((o) => o.value === raw || o.value === rawPl);
  }
  return opt;
};

/** Chuẩn hóa raw (label hoặc API value) về API value theo mảng options. */
const _normalizePicklistRawWithOpts = (opts, raw) => {
  const n = _normalizeForCompare(raw);
  if (!opts || !Array.isArray(opts) || opts.length === 0) return n;
  if (!n) return n;
  const opt = findPicklistOptionByRaw(opts, raw);
  if (opt) return _normalizeForCompare(opt.value);
  return n;
};

/** Picklist options cặp Original/Updated: ưu tiên original, không có thì updated. */
const _picklistOptsForOriginalUpdatedPair = (caseFieldOptions, pair) => {
  if (!caseFieldOptions || !pair) return null;
  let opts = caseFieldOptions[pair.original];
  if (opts && Array.isArray(opts) && opts.length > 0) return opts;
  opts = caseFieldOptions[pair.updated];
  if (opts && Array.isArray(opts) && opts.length > 0) return opts;
  return null;
};

const _GENDER_OU_PAIR = ORIGINAL_UPDATED_FIELD_PAIRS.find(
  (p) => p.updated === "FEC_Updated_Info_Gender__c",
);

const _isGenderOriginalUpdatedPair = (pair) =>
  pair != null &&
  _GENDER_OU_PAIR != null &&
  pair.original === _GENDER_OU_PAIR.original &&
  pair.updated === _GENDER_OU_PAIR.updated;

/** Chuẩn hóa Gender (M/F, Male/Female, Nam/Nữ, …) về M/F trước khi so sánh */
const _canonicalGenderApiForCompare = (s) => {
  const n = _normalizeForCompare(s);
  if (!n) return n;
  const k = n.toLowerCase();
  if (k === "m" || k === "male" || k === "nam") return "M";
  if (k === "f" || k === "female" || k === "nữ" || k === "nu") return "F";
  return n;
};

// true = mọi cặp (chỉ cặp đang hiển thị) đều original === updated → chặn submit
const checkNoUpdateInSubmit = (getOriginalValue, getUpdatedValue, options) => {
  const presentSet = options?.presentUpdatedApiNames;
  const picklistCase = options?.picklistCaseFieldOptions;
  const pairsToCheck =
    presentSet != null &&
      (Set.prototype.isPrototypeOf(presentSet) || Array.isArray(presentSet))
      ? ORIGINAL_UPDATED_FIELD_PAIRS.filter((p) =>
        Set.prototype.isPrototypeOf(presentSet)
          ? presentSet.has(p.updated) && presentSet.has(p.original)
          : presentSet.includes(p.updated) && presentSet.includes(p.original),
      )
      : ORIGINAL_UPDATED_FIELD_PAIRS;

  if (pairsToCheck.length === 0) return false;

  for (const pair of pairsToCheck) {
    const rawOrig = getOriginalValue(pair.original);
    const rawUpd = getUpdatedValue(pair.updated);
    let orig;
    let upd;
    if (picklistCase) {
      const pairOpts = _picklistOptsForOriginalUpdatedPair(picklistCase, pair);
      orig = _normalizePicklistRawWithOpts(pairOpts, rawOrig);
      upd = _normalizePicklistRawWithOpts(pairOpts, rawUpd);
    } else {
      orig = _normalizeForCompare(rawOrig);
      upd = _normalizeForCompare(rawUpd);
    }
    if (_isGenderOriginalUpdatedPair(pair)) {
      orig = _canonicalGenderApiForCompare(orig);
      upd = _canonicalGenderApiForCompare(upd);
    }
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
};

const getCaseIdNumber = (idText) => {
  const match = idText?.match(/\d+/);
  return match ? parseInt(match[0], 10) : 0;
};

/**
 * Format số với 2 chữ số thập phân, dùng cho tiền/amount. null/NaN → '0.00'.
 * @param {*} val - Giá trị số (number hoặc string)
 * @returns {string} Chuỗi đã format (vd: '1,234.00') hoặc '0.00'
 */
const formatNum = (val) => {
  if (val == null) return '0.00';
  const n = Number(val);
  if (Number.isNaN(n)) return '0.00';
  return n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};

/**
 * Chuẩn hóa chuỗi ngày sang YYYY-MM-DD để sort string đúng thứ tự.
 * Trả về '9999-12-31' khi val rỗng/blank hoặc '-' (ô trống).
 * @param {*} val - Giá trị ngày (string dạng YYYY-MM-DD hoặc DD/MM/YYYY, hoặc '-')
 * @returns {string} Chuỗi YYYY-MM-DD hoặc '9999-12-31' cho ô trống
 */
const toSortDateStr = (val) => {
  if (val == null || val === '' || String(val).trim() === '' || val === '-') return '9999-12-31';
  const s = String(val).trim();
  const iso = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})/);
  if (iso) return `${iso[1]}-${iso[2].padStart(2, '0')}-${iso[3].padStart(2, '0')}`.slice(0, 10);
  const parts = s.split('/').filter(Boolean);
  if (parts.length === 3) {
    // DD/MM/YYYY (chuẩn hiển thị FEC) — năm 4 chữ số ở cuối
    if (/^\d{4}$/.test(parts[2])) {
      const d = parts[0].padStart(2, '0');
      const m = parts[1].padStart(2, '0');
      const y = parts[2];
      return `${y}-${m}-${d}`;
    }
    // YYYY/MM/DD hoặc YYYY/M/D
    if (/^\d{4}$/.test(parts[0])) {
      return `${parts[0]}-${parts[1].padStart(2, '0')}-${parts[2].padStart(2, '0')}`;
    }
  }
  return s;
};
const sortByStringField = (list = [], field, direction = 'asc') => {
  if (!Array.isArray(list) || !field) return [];

  const dir = direction === 'desc' ? -1 : 1;

  return [...list].sort((a, b) => {
    const x = (a[field] || '').toString().trim().toLowerCase();
    const y = (b[field] || '').toString().trim().toLowerCase();

    return x.localeCompare(y) * dir;
  });
};

const stripToIntString = (raw) => {
  if (raw == null || raw === STR_EMPTY) {
    return STR_EMPTY;
  }
  const digits = String(raw).replace(/\D/g, '');
  return digits;
};

const formatThousandsFromDigits = (digits) => {
  if (!digits) {
    return STR_EMPTY;
  }
  const n = parseInt(digits, 10);
  if (isNaN(n)) {
    return STR_EMPTY;
  }
  return new Intl.NumberFormat(LOCALE_VN, {
    maximumFractionDigits: 0,
    minimumFractionDigits: 0
  }).format(n);
};

const formatThousandsFromDigitsEnUs = (digits) => {
  if (!digits) {
    return STR_EMPTY;
  }
  const n = parseInt(digits, 10);
  if (isNaN(n)) {
    return STR_EMPTY;
  }
  return new Intl.NumberFormat('en-US', {
    maximumFractionDigits: 0,
    minimumFractionDigits: 0
  }).format(n);
};

const toUpperNoVietnameseAccent = (str) => {
  if (!str) return '';

  return str
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toUpperCase()
    .trim();
};

const todayIso = () => {
  const t = new Date();
  const y = t.getFullYear();
  const m = String(t.getMonth() + 1).padStart(2, '0');
  const d = String(t.getDate()).padStart(2, '0');
  return y + '-' + m + '-' + d;
};

/** Human-readable file size (B … GB). Dùng bởi fec_FileUploadCard và LWC khác. */
const formatBytes = (bytes) => {
  const n = Number(bytes);
  if (!n || n <= 0) {
    return "0 B";
  }
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(n) / Math.log(k));
  return `${(n / k ** i).toFixed(i > 0 ? 1 : 0)} ${sizes[i]}`;
};

/** Ngày ngắn theo locale (vd. "18 Apr 2026") — list file. */
const formatShortDate = (dt) => {
  if (!dt) {
    return "";
  }
  try {
    const d = new Date(dt);
    return d.toLocaleDateString(undefined, {
      day: "2-digit",
      month: "short",
      year: "numeric"
    });
  } catch (e) {
    return "";
  }
};

/** Nhãn phần mở rộng file (tối đa 4 ký tự, in hoa). */
const extensionBadge = (ext) => {
  const e = (ext || "").toLowerCase().replace(/^\./, "");
  if (!e) {
    return "FILE";
  }
  return e.length <= 4 ? e.toUpperCase() : e.slice(0, 4).toUpperCase();
};

/**
 * `lightning-icon` icon-name theo phần mở rộng (ContentDocument.FileExtension / tên file).
 * Dùng cho bảng file / related list.
 */
const doctypeIconFromExtension = (ext) => {
  const e = (ext || "").toLowerCase().replace(/^\./, "");
  const map = {
    pdf: "doctype:pdf",
    xlsx: "doctype:excel",
    xls: "doctype:excel",
    csv: "doctype:csv",
    doc: "doctype:word",
    docx: "doctype:word",
    ppt: "doctype:ppt",
    pptx: "doctype:ppt",
    txt: "doctype:txt",
    xml: "doctype:xml",
    png: "doctype:image",
    jpg: "doctype:image",
    jpeg: "doctype:image",
    gif: "doctype:image",
    zip: "doctype:zip"
  };
  return map[e] || "doctype:attachment";
};

/**
 * Map 1 object cùng shape `FEC_CaseLinkedFilesController.CaseLinkedFileRow` → row UI bảng (Title / Owner / …).
 */
const mapLinkedFileToTableRow = (row) => {
  if (!row) {
    return null;
  }
  const ext = row.fileExtension || "";
  const title = row.title || row.contentDocumentId;
  return {
    id: row.linkId,
    linkLabel: title,
    contentDocumentId: row.contentDocumentId,
    ownerLabel: row.ownerName || "—",
    lastModifiedLabel: formatDateTimeVNShort(row.lastModifiedDate) || "—",
    sizeLabel: formatBytes(row.contentSize),
    iconName: doctypeIconFromExtension(ext)
  };
};

const formatCurrencyIncludeTax = (value, text) => {
  let val = formatNumber(value);
  if (!val || val == '0') return '';
  return val + ' ' + text;
}

/** Currency(18,0): phân cách hàng nghìn, không thập phân. VD: 8,200,000 */
const formatCurrency0 = (value) => {
  if (value == null || value === '' || value === '-') return '-';
  const num = Number(value);
  if (Number.isNaN(num)) return '-';
  return Math.round(num).toLocaleString('en-US');
};

/** Currency(16,2): phân cách hàng nghìn, 2 thập phân. VD: 5,526,000.00 */
const formatCurrency2 = (value) => {
  if (value == null || value === '' || value === '-') return '-';
  const num = Number(value);
  if (Number.isNaN(num)) return '-';
  return num.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
};

const getUsernameBeforeAt = (email) =>{
   if (!email) {
        return "";
    }

    return email.split("@")[0];
};

/* ---------- Batch import (fec_BatchCaseCreation / fec_BatchDataCreation) ---------- */

const normalizeHeaderCell = (cell) =>
  String(cell ?? "")
    .trim()
    .toLowerCase()
    .replace(/\s+/g, " ");

const findColumnIndex = (headersNorm, synonyms) => {
  for (let s = 0; s < synonyms.length; s += 1) {
    const idx = headersNorm.indexOf(synonyms[s]);
    if (idx >= 0) {
      return idx;
    }
  }
  return -1;
};

const normalizeNoteTextSafe = (text) => String(text ?? "").trim();

const promiseWithTimeoutSafe = (promise, timeoutMs, timeoutMessage) =>
  new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(timeoutMessage)), timeoutMs);
    Promise.resolve(promise)
      .then((value) => {
        clearTimeout(timer);
        resolve(value);
      })
      .catch((error) => {
        clearTimeout(timer);
        reject(error);
      });
  });

const arrayBufferToBase64Safe = (buffer) => {
  if (!buffer) {
    return "";
  }
  const bytes = new Uint8Array(buffer);
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode.apply(null, chunk);
  }
  return btoa(binary);
};

/**
 * Giữ số dài / SĐT dạng text (không scientific notation) khi đọc/ghi Excel.
 */
const formatSpreadsheetCellValueAsText = (value) => {
  if (value == null || value === "") {
    return "";
  }
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      return String(value);
    }
    const rounded = Math.round(value);
    const isWholeNumber = Math.abs(value - rounded) < 1e-9;
    if (isWholeNumber) {
      if (Math.abs(rounded) <= Number.MAX_SAFE_INTEGER) {
        return String(rounded);
      }
      try {
        return BigInt(rounded).toString();
      } catch {
        return rounded.toLocaleString("en-US", {
          useGrouping: false,
          maximumFractionDigits: 0
        });
      }
    }
    return value.toLocaleString("en-US", {
      useGrouping: false,
      maximumFractionDigits: 15
    });
  }
  return String(value).trim();
};

/**
 * Ưu tiên chuỗi hiển thị Excel (cell.w) để giữ leading zero / format custom.
 */
const getSheetJsCellDisplayText = (sheet, rowIndex, colIndex) => {
  if (!sheet || rowIndex < 0 || colIndex < 0) {
    return "";
  }
  const xlsx = typeof window !== "undefined" ? window.XLSX : null;
  if (!xlsx?.utils?.encode_cell) {
    return "";
  }
  const ref = xlsx.utils.encode_cell({ r: rowIndex, c: colIndex });
  const cell = sheet[ref];
  if (!cell) {
    return "";
  }
  if (cell.w != null && String(cell.w).trim() !== "") {
    return String(cell.w).trim();
  }
  return formatSpreadsheetCellValueAsText(cell.v);
};

const removeFileExtensionSafe = (fileName) => {
  const name = String(fileName ?? "");
  const dotIdx = name.lastIndexOf(".");
  if (dotIdx <= 0) {
    return name;
  }
  return name.substring(0, dotIdx);
};

const buildResultXlsxFileName = (sourceFileName) => {
  let base = removeFileExtensionSafe(sourceFileName);
  const lower = base.toLowerCase();
  if (lower.endsWith("_importresult")) {
    base = base.slice(0, -13);
  } else if (lower.endsWith("_result")) {
    base = base.slice(0, -7);
  }
  return `${base}_ImportResult.xlsx`;
};

const formatDateTimeEnGb = (value) => {
  try {
    return new Intl.DateTimeFormat("en-GB", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hour12: false
    }).format(new Date(value));
  } catch (e) {
    return value;
  }
};

const extractErrorMessage = (error) =>
  error?.body?.message || error?.message || "Unexpected error";

/** Encode ArrayBuffer to base64 (chunked for large buffers). */
const arrayBufferToBase64 = (buffer) => {
  if (!buffer) {
    return "";
  }
  const bytes = new Uint8Array(buffer);
  const chunkSize = 0x8000;
  let binary = "";
  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode.apply(null, chunk);
  }
  return btoa(binary);
};

export {
  formatDate,
  formatDateTime,
  formatDateTimeVN,
  formatDateTimeVNShort,
  mask,
  formatDateVNI,
  formatToDDMMYYYY,
  formatDateFlexibleVN,
  parseDateVNI,
  maskWorkPhone,
  maskValue,
  normalizePhone,
  validateUpdatedInfoPhone,
  applyPhoneInputMaxLength,
  validateUpdatedInfoEmail,
  validateIdNumber,
  validateNationalId,
  validateUpdatedInfoNationalID,
  checkNoUpdateInSubmit,
  findPicklistOptionByRaw,
  isOnlyNumber,
  setConsoleTab,
  urlCmpWithRecordId,
  isNegative,
  formatNumber,
  formatNum,
  toSortDateStr,
  formatDuration,
  getCaseIdNumber,
  sortByStringField,
  formatThousandsFromDigits,
  formatThousandsFromDigitsEnUs,
  stripToIntString,
  todayIso,
  toUpperNoVietnameseAccent,
  formatCurrencyIncludeTax,
  formatCurrency0,
  formatCurrency2,
  formatBytes,
  formatShortDate,
  extensionBadge,
  doctypeIconFromExtension,
  mapLinkedFileToTableRow,
  getUsernameBeforeAt,
  normalizeHeaderCell,
  findColumnIndex,
  formatSpreadsheetCellValueAsText,
  getSheetJsCellDisplayText,
  normalizeNoteTextSafe,
  promiseWithTimeoutSafe,
  arrayBufferToBase64Safe,
  removeFileExtensionSafe,
  buildResultXlsxFileName,
  formatDateTimeEnGb,
  extractErrorMessage,
  arrayBufferToBase64
};