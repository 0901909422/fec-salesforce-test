public with sharing class FEC_FraudConstantCommon {

	public static final String SET_ENPOINT_FRAUD_HEALTH = 'callout:FECredit_Service/archival/actuator/health';
	public static final String SET_ENPOINT_FRAUD_SERVICE = 'callout:FECredit_Service/fima';
	
	public static final String FRAUD_X_API_KEY = 'RkVDX1NBTEVTRk9SQ0U';
	public static final String CLIENT_ENDPOINT_XF = 'callout:FimaFraudService';
	public static final String FRAUD_CASE_SERVICE_NAME = 'UpdateFraudCaseStatus';
	

	


    public static final String DATETIME_FORMAT_DDMMYYYHHMMSS = 'dd/MM/yyyy HH:mm:ss';
	public static final String INFO_NATION_ID = 'NationalID';
	public static final String INFO_NATION_IDS = 'NationalIDs';
	public static final String INFO_PHONE_NUMBER = 'Phone';
	public static final String INFO_APPLICATION_ID = 'AppID';
	public static final String INFO_UIC = 'UIC';
	public static final String INFO_VIOLATIONTYPE = 'ViolationType';
	public static final String INFO_APPLICATION_IDS = 'AppIDs';
	public static final String INFO_CONTRACT_NUMBER = 'ContractNumbers';
	public static final String INFO_ACCOUNT_NUMBER = 'AccountNumber';
	public static final String TASK_NAME = 'TaskName';
	public static final String KEY_ID                     = 'Id';
	public static final String KEY_TASK_ID                = 'TaskId';
	public static final String KEY_FRAUD_TASK_ID          = 'FraudTaskId';
	public static final String KEY_INVESTIGATION_CONCLUSION = 'InvestigationConclusion';
	public static final String KEY_FRAUD_TASK_URL         = 'FraudTaskUrl';
	public static final String KEY_STATUS                 = 'Status';
	public static final String KEY_DEADLINE               = 'Deadline';
	public static final String KEY_CREATED_DATE           = 'CreatedDate';
	public static final String KEY_LAST_MODIFIED_DATE     = 'LastModifiedDate';
	public static final String KEY_ADDITIONAL_PROPERTY     = 'AdditionalProperty';

	

	public static final String SERVICE_CASE_LINK = '/lightning/n/Service_Fraud_Task_Case_Action?c__caseId=';
	public static final String FRAUD_HANDLING_CASE_DETAIL_PATH = 'integration_fraud_handling_case_detail';
	public static final String SYSTEM_CHANNEL = 'SALESFORE-CSM';
    public static final String DEFAULT_CHANNEL_INTEGRATION_CODE = 'FIMA';
    public static final Integer SUCCESSFULL = 200;
    public static final Integer CLIENT_ERROR = 400;
    public static final Integer NOT_FOUND = 404;
    public static final Integer UNAUTHORIZED = 401;
    public static final Integer FORBIDDEN = 403;
    public static final Integer CONFLICT = 409;
    public static final Integer SERVER_ERROR = 500;    
    public static final Integer UNPROCESSABLE_ENTITY = 522;

    public static final String MIME_PDF  = 'application/pdf';
    public static final String MIME_DOC  = 'application/msword';
    public static final String MIME_DOCX = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    public static final String MIME_XLS  = 'application/vnd.ms-excel';
    public static final String MIME_XLSX = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    public static final String MIME_PNG  = 'image/png';
    public static final String MIME_JPG  = 'image/jpeg';
    public static final String MIME_DEFAULT = 'application/octet-stream';
	public static final String MIME_CONTENT_TYPE  = 'Content-Type';
	public static final String MIME_XML_UTF8  = 'application/xml; charset=UTF-8';
	public static final String MIME_TEXT_UTF8  = 'text/xml;charset=UTF-8';

    public static final String FRAUD_SERVICE_SOAP_ENDPOINT = 'http://cf-webapp-uat02.deltavn.vn:3033/Soap/SCLService.svc';
    
	public class IntegrationFieldType {
		public final String TYPE_FILE     = 'file';
		public final String TYPE_TEXT     = 'text';
		public final String TYPE_STRING   = 'string';
		public final String TYPE_NUMBER   = 'number';
		public final String TYPE_DATE     = 'date';
		public final String TYPE_DATETIME = 'datetime';
		public final String TYPE_BOOLEAN  = 'boolean';
		public final String TYPE_OBJECT   = 'object';
		public final String TYPE_ARRAY    = 'array';
	}
	public class IntegrationMappingField {
		
		// =====================================================
		// Header – User / Channel
		// =====================================================
		public final String SOURCE_HEADER        = 'header';
		public final String SOURCE_DETAILS        = 'details';
		public final String SOURCE_NATURE_OF_CASE_ID        = 'natureOfCaseId';
		public final String SOURCE_CASE_STAGE_ID        = 'caseStageId';
		public final String SOURCE_SCREEN_CASE_ID        = 'screenCaseId';
		public final String SOURCE_MAPPING_ID        = 'mappingId';

		public final String SOURCE_TYPE_USER_TYPE        = 'userType';
		public final String SOURCE_TYPE_CHANNEL          = 'channel';
		public final String SOURCE_TYPE_INT_USER         = 'intUserType';
	
		// =====================================================
		// Header – Product / Service
		// =====================================================
		public final String SOURCE_TYPE_PRODUCT          = 'productLine';
		public final String SOURCE_MASTER_TYPE          = 'Product';
		public final String SOURCE_TYPE_SERVICE_TYPE     = 'serviceType';
	
		// =====================================================
		// Header – Case Classification
		// =====================================================
		public final String SOURCE_TYPE_CASE             = 'CaseType';
		public final String SOURCE_TYPE_CATEGORY         = 'category';
		public final String SOURCE_MASTER_CATEGORY       = 'Category';
		public final String SOURCE_MASTER_SUBCATEGORY    = 'SubCategory';
		public final String SOURCE_MASTER_SUBCODE        = 'SubCode';
		public final String SOURCE_TYPE_SUBCATEGORY      = 'subCategory';
		public final String SOURCE_TYPE_SUBCODE          = 'subCode';
		public final String SOURCE_TYPE_NATURE_OF_CASE   = 'NatureOfCase';
		public final String SOURCE_TYPE_CASE_STAGE       = 'CaseStage';
		public final String SOURCE_TYPE_SCREEN_CASE      = 'ScreenCase';
		public final String SOURCE_TYPE_MAPPING          = 'Mapping';
	
		// =====================================================
		// Detail (row) – Integration Info fields
		// =====================================================
		public final String ROW_PROPERTY                 = 'property';
		public final String ROW_PROPERTY_TYPE            = 'type';
		public final String ROW_CSM_PROPERTY             = 'csmProperty';
		public final String ROW_CSM_PROPERTY_TYPE        = 'csmPropertyType';
		public final String ROW_AUTO_MAPPING             = 'autoMapping';
		public final String ROW_MANDATORY                = 'mandatory';
	}

	
	
	
	
    public class IntegrationField {
        public final String CASEFH = 'FH-';
		public final String CASEBU = 'BU-';
		public final String CASETK = 'TK-';
		public final String CASESFT = 'SFT-';
		public final String CASE_SERVICE = 'S-';
        public final String UIC = 'UIC';
		public final String UIC_VALUE = 'CS';
		public final String RESULTDETAILCODE = 'RESULTDETAILCODE';
		public final String RESULTDETAILCODE_VALUE = 'CUS';
		public final String PHONE_FIELD = 'Phone';
		public final String CONTRACT_NUMBER_FIELD = 'ContractNumbers';
		public final String NATIONS_FIELD = 'NationalIDs';
		public final String NATION_FIELD = 'NationalID';
		public final String ACCOUNT_NUMBER_FIELD = 'AccountNumber';
		public final String CASE_RESULT_INFO = 'CaseResultInfo';		
		public final String ORIGINAL_REQUEST = 'OriginalRequest';
		public final String REQUEST_INFO = 'RequestInfo';
		public final String CREATOR_INFO = 'CreatorInfo';
		public final String CUSTOMER_INFO = 'CustomerInfo';
		public final String ADDITIONAL_INFO = 'AdditionalInfo';
		public final String MESSAGE_TIME = 'messageTime';
		public final String CASEID_FIELD = 'caseID';
		public final String REFERENCE_FIELD = 'referenceID';
		public final String CHANNEL_ID_FIELD = 'channelID';
		public final String PARENT_ID_FIELD = 'parentID';
		public final String CASE_STATUS_FIELD = 'caseStatus';
		public final String INVESTIGATION_CONCLUSION_FIELD = 'investigationConclusion';
		public final String REMARKS_FIELD = 'Remarks';
		public final String CREATEDTIME_FIELD = 'CreatedTime';
		public final String UPDATEDTIME_FIELD = 'UpdatedTime';
		public final String CREATOR_EMAIL_FIELD = 'CreatorEmail';
		public final String ID_FIELD = 'ID';
		public final String VALUE_FIELD = 'Value';
		public final String USER_TYPE_FIELD = 'UserType';
		
		
		
		
		
		
		
    }
	public class IntegrationMappingStatus {
		public final String ALLOCATING = 'Allocating';
		public final String SEC_INVESTIGATING = 'SEC Investigating';
		public final String ALLOCATING_PIC = 'Allocating_PIC';
		public final String ALLOCATING_TL = 'Allocating_TL';
		public final String INVESTIGATING = 'Investigating';
		public final String PENDING = 'Pending';
		public final String REPORTING = 'Reporting';
		public final String REPORTING_HEAD = 'Reporting_Head';
		public final String REPORTING_TL = 'Reporting_TL';
		public final String SE_REVIEWING = 'SE_Reviewing';
		public final String UPDATE_REPORT = 'Update_Report';

		public final String EVALUATING = 'Evaluating';
		public final String RESULTING = 'Resulting';
		public final String REVIEWING_REPORT = 'Reviewing_Report';
		public final String UPDATING = 'Updating';

		public final String INITIAL = 'Initial';
		public final String NEW_STATUS= 'New';
		public final String RE_INITIAL = 'Re-initial';

		public final String END_STATUS = 'End';
		public final String POLICING = 'Policing';
		public final String CANCELED = 'Canceled';
		public final String PRE_CANCEL = 'Pre_Cancel';

		public final String CS_UPDATING = 'CS_Updating';

		public final String FRAUD_INVESTIGATING = 'Fraud Investigating';
		public final String FRAUD_SEC_INVESTIGATING = 'Fraud/SEC Investigating';
		public final String FRAUD_REVIEW = 'Fraud review';

		public final String RESOLVED_COMPLETED = 'Resolved-Completed';
		public final String RESOLVED_CANCEL = 'Resolved-Cancel';
		public final String PROVIDE_INFORMATION = 'Provide Information';
	}

	
}