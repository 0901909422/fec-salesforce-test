public with sharing class FEC_ConstantCommon {
    
    public static final String API_CONTENT_TYPE = 'text/xml; charset=utf-8';
    public static final String SOAP_ENV = 'http://schemas.xmlsoap.org/soap/envelope/';

    public static final String STR_DATETIME_FORMAT = 'yyyy-MM-dd\'T\'HH:mm:ss.SSS';

    public static final String CASE_INTERACTION_RECORD_TYPE_DEV_NAME = 'Interaction';
    public static final String CASE_CUSTOMER_RECORD_TYPE_DEV_NAME = 'Customer_Case';

    public static final String CHANNEL_INBOUND_API = 'InboundRinging';
    public static final String CHANNEL_OUTBOUND_API = 'OutboundEstablished';
    public static final String CHANNEL_INBOUND_NAME = 'Inbound';
    public static final String CHANNEL_OUTBOUND_NAME = 'Outbound';

    public static final String PATTERN_PHONE_NUMBER = '^(0\\d{9}|84\\d{9})$';
    public static final String PATTERN_NATIONAL_ID = '^(\\d{9}|\\d{12})$';
    public static final String PATTERN_APPLICATION_ID = '^(\\d{6}|\\d{8}|\\d{9})$';
    public static final String PATTERN_ACCOUNT_NUMBER = '^(\\d{16}|\\d{19})$';
    public static final String PATTERN_CONTRACT_NUMBER = '^(\\d{8}-\\d{6}-\\d{4}|\\d{8}-\\d{7}-\\d{3}|\\d{8}-\\d{7}-\\d{2}|\\d{8}-\\d{7}-\\d{1}|\\d{8}-\\d{7}|\\d{2}-\\d{2}-\\d{2}-\\d{2})$';
    public static final String PATTERN_EMAIL = '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,5}(\\.[A-Za-z]{2,5})?$';
}