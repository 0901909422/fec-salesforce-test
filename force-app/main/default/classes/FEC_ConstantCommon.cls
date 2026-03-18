public with sharing class FEC_ConstantCommon {
    public static final String API_CONTENT_TYPE = 'text/xml; charset=utf-8';
    public static final String API_CONTENT_TYPE_JSON = 'application/json';
    public static final String API_METHOD_POST = 'POST';
    public static final String API_METHOD_GET = 'GET';
    public static final String API_REQUESTOR_ID = 'SALESFORE-CSM';
    public static final String SOAP_ENV = 'http://schemas.xmlsoap.org/soap/envelope/';
    
    /** Chuỗi rỗng dùng chung (default khi value blank). */
    public static final String STR_EMPTY = '';
    
    /** Dấu phân tách dùng cho key (vd: RecordType|Channel). */
    public static final String KEY_DELIMITER_PIPE = '|';
    
    /** Dấu phân tách trong FEC_ID_Search__c (format: Prefix-Số, vd S-0001). */
    public static final String FEC_ID_SEARCH_DELIMITER = '-';
    
    /** Prefix cho các trạng thái Case đã resolved (Resolved-Completed, Resolved-Cancelled, ...) */
    public static final String CASE_STATUS_PREFIX_RESOLVED = 'Resolved';
    
    /** Follow-up: giá trị picklist "Until Case is Resolved" */
    public static final String FOLLOW_UP_TYPE_UNTIL_RESOLVED = 'Until Case is Resolved';
    /** Follow-up: giá trị picklist "Until choosing Unfollow" */
    public static final String FOLLOW_UP_TYPE_UNTIL_UNFOLLOW = 'Until choosing Unfollow';
    /** Follow-up: giá trị frontend UNTIL_RESOLVED */
    public static final String FOLLOW_UP_FRONTEND_RESOLVED = 'UNTIL_RESOLVED';
    /** Follow-up: giá trị frontend UNTIL_UNFOLLOW */
    public static final String FOLLOW_UP_FRONTEND_UNFOLLOW = 'UNTIL_UNFOLLOW';
    /** Follow-up: ký hiệu rút gọn trong FEC_Follow_Up_User__c cho Until Resolved */
    public static final String FOLLOW_UP_COMPACT_RESOLVED = 'R';
    /** Follow-up: ký hiệu rút gọn trong FEC_Follow_Up_User__c cho Until Unfollow */
    public static final String FOLLOW_UP_COMPACT_UNFOLLOW = 'U';
    /** Dấu phân tách giữa các entry trong FEC_Follow_Up_User__c */
    public static final String FOLLOW_UP_FIELD_DELIMITER = ';';
    
    public static final String STR_DATETIME_FORMAT = 'yyyy-MM-dd\'T\'HH:mm:ss.SSS';
    public static final String STR_DATETIME_FORMAT_Z = 'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'';
    public static final String STR_DATETIME_FORMAT_XXX = 'yyyy-MM-dd\'T\'HH:mm:ss.SSSXXX';
    public static final String DATETIME_FORMAT = 'yyyy-MM-dd\'T\'HH:mm:ss';
    public static final String DATE_FORMAT = 'yyyy-MM-dd';
    public static final String DATE_FORMAT_MMYYYY = 'MM/yyyy';
    public static final String DATETIME_FORMAT_OUTPUT = 'dd/MM/yyyy HH:mm:ss';
    
    public static final String CASE_INTERACTION_RECORD_TYPE_DEV_NAME = 'Interaction';
    public static final String CASE_CUSTOMER_RECORD_TYPE_DEV_NAME = 'Customer_Case';
    public static final String CASE_INTERNAL_RECORD_TYPE_DEV_NAME = 'Internal_Case';
    public static final String CASE_SEARCH_RECORD_TYPE_DEV_NAME = 'Search_Interaction';
    
    public static final String CHANNEL_INBOUND_API = 'InboundRinging';
    public static final String CHANNEL_OUTBOUND_API = 'OutboundEstablished';
    public static final String CHANNEL_INBOUND_NAME = 'Inbound';
    public static final String CHANNEL_OUTBOUND_NAME = 'Outbound';
    public static final String CHANNEL_ZALO = 'ZALO';
    public static final String CHANNEL_WEBSITE = 'WEBSITE';
    public static final String CHANNEL_FE_MOBILE_APP = 'FEMOBILEAPP';
    public static final String CHANNEL_EXTERNAL = 'External';
    public static final String CHANNEL_INTERNAL = 'Internal';
    public static final String STR_NA = 'N/A';
    
    public static final String CHANNEL_INBOUND_SUBCHANNEL_NAME = 'Inbound Call';
    public static final String CHANNEL_OUTBOUND_SUBCHANNEL_NAME = 'Outbound Call';
    public static final String CHANNEL_EXTERNAL_SUBCHANNEL_OTHER_NAME = 'Other';
    public static final String CHANNEL_CHAT = 'Chat';
    
    public static final String PATTERN_PHONE_NUMBER = '^(0\\d{9}|84\\d{9})$';
    public static final String PATTERN_NATIONAL_ID = '^(\\d{9}|\\d{12})$';
    public static final String PATTERN_APPLICATION_ID = '^(\\d{6}|\\d{8}|\\d{9})$';
    public static final String PATTERN_ACCOUNT_NUMBER = '^(\\d{16}|\\d{19})$';
    public static final String PATTERN_CONTRACT_NUMBER = '^(\\d{8}-\\d{6}-\\d{4}|\\d{8}-\\d{7}-\\d{3}|\\d{8}-\\d{7}-\\d{2}|\\d{8}-\\d{7}-\\d{1}|\\d{8}-\\d{7}|\\d{2}-\\d{2}-\\d{2}-\\d{2})$';
    public static final String PATTERN_EMAIL = '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,5}(\\.[A-Za-z]{2,5})?$';
    public static final String PATTERN_DATE = '^\\d{4}-\\d{2}-\\d{2}$';
    public static final String PATTERN_SYS_TIME = '\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}';
    public static final String PATTERN_DATE_TIME = '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$';
    public static final String PATTERN_DATE_TIME_FULL = '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}[+-]\\d{2}:\\d{2}$';
    public static final String PATTERN_DATE_FORMAT_MM = '^(1[0-2]|[1-9])$';
    public static final String PATTERN_DATE_FORMAT_DDMMYYZZ = '^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}\\.\\d{3}Z$';
    public static final String PATTERN_DATE_FORMAT_MMYYYY = '^(0[1-9]|1[0-2])/\\d{4}$';
    public static final String PATTERN_TOKEN_KYC = '\\{\\{(.*?)\\}\\}';
    
    // CARD: 16 hoặc 19 digits
    public static final String PATTERN_CARD = '^(\\d{16}|\\d{19})$';
    
    // LOAN: nhiều format khác nhau
    public static final String PATTERN_LOAN = '^(\\d{8}-\\d{6}-\\d{4}|\\d{8}-\\d{7}-\\d{3}|\\d{8}-\\d{7}-\\d{2}|\\d{8}-\\d{7}-\\d{1}|\\d{8}-\\d{7}|\\d{2}-\\d{2}-\\d{2}-\\d{2})$';
    
    // INSURANCE
    public static final String PATTERN_INSURANCE = '^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z0-9]+$';
    
    
    public static final String REQUESTOR_CRM = 'CRM';
    public static final String REQUESTOR_PORTAL = 'PORTAL';
    public static final String REQUESTOR_MOBILE_APP = 'MOBILE_APP';
    public static final String REQUESTOR_PEGA_CSM = 'PegaCSM';
    public static final String REQUESTOR_PEGA_CSM_HYPHEN = 'PEGA_CSM';
    public static final String REQUESTOR_APS = 'APS';
    public static final String REQUESTOR_SD = 'SD';
    public static final String REQUESTOR_VMXVERSION = 'R8V3';
    public static final String REQUESTOR_CONTEXT = 'CRM';
    public static final String REQUESTOR_ORG = '150';
    public static final String REQUESTOR_RES = 'RES';
    public static final String REQUESTOR_PEGA = 'PEGA';
    public static final String REQUESTOR_ESB = 'ESB';
    public static final String REQUESTOR_CORE = 'CORE';
    public static final String REQUESTOR_MOBILE = 'MOBILE';
    public static final String REQUESTOR_VMXVERSION_EMEA = 'E8V8';
    
    public static final String ADDRESS_TYPE_CURRES = 'CURRES';
    public static final String ADDRESS_TYPE_PERMNENT = 'PERMNENT';
    public static final String ADDRESS_TYPE_OFFICE = 'OFFICE';
    public static final String TEXT_YES = 'Yes';
    
    public static final String ORIGINAL_USER_UPLOAD = 'Original_User_Upload';
    public static final String JSON_DATA_FOR_PROCESSING = 'JSON_Data_For_Processing';
    public static final String UPLOADED_STATUS = 'Uploaded';
    public static final String PROCESSED_STATUS = 'Processed';
    public static final String JSON_EXTENSION = '.json';
    public static final String SUCCESS_MESSAGE = 'Success';
    public static final String SUCCESS_STATUS_CODE = '0';
    public static final String SUCCESS_CODE_1 = '1';
    public static final String SUCCESS_CODE_4 = '4';
    public static final String SUCCESS_CODE_Y = 'Y';
    public static final String SUCCESS_CODE_E = 'E';
    public static final String SUCCESS_CODE_200 = '200';
    public static final String SUCCESS_CODE_203 = '203';
    public static final String KEY_ID = 'id';
    public static final String KEY_NAME = 'name';
    public static final String KEY_UPLOADED_BY = 'uploadedBy';
    public static final String KEY_UPLOADED_TIME = 'uploadedTime';
    public static final String KEY_STATUS = 'status';
    public static final String YES_VALUE = 'yes';
    
    public static final String PRODUCT_TYPE_INSURANCE = 'INSURANCE';
    public static final String PRODUCT_TYPE_LOAN = 'LOAN';
    public static final String PRODUCT_TYPE_CARD = 'CARD';
    public static final String PRODUCT_TYPE_UBANK = 'Ubank';
    public static final String PRODUCT_NON_EXISTING_CUSTOMER = 'Non-Existing Customer';
    
    public static final String CASE_STATUS_RESOLVED_CANCELLED = 'Resolved-Cancelled';
    public static final String CASE_STATUS_RESOLVED_REJECTED = 'Resolved-Rejected';
    public static final String CASE_STATUS_RESOLVED_COMPLETED = 'Resolved-Completed';
    public static final String CASE_STATUS_AUTO_CANCELLED = 'Resolved-AutoCancelled';
    public static final String CASE_STATUS_AUTO_CLOSED = 'Auto-Closed';
    public static final String INTERACTION_STATUS_CLOSED = 'Closed';
    
    public static final String INTERACTION_VIEW_MODE = 'view';
    public static final String INTERACTION_HANDLING_MODE = 'handling';
    public static final String INTERACTION_REVIEW_MODE = 'review';
    
    public static final String CASE_STATUS_NEW = 'New';
    public static final String CASE_STATUS_OPEN = 'Open';
    public static final String CASE_STATUS_PENDING = 'Pending';
    
    public static final String CASE_WEB_ORIGIN = 'Web';
    
    public static final String GROUP_TYPE_QUEUE = 'Queue';
    public static final String SOBJECT_USER = 'User';
    public static final String SOBJECT_GROUP = 'Group';
    public static final String DELIMITER_SEMICOLON = ';';
    
    public static final String CASE_NON_EXISTING_CUSTOMER = 'Non-Existing';
    public static final String CASE_EXISTING_CUSTOMER = 'Existing';
    
    public static final String CUSTOMER_HISTORY_NON_EXISTING_CUSTOMER = 'Non-existing';
    public static final String CUSTOMER_HISTORY_EXISTING_CUSTOMER = 'Existing';
    
    public static final String MASKING_TYPE_PHONE = 'Mobile/ Phone';
    public static final String MASKING_TYPE_PASSPORT = 'National ID/ Passport';
    
    public static final String FEC_CATEGORY_COMPLAINT = 'Complaint';
    public static final String FEC_COMPLAIN_TYPE_NORMAL = 'Normal';
    public static final String FEC_COMPLAIN_TYPE_URGENT = 'Urgent';
    public static final String FEC_COMPLAIN_TYPE_HIGH_RISK = 'High Risk';
    public static final String FEC_SUB_CATEGORY_CODE_CL01 = 'CL01';
    public static final String FEC_SUB_CATEGORY_CODE_CC01 = 'CC01';
    
    public static final String CUSTOMER_CATEGORY_SUSPECTED_FRAUD = 'Suspected Fraud';
    public static final String CUSTOMER_CATEGORY_MEDIA = 'Media';
    public static final String CUSTOMER_CATEGORY_SERIOUS_COMPLAINT = 'Serious Complaint';
    public static final String CUSTOMER_CATEGORY_UNHAPPY = 'Unhappy';
    public static final String CUSTOMER_CATEGORY_VIP = 'VIP';
    public static final String CUSTOMER_CATEGORY_NEUTRAL = 'Neutral';
    
    public static final String SECTION_INTERACTION_DETAILS = 'Interaction Details';
    public static final String SECTION_SEARCH_INFORMARION = 'Search Information';
    public static final String SECTION_NATIONAL_PASSPORT = 'National ID/ Passport ID';
    public static final String SECTION_INTERACTION_PHONE = 'Interaction Phone';
    public static final String SECTION_CUSTOMER_INFORMATION = 'Customer Information';
    
    public static final String EMAIL = 'Email';
    public static final String PHONE = 'Phone';
    public static final String PRIMARY_PHONE = 'Primary Phone';
    public static final String SUBCHANNEL_INCOMING_EMAIL = 'Incoming Email';
    public static final String CASE_ORIGIN_EMAIL2CASE = 'Email2Case';
    public static final String OUTCOME_CODE_COMPLETED = 'Hoàn tất/ Đã phản hồi';
    
    public static final String KEY_VALID_CHANNELS_WED = 'WED';
    public static final String KEY_VALID_CHANNELS_MOBILE = 'MOBILE';
    public static final String KEY_VALID_CHANNELS_API = 'API';
    public static final String KEY_VALID_CHANNELS_PORTAL = 'PORTAL';
    public static final String KEY_PRODUCT_TYPE_PRODUCT = 'Product';
    public static final String KEY_PROSPECT = 'Prospect';
    public static final String KEY_CASETYPE = 'CaseType';
    public static final String KEY_CATEGORY = 'Category';
    public static final String KEY_SUBCATEGORY = 'SubCategory';
    public static final String KEY_SUBCODE = 'SubCode';
    public static final String KEY_ERROR = 'Error';

    public static final String API_BLANK_BODY = '{}';

    //Get Next Work
    public static final String CASE_TYPE_DESCRIPTION = 'Get Next Work';
    public static final String CASE_ROUTING_ACTION = 'Route to';
    public static final String CASE_STATUS_RESOLVED_CANNOT_CONTACT_CUSTOMER = 'Resolved-CannotContactCustomer';
    
    public static final String UPLOAD_DOCUMENT = 'UploadDocument';
    public static final String CASE_STATUS_ERROR = 'ERROR';
    
    public static final String SYSTEM_SOURCE_VTIGER   = 'VTiger';
    public static final String SYSTEM_SOURCE_ISALE    = 'iSale';
    public static final String SYSTEM_SOURCE_ICOLLECT = 'iCollect';
    public static final String SYSTEM_SOURCE_WEBSITE  = 'Website';
    public static final String SYSTEM_SOURCE_FEOL     = 'FEOL';
    public static final String SYSTEM_SOURCE_ZALO     = 'Zalo';

    public static final String LANGUAGE_EN = 'EN';
    public static final String LANGUAGE_VN = 'VN';

    // Call api FEC_GetCSMasterDataService
    public static final String KEY_PICKLIST = 'Picklist';
    public static final String KEY_CHECKBOX = 'Checkbox';
    public static final String KEY_DATE = 'Date';
    public static final String KEY_DATETIME = 'DateTime';
    public static final String KEY_NUMBER = 'Number';
    public static final String KEY_TEXT = 'Text';
    public static final String OBJ_ADDITIONAL_INFO = 'FEC_Additional_Info__c';

    public static final String AUTO_METHOD = 'Auto';
}