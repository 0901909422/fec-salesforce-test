const AUTO_NOTIFICATION_HEADER_VI = 'New Notifications: Auto Notification';
const MANUAL_NOTIFICATION_HEADER_VI = 'New Notifications: Manual Notification';
const AUTO_NOTIFICATION_TYPE = 'Auto_Notification';
const MANUAL_NOTIFICATION_TYPE = 'Manual_Notification';
const STR_NA = 'N/A';
const MASKING_TYPE_PHONE = 'Mobile/ Phone';
const MASKING_TYPE_PASSPORT = 'National ID/ Passport';
const PHONE_VN_REGION = '84';
const DIV_ELEMENT = 'div';
const ICON_CASE = 'standard:case';
const ICON_PREVIEW = 'utility:preview';
const ICON_HIDE = 'utility:hide';
const OUTCOME_CODE = 'Hoàn tất/ Đã phản hồi';
const LOCALE_ENG = 'en-US';
const LOCALE_VN = 'vi-VN';
const STR_EMPTY = '';
const STR_NONE = 'none';
const STR_UNDEFINED = 'undefined';
const VIEW_MODE_HANDLING = 'handling';
const VIEW_MODE_REVIEW = 'review';
const ACTION_REOPEN = 'Reopen';
const ACTION_RECALL = 'Recall';
const MSG_PHONE_ONLY_NUMBERS = 'Phone number must only contain numbers';
const MSG_PHONE_FORMAT_0_OR_84 = 'Phone number must start with 0 (10 digits) or 84 (11 digits)';
const MSG_INVALID_NATIONAL_ID_OR_PASSPORT = 'Invalid National ID or Passport number';
const MSG_NATIONAL_ID_9_OR_12_CHARS = 'National ID must be 9 characters or 12 characters';
const MSG_PASSPORT_1_LETTER_7_DIGITS = 'Passport must be 1 uppercase letter and 7 digits';
const MSG_PASSPORT_START_UPPERCASE_THEN_7 = 'Passport must start with 1 uppercase letter (A-Z) then 7 digits';
const MSG_PASSPORT_1_UPPERCASE_FOLLOWED_BY_7 = 'Passport must be 1 uppercase letter (A-Z) followed by 7 digits';
const MSG_PASSPORT_1_LETTER_7_DIGITS_ONLY = 'Passport must be 1 uppercase letter and 7 digits only';
const MSG_NATIONAL_ID_9_OR_12_DIGITS = 'National ID must be 9 digits or 12 digits';
const MSG_NATIONAL_ID_9_OR_12_DIGITS_ONLY = 'National ID must be 9 or 12 digits only';
const MSG_NATIONAL_ID_PASSPORT_RULES = 'National ID/Passport: digits only, or 1 uppercase letter + 7 digits for Passport';
const MSG_INVALID_NATIONAL_ID = 'Invalid National ID number';
const MSG_NATIONAL_ID_DIGITS_ONLY_9_OR_12 = 'National ID must contain digits only (9 or 12 digits)';
const MSG_INVALID_EMAIL_FORMAT = 'Email must be one of (randomString1)@(randomString2).(2-5 chars) or (randomString1)@(randomString2).(2-5 chars).(2-5 chars)';
const UBANK_PRODUCT_NAME = 'UBank';
const RECORD_TYPE_INTERACTION = 'Interaction';
const RECORD_TYPE_CUSTOMER_CASE = 'Customer_Case';
const RECORD_TYPE_INTERNAL_CASE = 'Internal_Case';
const RECORD_TYPE_CUSTOMER_CASE_NAME = 'Customer Case';
const NON_EXISTING_CUSTOMER_PRODUCT_NAME = "Non-Existing Customer";
const NON_EXISTING_CUSTOMER_TYPE = "Non-existing";
const MSG_NO_RESULTS = 'Không tìm thấy kết quả';
const MSG_UNKNOWN_ERROR = 'Unknown error';
const CASE_OBJECT_API_NAME = 'Case';
const NAV_ACTION_VIEW = 'view';
const NAV_ACTION_LIST = 'list';
const CASE_ORIGIN_EMAIL_UBANK = 'Email-Ubank';
const CASE_ORIGIN_EMAIL_FE = 'Email-FE';
const CASE_ORIGIN_EMAIL_INTERNAL = 'Email-Internal';
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const RESULT_ERROR = "result-error";
const RESULT_SUCCESS = "result-success";
const RESPONE_MESSARE_ERROR = 'Số hợp đồng/ tài khoản này đã chuyển ngưng tác động thất bại'
const RESPONE_MESSARE_SUCCESS = 'Số hợp đồng/ tài khoản này đã chuyển ngưng tác động thành công'
const CHANNEL_OPTIONS = [
  { label: "Inbound", value: "Inbound" },
  { label: "Outbound", value: "Outbound" },
  { label: "Email", value: "Email" },
  { label: "Chat", value: "Chat" },
  { label: "F2F", value: "F2F" },
  { label: "Letter", value: "Letter" },
  { label: "Internal", value: "Internal" },
  { label: "External", value: "External" },
];
const SUB_CHANNEL_MAP = {
  Inbound: [{ label: "Inbound Call", value: "Inbound Call" }],
  Outbound: [{ label: "Outbound Call", value: "Outbound Call" }],
  Email: [
    { label: "Incoming Email", value: "Incoming Email" },
    { label: "Outgoing Email", value: "Outgoing Email" },
  ],
  Chat: [
    { label: "Facebook", value: "Facebook" },
    { label: "Zalo", value: "Zalo" },
    { label: "Website", value: "Website" },
    { label: "Mobile App", value: "Mobile App" },
  ],
  F2F: [{ label: "F2F", value: "F2F" }],
  Letter: [{ label: "Letter", value: "Letter" }],
  Internal: [
    { label: "Internal Email", value: "Internal Email" },
    { label: "iCollect", value: "iCollect" },
    { label: "iSale", value: "iSale" },
    { label: "VTiger", value: "VTiger" },
  ],
  External: [
    { label: "PR/MKT", value: "PR/MKT" },
    { label: "SBV", value: "SBV" },
    { label: "EA", value: "EA" },
    { label: "VPBank", value: "VPBank" },
    { label: "Website", value: "Website" },
    { label: "Zalo", value: "Zalo" },
    { label: "Mobile App", value: "Mobile App" },
  ],
};
const RECORD_TYPES = {
  INTERACTION: "Interaction",
  CUSTOMER_CASE: "Customer_Case",
};
const ERROR_MODAL_TITLE = "Error";
const SUCCESS_MODAL_TITLE = "Success";
const SUCCESS_TOAST_TYPE = "success";
const ERROR_TOAST_TYPE = "error";
const CLOSED_STATUS = "Closed";
const FORM_STATE_LOADING = 'LOADING';
const FORM_STATE_NONE = 'NONE';
const FORM_STATE_HAS_DATA = 'HAS_DATA';
const INTERNAL_REQUEST = 'Internal Request';
const INTERNAL_UBANK = 'Ubank';
const PATTERN_EMAIL_FEC_STRICT = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,5}(\.[A-Za-z]{2,5})?$/;
const PATTERN_PHONE_VN_FEC = /^(0\d{9}|84\d{9})$/;
const CONTRACT_CLOSURE_EMAIL_CHANNEL_C360 = 'C360';
const CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY = 'TEMPORARY';
const CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY = 'Temporary Address';
const CONTRACT_CLOSURE_DELIVERY_VALUE_ADDRESS_DEFAULT = 'Địa chỉ';
const CONTRACT_CLOSURE_DELIVERY_VALUE_OFFICE_DEFAULT = 'Văn phòng';
const WARNING_HOLD_CASE = 'Warning';
const WARNING_HOLD_TOAST = 'warning';
const RESPONSE_SUCCESS = 'SUCCESS';
const TARGET_GROUP_INTERNAL_USER = 'Internal User';
const SEARCH_PLACEHOLDER = 'Search User...';
const SEARCH_BY_EMAIL = 'Search By Email';
const SEARCH_INTERNAL_USERS = 'Search Internal Users';
const MIN_FAST_CASH_REGISTRATION_VND = 2000000;
const MAX_FAST_CASH_BLOCK_ATTEMPTS = 3;
const FEC_FAST_CASH_STORAGE_NOC_LOCK_PREFIX = 'fec_fc_noclock_';
const FEC_FAST_CASH_STORAGE_BLK_FAIL_PREFIX = 'fec_fc_blkfail_';
const FEC_FAST_CASH_STORAGE_BLK_OK_PREFIX = 'fec_fc_blkok_';
const ERROR_TILE_SHOWTOAST = 'Thất bại';

export { 
    AUTO_NOTIFICATION_HEADER_VI, 
    MANUAL_NOTIFICATION_HEADER_VI, 
    AUTO_NOTIFICATION_TYPE, 
    MANUAL_NOTIFICATION_TYPE,
    STR_NA,
    MASKING_TYPE_PHONE,
    MASKING_TYPE_PASSPORT,
    PHONE_VN_REGION,
    DIV_ELEMENT,
    ICON_CASE,
    ICON_PREVIEW,
    ICON_HIDE,
    OUTCOME_CODE,
    LOCALE_ENG,
    LOCALE_VN,
    STR_EMPTY,
    STR_NONE,
    STR_UNDEFINED,
    VIEW_MODE_HANDLING,
    VIEW_MODE_REVIEW,
    ACTION_REOPEN,
    ACTION_RECALL,
    MSG_PHONE_ONLY_NUMBERS,
    MSG_PHONE_FORMAT_0_OR_84,
    MSG_INVALID_NATIONAL_ID_OR_PASSPORT,
    MSG_NATIONAL_ID_9_OR_12_CHARS,
    MSG_PASSPORT_1_LETTER_7_DIGITS,
    MSG_PASSPORT_START_UPPERCASE_THEN_7,
    MSG_PASSPORT_1_UPPERCASE_FOLLOWED_BY_7,
    MSG_PASSPORT_1_LETTER_7_DIGITS_ONLY,
    MSG_NATIONAL_ID_9_OR_12_DIGITS,
    MSG_NATIONAL_ID_9_OR_12_DIGITS_ONLY,
    MSG_NATIONAL_ID_PASSPORT_RULES,
    MSG_INVALID_NATIONAL_ID,
    MSG_NATIONAL_ID_DIGITS_ONLY_9_OR_12,
    MSG_INVALID_EMAIL_FORMAT,
    UBANK_PRODUCT_NAME,
    RECORD_TYPE_INTERACTION,
    RECORD_TYPE_CUSTOMER_CASE,
    RECORD_TYPE_INTERNAL_CASE,
    RECORD_TYPE_CUSTOMER_CASE_NAME,
    NON_EXISTING_CUSTOMER_PRODUCT_NAME,
    NON_EXISTING_CUSTOMER_TYPE,
    MSG_NO_RESULTS,
    MSG_UNKNOWN_ERROR,
    CASE_OBJECT_API_NAME,
    NAV_ACTION_VIEW,
    NAV_ACTION_LIST,
    EMAIL_REGEX,
    CASE_ORIGIN_EMAIL_UBANK,
    CASE_ORIGIN_EMAIL_FE,
    CASE_ORIGIN_EMAIL_INTERNAL,
    CHANNEL_OPTIONS,
    SUB_CHANNEL_MAP,
    RECORD_TYPES,
    ERROR_MODAL_TITLE,
    SUCCESS_MODAL_TITLE,
    SUCCESS_TOAST_TYPE,
    ERROR_TOAST_TYPE,
    RESULT_ERROR,
    RESULT_SUCCESS,
    CLOSED_STATUS,
    FORM_STATE_LOADING,
    FORM_STATE_NONE,
    FORM_STATE_HAS_DATA,
    INTERNAL_REQUEST,
    INTERNAL_UBANK,
    PATTERN_EMAIL_FEC_STRICT,
    PATTERN_PHONE_VN_FEC,
    CONTRACT_CLOSURE_EMAIL_CHANNEL_C360,
    CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY,
    CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY,
    CONTRACT_CLOSURE_DELIVERY_VALUE_ADDRESS_DEFAULT,
    CONTRACT_CLOSURE_DELIVERY_VALUE_OFFICE_DEFAULT,
    WARNING_HOLD_CASE,
    WARNING_HOLD_TOAST,
    RESPONSE_SUCCESS,
    TARGET_GROUP_INTERNAL_USER,
    SEARCH_PLACEHOLDER,
    SEARCH_BY_EMAIL,
    SEARCH_INTERNAL_USERS,
    MIN_FAST_CASH_REGISTRATION_VND,
    MAX_FAST_CASH_BLOCK_ATTEMPTS,
    FEC_FAST_CASH_STORAGE_NOC_LOCK_PREFIX,
    FEC_FAST_CASH_STORAGE_BLK_FAIL_PREFIX,
    FEC_FAST_CASH_STORAGE_BLK_OK_PREFIX,
    SEARCH_INTERNAL_USERS,
    RESPONE_MESSARE_ERROR,
    RESPONE_MESSARE_SUCCESS,
    ERROR_TILE_SHOWTOAST
};