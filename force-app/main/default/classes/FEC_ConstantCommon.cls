public with sharing class FEC_ConstantCommon {

    public static final String API_CONTENT_TYPE = 'text/xml; charset=utf-8';
    public static final String API_CONTENT_TYPE_JSON = 'application/json';
    public static final String API_CONTENT_TYPE_JSON_UTF8 = 'application/json;charset=UTF-8';
    public static final String API_METHOD_GET = 'GET';
    public static final String API_METHOD_POST = 'POST';
    public static final String API_REQUESTOR_ID = 'SALESFORE-CSM';
    public static final String SOAP_ENV = 'http://schemas.xmlsoap.org/soap/envelope/';

    public static final String HTTP_HEADER_CONTENT_TYPE = 'Content-Type';
    public static final String HTTP_HEADER_ACCEPT = 'Accept';
    public static final Integer HTTP_TIMEOUT_MAX = 120000;
    public static final Integer HTTP_TIMEOUT_DEFAULT = 60000;
    public static final Integer HTTP_STATUS_OK = 200;

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

    public static final String DATETIME_FORMAT_GMT = 'yyyyMMdd\'T\'HHmmss\'.0 GMT\'';
    public static final String STR_DATETIME_FORMAT = 'yyyy-MM-dd\'T\'HH:mm:ss.SSS';
    public static final String STR_DATETIME_FORMAT_Z = 'yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'';
    public static final String STR_DATETIME_FORMAT_XXX = 'yyyy-MM-dd\'T\'HH:mm:ss.SSSXXX';
    public static final String STR_DATETIME_FORMAT_SSSSSS_XXX = 'yyyy-MM-dd\'T\'HH:mm:ss.SSSSSSXXX';
    public static final String DATETIME_FORMAT = 'yyyy-MM-dd\'T\'HH:mm:ss';
    public static final String DATE_FORMAT = 'yyyy-MM-dd';
    public static final String DATE_FORMAT_MMYYYY = 'MM/yyyy';
    public static final String DATE_FORMAT_DDMMYYYY = 'dd/MM/yyyy';
    public static final String DATETIME_FORMAT_OUTPUT = 'dd/MM/yyyy HH:mm:ss';

    public static final String PAYMENT_PREFIX = 'pay_';
    
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
    /** Channel/Subchannel dùng cho Interaction SLA (FEC_InteractionSLAController) */
    public static final String CHANNEL_EMAIL_NAME = 'Email';
    public static final String CHANNEL_EMAIL_INCOMING_SUBCHANNEL_NAME = 'Incoming Email';
    public static final String CHANNEL_EMAIL_OUTGOING_SUBCHANNEL_NAME = 'Outgoing Email';
    public static final String CHANNEL_CHAT_NAME = 'Chat';
    public static final String CHANNEL_F2F_NAME = 'F2F';
    public static final String CHANNEL_F2F_SUBCHANNEL_NAME = 'F2F';
    public static final String CHANNEL_LETTER_NAME = 'Letter';
    public static final String CHANNEL_LETTER_SUBCHANNEL_NAME = 'Letter';
    public static final String CHANNEL_INTERNAL_NAME = 'Internal';
    public static final String CHANNEL_INTERNAL_EMAIL_SUBCHANNEL_NAME = 'Email';
    public static final String SUBCHANNEL_INTERNAL_EMAIL = 'Internal Email';
    public static final String CHANNEL_INTERNAL_TASK_SUBCHANNEL_NAME = 'Task';
    public static final String CHANNEL_EXTERNAL_NAME = 'External';
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
    public static final String MERGE_FIELD_OPEN = '{{{';
    public static final String MERGE_FIELD_CLOSE = '}}}';
    public static final String MERGE_FIELD_NORMALIZE_REPLACEMENT = '{{{$1}}}';
    public static final String PATTERN_MERGE_FIELD = '\\{\\{\\{([^}]+)\\}\\}\\}';
    public static final String PATTERN_TRIPLE_BRACE = '\\{\\{\\{([^}]+)\\}\\}\\}';
    public static final String PATTERN_DOUBLE_BRACE = '\\{\\{([^{}]+)\\}\\}';
    public static final String PATTERN_FLEXIBLE_BRACES = '\\{\\{+([^{}]+)\\}\\}+';

    public static final String PATTERN_CASE_MERGE_FIELD = '\\{\\{Case\\.([^}]+)\\}\\}';
    public static final String PATTERN_USER_MERGE_FIELD = '\\{\\{User\\.([^}]+)\\}\\}';
    public static final String PATTERN_CLEAN_TEXT = '[^a-zA-Z0-9-_]';
    /** Nhận diện "Stage N" trong tên stage Case (dyn LWC FEC_CaseBusinessService). */
    public static final Pattern PAT_STAGE_NAME_WITH_NUMBER = Pattern.compile('(?i)[\\s-]stage ([0-9]+)( -|$)');
    
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
    /** Giá trị RequestorID trong mẫu SOAP/CMS (chữ hoa + gạch ngang). */
    public static final String REQUESTOR_PEGA_CSM_LEGACY = 'PEGA-CSM';
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
    public static final String REQUESTOR_VTIGER_CL = 'VTIGER_CL';
    public static final String REQUESTOR_VTIGER_PL = 'VTIGER_PL';
    public static final String REQUESTOR_VMXVERSION_EMEA = 'E8V8';
    public static final String REQUESTOR_VMXVERSION_EMEA_CARD = 'E8V2';
    public static final String REQUESTOR_VMX_CONTEXT = 'FECVMX';
    public static final String REQUESTOR_LANDING_PAGE = 'FEC_LandingPage';
    public static final String REQUESTOR_ORG_EMEA_CARD = '150';
    
    public static final String ADDRESS_TYPE_CURRES = 'CURRES';
    public static final String ADDRESS_TYPE_PERMNENT = 'PERMNENT';
    /** API trả PERMANENT — khác PERMNENT (mã nguồn CIF). */
    public static final String ADDRESS_TYPE_PERMANENT = 'PERMANENT';
    public static final String ADDRESS_TYPE_OFFICE = 'OFFICE';
    /** FEC_Address_Info__c.FEC_Address_Type__c — giá trị picklist. */
    public static final String SF_ADDRESS_TYPE_PERMANENT = 'Permanent Address';
    public static final String SF_ADDRESS_TYPE_OFFICE = 'Office Address';
    public static final String SF_ADDRESS_TYPE_CURRENT = 'Current Address';
    public static final String TEXT_YES = 'Yes';

    public static final String TEXT_NO = 'No';
    
    public static final String ORIGINAL_USER_UPLOAD = 'Original_User_Upload';
    public static final String JSON_DATA_FOR_PROCESSING = 'JSON_Data_For_Processing';
    // === Customer Additional Data — Status constants ===
    public static final String UPLOADED_STATUS = 'Uploaded';
    public static final String PROCESSED_STATUS = 'Processed';
    public static final String REUPLOADED_STATUS = 'Reuploaded';
    public static final String PROCESSING_STATUS = 'Processing';
    public static final String REPROCESS_STATUS = 'Reprocess';
    public static final String CANCELLED_STATUS = 'Cancelled';
    public static final String FAILURE_STATUS = 'Failure';

    // === Customer Additional Data — Status groups ===
    public static final Set<String> PENDING_STATUSES = new Set<String>{
        UPLOADED_STATUS, REUPLOADED_STATUS, PROCESSING_STATUS, REPROCESS_STATUS, FAILURE_STATUS
    };
    public static final Set<String> PROCESSED_STATUSES = new Set<String>{
        PROCESSED_STATUS, CANCELLED_STATUS
    };
    public static final Set<String> BATCH_QUERY_STATUSES = new Set<String>{
        UPLOADED_STATUS, REUPLOADED_STATUS
    };
    public static final Set<String> DELETABLE_STATUSES = new Set<String>{
        UPLOADED_STATUS, REUPLOADED_STATUS, FAILURE_STATUS
    };

    // === Customer Additional Data — Composite Key ===
    public static final String COMPOSITE_KEY_DELIMITER = '!';

    public static final String JSON_EXTENSION = '.json';
    public static final String SUCCESS_MESSAGE = 'Success';
    public static final String SUCCESS_STATUS_CODE = '0';
    public static final String SUCCESS_CODE_1 = '1';
    public static final String SUCCESS_CODE_4 = '4';
    public static final String SUCCESS_CODE_Y = 'Y';
    public static final String SUCCESS_CODE_E = 'E';
    public static final String SUCCESS_CODE_200 = '200';
    public static final Integer SUCCESS_CODE_200_NUM = 200;
    public static final String SUCCESS_CODE_203 = '203';
    public static final Integer ERROR_CODE_500_NUM = 500;
    public static final String KEY_ID = 'id';
    public static final String KEY_NAME = 'name';
    public static final String KEY_UPLOADED_BY = 'uploadedBy';
    public static final String KEY_UPLOADED_TIME = 'uploadedTime';
    public static final String KEY_STATUS = 'status';
    public static final String YES_VALUE = 'yes';

    public static final String PRODUCT_TYPE_INSURANCE = 'INSURANCE';
    public static final String PRODUCT_TYPE_LOAN = 'LOAN';
    public static final String PRODUCT_TYPE_CARD = 'CARD';
    public static final String PRODUCT_TYPE_UBANK = 'UBank';
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
    /** Prefix cho Status dạng Pending-{Team} / Pending-{Team1}_{Team2} */
    public static final String CASE_STATUS_PENDING_PREFIX = 'Pending-';

    public static final String CASE_WEB_ORIGIN = 'Web';

    public static final String GROUP_TYPE_QUEUE = 'Queue';
    public static final String SOBJECT_USER = 'User';
    public static final String SOBJECT_GROUP = 'Group';
    public static final String DELIMITER_SEMICOLON = ';';
    public static final String DELIMITER_UNDERSCORE = '_';

    // tungnm37 thêm: Assignment constants cho COF/GSR
    public static final String ASSIGNMENT_NAME_CALL = 'Call';
    public static final String ASSIGNMENT_NAME_ROUTING = 'Routing';
    public static final String ASSIGNMENT_TYPE_ROUTING = 'Routing';
    public static final String ASSIGNMENT_STATUS_OPEN = 'Open';

    // tungnm37 thêm: UpdateDisbursementStatus log constants
    public static final String DISB_LOG_CRMID    = 'CRMID=';
    public static final String DISB_LOG_STATUS   = ' DISB_STATUS=';
    public static final String DISB_LOG_RESPONSE = ' Response=';

    public static final String CASE_NON_EXISTING_CUSTOMER = 'Non-Existing';
    public static final String CASE_EXISTING_CUSTOMER = 'Existing';

    public static final String CUSTOMER_HISTORY_NON_EXISTING_CUSTOMER = 'Non-existing';
    public static final String CUSTOMER_HISTORY_EXISTING_CUSTOMER = 'Existing';

    public static final String MASKING_TYPE_PHONE = 'Mobile/ Phone';
    public static final String MASKING_TYPE_PASSPORT = 'National ID/ Passport';

    
    public static final String FEC_CATEGORY_REQUEST = 'Request';
    public static final String FEC_CATEGORY_FEEDBACK = 'Feedback';
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
    public static final String CASE_ORIGIN_EMAIL_FECREDIT = 'Email FECredit';
    public static final String OUTCOME_CODE_COMPLETED = 'Hoàn tất/ Đã phản hồi';
    public static final String CASE_ORIGIN_EMAIL_UBANK = 'Email-Ubank';
    public static final String CASE_ORIGIN_EMAIL_FE ='Email-FE';
    public static final String CASE_ORIGIN_EMAIL_INTERNAL ='Email-Internal';

    
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
    public static final String CASE_TRANSFER_ACTION = 'Transfer';
    public static final String CASE_ESCALATE_ACTION = 'Escalate';
    public static final String CASE_REVERT_ACTION = 'Revert';
    public static final String CASE_REVERTING_CREATOR = 'RevertingCreator';
    public static final String CASE_DECISION_VALUE = 'Cannot Contact Customer';
    public static final String CASE_UPDATE_VALUE = 'Update';
    public static final String CASE_REJECT_ACTION = 'Reject';
    public static final String CASE_RESOLVE_ACTION = 'Resolve';
    public static final String REMARK_TYPE_ASSIGNMENT = 'Assignment';
    public static final String TEAM_VALUE = 'CannotContactCustomer';
    
    /** Giá trị trường FEC_Routing_Action__c khi đổi Owner (Salesforce / trigger). */
    public static final String FEC_ROUTING_ACTION_CHANGE_OWNER = 'Change Owner';
    /** Routing Action History: cộng dồn FEC_Team__c / Pending-{Team1}_{Team2} (cùng luồng Route to). */
    public static final Set<String> ROUTING_ACTIONS_SYNC_CASE_TEAMS = new Set<String>{
        CASE_ROUTING_ACTION,
        FEC_ROUTING_ACTION_CHANGE_OWNER,
        'Revert',
        'Escalate',
        'Transfer',
        'Recall'
    };
    /** Routing Action History: đổi Owner Case (khớp FEC_CaseBusinessService.buildRoutingActionHistoryRecord). */
    public static final String FEC_RAH_DESCRIPTION_CHANGE_OWNER = 'Change Owner';
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
    public static final String REQUEST_EXISTING_USER_TYPE  = 'EXISTING';
    public static final String REQUEST_NON_EXISTING_USER_TYPE  = 'NON-EXISTING';
    public static final String REQUEST_PROSPECT_USER_TYPE  = 'PROSPECT';

    public static final String AUTO_METHOD = 'Auto';

    // Call api FEC_CancelCSCaseService
    public static final String STATUS_CLOSED = 'Closed';
    public static final String STATUS_COMPLETED = 'Completed';
    public static final String STATUS_CANCELLED  = 'Cancelled';
    public static final String CODE_SUCCESS      = '1';
    public static final String CODE_FAILURE      = '3';
    public static final String CODE_SYS_ERROR    = '0';
    public static final String ERROR_PREFIX      = 'Error: ';
    public static final String SUCCESS_MESSAGE_CANCEL_CASE = System.Label.FEC_MSG_CancelCS_Success;
    public static final String PHONE_REGEX_VN    = '^0[0-9]{9}$';
    public static final String PHONE_REGEX_INTL  = '^\\+[0-9]{8,15}$';

    /** Kênh hợp lệ cho API FEC_CancelCSCaseService (SOAP). */
    public static final String CANCEL_CS_CHANNEL_CHAT = 'Chat';
    public static final String CANCEL_CS_CHANNEL_F2F = 'F2F';
    public static final String CANCEL_CS_CHANNEL_LETTER = 'Letter';

    public static final List<String> CANCEL_CS_VALID_CHANNELS_ORDERED = new List<String>{
        CHANNEL_INBOUND_NAME,
        CHANNEL_OUTBOUND_NAME,
        CANCEL_CS_CHANNEL_CHAT,
        EMAIL,
        CANCEL_CS_CHANNEL_F2F,
        CANCEL_CS_CHANNEL_LETTER,
        CHANNEL_EXTERNAL,
        CHANNEL_INTERNAL
    };

    public static final Set<String> CANCEL_CS_VALID_CHANNELS = new Set<String>(CANCEL_CS_VALID_CHANNELS_ORDERED);

    /** Độ dài tối đa field request Cancel CS Case. */
    public static final Integer CANCEL_CS_TRANSACTION_ID_MAX_LEN = 36;
    public static final Integer CANCEL_CS_CASE_ID_MAX_LEN = 15;
    public static final Integer CANCEL_CS_CONTRACT_OR_ACCOUNT_MAX_LEN = 255;
    public static final Integer CANCEL_CS_PHONE_MAX_LEN = 16;

    // Email readonly from addresses
    public static final String EMAIL_READONLY_FROM_FECREDIT = 'dichvukhachhang@fecredit.com.vn';
    public static final String EMAIL_READONLY_FROM_UBANK    = 'dichvukhachhang@ubank.com.vn';
    public static final String EMAIL_UBANK_VN    = 'dichvukhachhang@ubank.vn';

    // Case statuses blocked from sending email
    public static final String CASE_STATUS_CLOSED    = 'Closed';
    public static final String CASE_STATUS_RESOLVED  = 'Resolved';
    public static final String CASE_STATUS_CANCELLED = 'Cancelled';
    public static final String CASE_INTERNAL_REQUEST = 'Internal Request';
    public static final Set<String> SUPPORTED_CHANNELS = new Set<String>{
        'INBOUND',
        'OUTBOUND',
        'CHAT',
        'WEBSITE',
        'FE_MOBILE_APP',
        'EXTERNAL',
        'INTERNAL',
        'ZALO'
    };

    public static final String QUEUE_UBANK_EMAIL_NAME = 'FEC_Ubank_Email';
    public static final String QUEUE_CSM_MAILBOX_NAME = 'FEC_CSM_Mailbox';
    public static final String QUEUE_SUPPORT_MAILBOX_NAME = 'FEC_Support_Mailbox';
    public static final String QUEUE_CARE_MAILBOX_NAME = 'FEC_Care_Mailbox';
    public static final String QUEUE_ECOM_MAILBOX_NAME = 'FEC_Ecom_Mailbox';
    public static final String QUEUE_OFFICE_BASED_MAILBOX_NAME = 'FEC_Office_Based_Mailbox';
    public static final String QUEUE_DAY_2_CHECK_NAME = 'FEC_Day_2_Check';
    public static final String QUEUE_OM_MAILBOX_NAME = 'FEC_OM_Mailbox';
    public static final String QUEUE_QUALITY_CONTROL_MAILBOX_NAME = 'FEC_Quality_Control_Mailbox';
    public static final String QUEUE_DQ_CS_SUPPORT_NAME = 'FEC_DQ_CS_Support';
    public static final String QUEUE_DQ_CS_CUSTOMER_CARE_NAME = 'FEC_DQ_CS_Customer_Care';
    public static final String PRODUCT_TYPE_CARD_CASE = 'Card';
    public static final String PRODUCT_TYPE_LOAN_CASE = 'Loan';
    public static final String PRODUCT_TYPE_INSURANCE_CASE = 'Insurance';
    public static final String TARGET_GROUP_CUSTOMER = 'Customer';
    public static final String NOTIFICATION_SUBJECT = 'Notification';

    public static final String CONTRACT_CLOSURE_EMAIL_CHANNEL_C360 = 'C360';
    public static final String CONTRACT_CLOSURE_EMAIL_CHANNEL_TEMPORARY = 'TEMPORARY';    /** FEC_Address_Info__c.FEC_Address_Type__c — địa chỉ tạm Contract Closure */
    public static final String CONTRACT_CLOSURE_ADDRESS_TYPE_TEMPORARY = 'Temporary Address';

    // Auto Notification - Target Group
    public static final String NOTIFICATION_TARGET_GROUP_INTERNAL = 'Internal User';

    // Auto Notification - Channel names (FEC_Notification_Channel__c.Name)
    public static final String NOTIFICATION_CHANNEL_EMAIL = 'Email';
    public static final String NOTIFICATION_CHANNEL_SF_APP = 'Salesforce App';


    //internalSendToSet
    public static final String EMAIL_SUPPORT_CSM = 'supportcsm@fecredit.com.vn';
    public static final String EMAIL_CS_SUPPORT = 'cssupport@fecredit.com.vn';
    public static final String EMAIL_CUSTOMER_CARE = 'customercare@fecredit.com.vn';
    public static final String EMAIL_E_COM = 'e_com@fecredit.com.vn';
    public static final String EMAIL_F2F = 'F2F@fecredit.com.vn';
    public static final String EMAIL_CS_D2C = 'cs_d2c@fecredit.com.vn';
    public static final String EMAIL_CS_OM = 'CS_OM@fecredit.com.vn';
    public static final String EMAIL_CS_QC_TEAM = 'CS_QC_TEAM@fecredit.com.vn';

    public static final String STATUS_SUCCESS = 'SUCCESS';
    public static final String CASE_STATUS_ON_HOLD = 'On Hold';
    
    public static final Map<String, String> decisionToTeamMap = new Map<String, String>{
      // Nhóm thường (Pending-) -> Bỏ prefix
      'Pending CS' => 'CSInternal',
      'Pending Customer' => 'Customer',
      'Pending Card Ops' => 'CardOpsOutOfSystem',
      'Pending Collections' => 'CollectionsOutOfSystem',
      'Pending Contract Processing' => 'CPOutOfSystem',
      'Pending Credit Assessment' => 'CAOutOfSystem',
      'Pending Direct Sales' => 'DirectSalesOutOfSystem',
      'Pending Telesales' => 'TelesalesOutOfSystem',
      'Pending IT' => 'ITOutOfSystem',
      'Pending Payment' => 'PaymentOutOfSystem',
      'Pending Product' => 'PBDOutOfSystem',
      'Pending RCP&A' => 'RCPAOutOfSystem',
      'Pending Security' => 'SecurityOutOfSystem',
      'Pending Vendor' => 'VendorOutOfSystem',
      // Nhóm đặc biệt (cần map Team và đổi Owner sang Queue)
      'Out Of Process' => 'OutOfProcess',
      'CIC Related' => 'CICRelated',
      'Document Preparation' => 'DocumentPreparation',
      'Task Under Review' => 'TaskUnderReview'
    };
    
    public static final String CASE_ALL_REQUEST = 'All';
    public static final String CASE_ALL_CUSTOMER = 'All';

    //----------HARD CODE VALUE FOR CALL API (Non-production)----------
    public static final String ENVIROMENT_NON_PRODUCTION = 'Non-Production';
    
    /** Profile names */
    public static final String PROFILE_RELEVANT_DEPTS = 'Relevant Depts';

    /** MIME types for file attachments */
    public static final String MIME_OCTET_STREAM = 'application/octet-stream';
    public static final String MIME_PDF = 'application/pdf';
    public static final String MIME_PNG = 'image/png';
    public static final String MIME_JPEG = 'image/jpeg';
    public static final String MIME_EXCEL = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    public static final String MIME_WORD = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

    /** FileType values for ContentVersion */
    public static final String FILE_TYPE_PDF = 'PDF';
    public static final String FILE_TYPE_PNG = 'PNG';
    public static final String FILE_TYPE_JPG = 'JPG';
    public static final String FILE_TYPE_JPEG = 'JPEG';
    public static final String FILE_TYPE_EXCEL_X = 'EXCEL_X';
    public static final String FILE_TYPE_EXCEL = 'EXCEL';
    public static final String FILE_TYPE_WORD_X = 'WORD_X';
    public static final String FILE_TYPE_WORD = 'WORD';

    public static final String SUB_CODE_PROCESS_UPDATE_MOBILE = 'RC09.01';
    public static final String SUB_CODE_PROCESS_UPDATE_ADDRESS = 'RC09.02';

    public static final String TARGET_USER_NOT_FOUND = 'Target User not found';
    public static final String BR_TAG_REGEX = '(?i)<br\\s*/?>';
    public static final String P_TAG_REGEX = '(?i)</p>';
    public static final String HTML_TAG_REGEX = '<[^>]+>';
    public static final String CUSTOM_NOTIFICATION_TYPE_NOT_FOUND = 'CustomNotificationType not found.';
    public static final String NOTIFICATION_SEND_FAILED = 'Notification send failed: ';
    public static final String NO_MATCH = 'No match';
    public static final String SKIP_ITEM = 'Skip item (null/blank)';
    
    //HieuTT74 - Update ngày 25/4/2026 - Assigment Routing Action
    // ================= ACTION =================
    public static final String ACTION_ESCALATE = 'Escalate';
    public static final String ACTION_REJECT = 'Reject';
    public static final String ACTION_RESOLVE = 'Resolve';
    public static final String ACTION_REVERT = 'Revert';
    public static final String ACTION_TRANSFER = 'Transfer';
    public static final String ACTION_ROUTE_TO = 'Route_to';
    public static final String ACTION_ROUTE_TO_DISPLAY = 'Route to';
    public static final String ACTION_UPDATE = 'Update';
    
    // ================= DECISION =================
    public static final String DECISION_USER = 'USER';
    public static final String DECISION_QUEUE = 'QUEUE';
    public static final String DECISION_USER_QUEUE = 'USER_QUEUE';
    
    public static final String DECISION_CANNOT_CONTACT = 'CANNOT_CONTACT';
    
    // ================= ASSIGNMENT STATUS =================
    public static final String ASSIGNMENT_STATUS_COMPLETED = 'Completed';
    public static final String ASSIGNMENT_STATUS_REVERTING_CREATOR = 'RevertingCreator';
    
    // ================= TEAM =================
    public static final String TEAM_CS_SUPPORT = 'CS Support';
    public static final String TEAM_CS_CUSTOMER_CARE = 'CS Customer Care';
    
    // ================= QUEUE NAME =================
    public static final String QUEUE_CS_SUPPORT = 'DQ-CS Support';
    public static final String QUEUE_CS_CUSTOMER_CARE = 'DQ-CS Customer Care';
    
    public static final String QUEUE_HANDLING = 'Handling';
    public static final String QUEUE_CARE_INTERNAL_TASK = 'Care Internal Task';
    
    // ================= BUSINESS PROCESS =================
    public static final String BP_GENERAL_SERVICE = 'General Service Request';
    public static final String BP_COMPLAINT = 'Complaint';
    public static final String BP_FEEDBACK = 'Feedback';
    
    // ================= ROUTE STATUS =================
    public static final String STATUS_CS_BACKOFFICE = 'CSBackOfficeReview';
    public static final String STATUS_OTHER_DEPT = 'OtherDeptReview';
    
    // ================= ROUTING TYPE =================
    public static final String ROUTING_TYPE_ASSIGNMENT = 'Assignment';
    
    // ================= ROUTE ACTION HISTORY =================
    public static final String HISTORY_ACTION_ROUTE_TO = 'Route to';
    
    // ================= UPDATE DECISION KEYS =================
    public static final String DECISION_OUT_OF_PROCESS = 'OUT_OF_PROCESS';
    public static final String DECISION_CIC_RELATED = 'CIC_RELATED';
    public static final String DECISION_DOCUMENT_PREP = 'DOCUMENT_PREP';
    public static final String DECISION_TASK_UNDER_REVIEW = 'TASK_UNDER_REVIEW';
    
    // ================= CASE STATUS =================
    public static final String STATUS_PENDING_CS = 'Pending-CSInternal';
    public static final String STATUS_PENDING_CUSTOMER = 'Pending-Customer';
    public static final String STATUS_PENDING_CARD_OPS = 'Pending-CardOpsOutOfSystem';
    public static final String STATUS_PENDING_COLLECTIONS = 'Pending-CollectionsOutOfSystem';
    public static final String STATUS_PENDING_CP = 'Pending-CPOutOfSystem';
    public static final String STATUS_PENDING_CA = 'Pending-CAOutOfSystem';
    public static final String STATUS_PENDING_DS = 'Pending-DirectSalesOutOfSystem';
    public static final String STATUS_PENDING_TELESALES = 'Pending-TelesalesOutOfSystem';
    public static final String STATUS_PENDING_IT = 'Pending-ITOutOfSystem';
    public static final String STATUS_PENDING_PAYMENT = 'Pending-PaymentOutOfSystem';
    public static final String STATUS_PENDING_PRODUCT = 'Pending-PBDOutOfSystem';
    public static final String STATUS_PENDING_RCPA = 'Pending-RCPAOutOfSystem';
    public static final String STATUS_PENDING_SECURITY = 'Pending-SecurityOutOfSystem';
    public static final String STATUS_PENDING_VENDOR = 'Pending-VendorOutOfSystem';
    
    public static final String STATUS_PENDING_OUT_OF_PROCESS = 'Pending-OutOfProcess';
    public static final String STATUS_PENDING_CIC = 'Pending-CICRelated';
    public static final String STATUS_PENDING_DOCUMENT = 'Pending-DocumentPreparation';
    public static final String STATUS_PENDING_TASK_REVIEW = 'Pending-TaskUnderReview';
    
    
    public static final Map<String, String> CASE_STATUS_MAP = new Map<String, String>{
        'PENDING_CS' => 'Pending-CSInternal',
        'PENDING_CUSTOMER' => 'Pending-Customer',
        'PENDING_CARD_OPS' => 'Pending-CardOpsOutOfSystem',
        'PENDING_COLLECTIONS' => 'Pending-CollectionsOutOfSystem',
        'PENDING_CP' => 'Pending-CPOutOfSystem',
        'PENDING_CA' => 'Pending-CAOutOfSystem',
        'PENDING_DS' => 'Pending-DirectSalesOutOfSystem',
        'PENDING_TELESALES' => 'Pending-TelesalesOutOfSystem',
        'PENDING_IT' => 'Pending-ITOutOfSystem',
        'PENDING_PAYMENT' => 'Pending-PaymentOutOfSystem',
        'PENDING_PRODUCT' => 'Pending-PBDOutOfSystem',
        'PENDING_RCPA' => 'Pending-RCPAOutOfSystem',
        'PENDING_SECURITY' => 'Pending-SecurityOutOfSystem',
        'PENDING_VENDOR' => 'Pending-VendorOutOfSystem',
        
        'OUT_OF_PROCESS' => 'Pending-OutOfProcess',
        'CIC_RELATED' => 'Pending-CICRelated',
        'DOCUMENT_PREP' => 'Pending-DocumentPreparation',
        'TASK_UNDER_REVIEW' => 'Pending-TaskUnderReview'
    };
    
    public static final Map<String, String> TEAM_QUEUE_MAP = new Map<String, String>{
        TEAM_CS_SUPPORT => QUEUE_CS_SUPPORT,
        TEAM_CS_CUSTOMER_CARE => QUEUE_CS_CUSTOMER_CARE
    };
    
    public static final Map<String, String> DECISION_QUEUE_MAP = new Map<String, String>{
        DECISION_OUT_OF_PROCESS => QUEUE_HANDLING,
        DECISION_CIC_RELATED => QUEUE_CARE_INTERNAL_TASK,
        DECISION_DOCUMENT_PREP => QUEUE_CARE_INTERNAL_TASK,
        DECISION_TASK_UNDER_REVIEW => QUEUE_CARE_INTERNAL_TASK
    };
    
    
    //HieuTT74: Update common constant - ngày 28-4-2026
    public static final String CHANNEL_FACEBOOK = 'Facebook';
    public static final String CHANNEL_WEBCHAT = 'Webchat';
    
    public static final String CHANNEL_FACEBOOK_LOWER = 'facebook';
    public static final String CHANNEL_ZALO_LOWER = 'zalo';
    public static final String CHANNEL_WEBCHAT_LOWER = 'webchat';
    
    // ===== KYC =====
    public static final String KYC_METHOD_OTHER = 'Other';
    public static final String KYC_STATUS_NOT_KYC = 'NOT KYC';
    public static final String KYC_STATUS_KYC = 'KYC';
    
    public static final String KYC_RESULT_PASS = 'Pass';
    public static final String KYC_RESULT_FAIL = 'Fail';
    
    
    public static final String DNB_STATUS_ACTIVE = 'Active';
    public static final String DNB_STATUS_INACTIVE = 'Inactive';
    public static final String BOOLEAN_TRUE = 'true';
}