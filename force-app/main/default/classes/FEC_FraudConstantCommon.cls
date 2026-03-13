public with sharing class FEC_FraudConstantCommon {


	public static final String LANG_VI      = 'vi';

	public static final String SET_ENPOINT_FRAUD_HEALTH = 'callout:FECredit_Service/archival/actuator/health';
	public static final String SET_ENPOINT_FRAUD_SERVICE = 'callout:FIMA/fima/';
	
	public static final String FRAUD_X_API_KEY = 'RkVDX1NBTEVTRk9SQ0U';
	public static final String CLIENT_ENDPOINT_XF = 'callout:FimaFraudService';
	public static final String FRAUD_CASE_SERVICE_NAME = 'UpdateFraudCaseStatus';
	public static final String FRAUD_CASE_CANCEL_NAME = 'CancelFraudCase';
	public static final String FRAUD_CASE_CREATE_NAME = 'CreateFraudCase';

	public static final String FRAUD_CASE_UPDATE_NAME = 'UpdateFraudCase';
	public static final String FRAUD_CASE_PROCESS_NAME = 'ProcessCase';
	
	
	public static final Integer NUMBER_MAX_LENGTH = 32768;

	
	public static final String CATEGORY_KEY     = 'CATEGORY';
    public static final String SUBCATEGORY_KEY  = 'SUBCATEGORY';
    public static final String SUBCODE_KEY      = 'SUBCODE';

	public static final String FIELD_NAME_VN      = 'nameVN';
	public static final String FIELD_NAME_EN      = 'nameEN';


    public static final String DATETIME_FORMAT_DDMMYYYHHMMSS = 'dd/MM/yyyy HH:mm:ss';
	public static final String INFO_NATION_ID = 'NationalID';
	public static final String INFO_NATION_IDS = 'NationalIDs';
	public static final String INFO_PHONE_NUMBER = 'Phone';
	public static final String INFO_APPLICATION_ID = 'AppID';
	public static final String INFO_UIC = 'UIC';
	public static final String INFO_VIOLATIONTYPE = 'ViolationType';

	public static final String INFO_RESULT_DETAIL_CODE = 'ResultDetailCode';

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

	public static final String KEY_AVAILABLE_VALUE     = 'AvailableValues';	

	

	public static final String SERVICE_CASE_LINK = '/lightning/n/integration_fraud_handling_case_update?c__caseId=';
	public static final String SERVICE_SFT_CASE_LINK = '/lightning/n/Service_Fraud_Task_Case_Action?c__caseId=';
	public static final String FRAUD_HANDLING_CASE_DETAIL_PATH = 'integration_fraud_handling_case_detail';
	public static final String SYSTEM_CHANNEL = 'PEGACSM';
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

    public static final String FRAUD_SERVICE_SOAP_ENDPOINT = 'urn:PegaRULES:SOAP:FraudCase:Services/ISCLService/GetFraudMasterData';

	public static final String FRAUD_SERVICE_SOAP_CREATE_ENDPOINT = 'urn:PegaRULES:SOAP:FraudCase:Services/ISCLService/CreateFraudCase';
	public static final String FRAUD_SERVICE_SOAP_CANCEL_ENDPOINT = 'urn:PegaRULES:SOAP:FraudCase:Services/ISCLService/CancelFraudCase';
	public static final String FRAUD_SERVICE_SOAP_GET_MASTER_ENDPOINT = 'urn:PegaRULES:SOAP:FraudCase:Services/ISCLService/GetFraudMasterData';
	public static final String FRAUD_SERVICE_SOAP_PROCESS_CASE_ENDPOINT = 'urn:PegaRULES:SOAP:FraudCase:Services/ISCLService/ProcessCase';

	public static final String FRAUD_SERVICE_SOAP_NS_SOAP = 'http://schemas.xmlsoap.org/soap/envelope/';
	public static final String FRAUD_SERVICE_SOAP_NS_URN = 'urn:PegaRULES:SOAP:FraudCase:Services';
	
	public static final Integer REQUEST_TIMEOUT = 120000;

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
		public final String TYPE_MULTI    = 'multi';
		public final String TYPE_LIST    = 'list';
		public final String TYPE_PICKLIST    = 'picklist';
	}
	public class IntegrationLabelFieldType {

		public final String LABEL_TYPE_FILE     = 'FILE';
		public final String LABEL_TYPE_TEXT     = 'TEXT';
		public final String LABEL_TYPE_STRING   = 'STRING';
		public final String LABEL_TYPE_NUMBER   = 'NUMBER';
		public final String LABEL_TYPE_DATE     = 'DATE';
		public final String LABEL_TYPE_DATETIME = 'DATETIME';
		public final String LABEL_TYPE_BOOLEAN  = 'BOOLEAN';
		public final String LABEL_TYPE_OBJECT   = 'OBJECT';
		public final String LABEL_TYPE_ARRAY    = 'ARRAY';
		public final String LABEL_TYPE_MULTI    = 'MULTI';
		public final String LABEL_TYPE_LIST     = 'LIST';
		public final String LABEL_TYPE_PICKLIST = 'PICKLIST';

	}
	public class IntegrationPayloadField {
		public final String CHANNEL     = 'Channel';
		public final String CASE_TYPE     = 'CaseType';
		public final String PRODUCT_TYPE   = 'ProductType';
		public final String CATEGORY   = 'Category';
		public final String SUBCATEGORY     = 'SubCategory';
		public final String SUBCODE = 'SubCode';
		public final String USER_TYPE  = 'UserType';
		public final String FRAUD_CASEID   = 'FraudCaseId';
		public final String REMARKS    = 'Remarks';
		public final String SERVICE_CASEID    = 'ServiceCaseId';
		public final String CHANNEL_INTEGRATION_CODE    = 'ChannelIntegrationCode';
		public final String ADDITIONAL_INFO    = 'AdditionalInfo';
		public final String INFO_VALUE     = 'Value';
		public final String INFO_TYPE     = 'Type';
		public final String INFO_ID     = 'ID';
		public final String INFO_REFERENCE_ID     = 'ReferenceID';
		public final String INFO_CASE_ID     = 'CaseID';
		public final String INFO_MANDATORY     = 'Mandatory';	
		
		
	}
	public class IntegrationMappingField {
		
		// =====================================================
		// Header – User / Channel
		// =====================================================
		public final String SOURCE_HEADER        = 'header';
		public final String SOURCE_DETAILS        = 'details';
		public final String SOURCE_DETAIL        = 'detail';
		public final String SOURCE_DATA        = 'data';
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
		public final String SOURCE_CASEID                = 'CaseID';
	
		// =====================================================
		// Detail (row) – Integration Info fields
		// =====================================================
		public final String ROW_PROPERTY                 = 'property';
		public final String ROW_PROPERTY_TYPE            = 'type';
		public final String ROW_CSM_PROPERTY             = 'csmProperty';
		public final String ROW_CSM_PROPERTY_TYPE        = 'csmPropertyType';
		public final String ROW_AUTO_MAPPING             = 'autoMapping';
		public final String ROW_MANDATORY                = 'mandatory';
		
		public final String NODE_RESPONSE                = 'Response';
		public final String NODE_SUCCESS                = 'Success';
		public final String NODE_CASEID                = 'CaseId';
		public final String NODE_MESSAGE                = 'Message';
		public final String NODE_TRUE                = 'true';
		public final String NODE_FALSE                = 'false';
		public final String NODE_SYS                = 'Sys';
		public final String NODE_CODE                = 'Code';
		public final String NODE_DESCRIPTION                = 'Description';
		public final String NODE_LABEL                = 'label';
		public final String NODE_VALUE                = 'value';
		public final String NODE_PARENT_ID                = 'parentId';

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
		public final String MASTER_ADDITONAL_PROPERTIES = 'additionalProperties';
		public final String MASTER_POSORDER = 'posOrder';
		public final String MASTER_SUBCATEGORIES = 'subCategories';
		public final String MASTER_ID = 'id';
		public final String MASTER_NAME = 'name';
		public final String MASTER_SUBCODES = 'subCodes';
		public final String MASTER_AVAILABLE_VALUES = 'availableValues';
		public final String MASTER_MANDATORY = 'mandatory';
		public final String MASTER_TYPE = 'type';		
		public final String MASTER_CATEGORIES = 'categories';

		
    }
	
	 // SEC Investigating
	 public static final String ALLOCATING            = 'Allocating';
	 public static final String ALLOCATING_PIC        = 'Allocating_PIC';
	 public static final String ALLOCATING_TL         = 'Allocating_TL';
	 public static final String INVESTIGATING         = 'Investigating';
	 public static final String PENDING               = 'Pending';
	 public static final String REPORTING             = 'Reporting';
	 public static final String REPORTING_HEAD        = 'Reporting_Head';
	 public static final String REPORTING_TL          = 'Reporting_TL';
	 public static final String SE_REVIEWING          = 'SE_Reviewing';
	 public static final String UPDATE_REPORT         = 'Update_Report';
 
	 public static final String SEC_INVESTIGATING     = 'SEC Investigating';
 
	 // Fraud Investigating
	 public static final String EVALUATING            = 'Evaluating';
	 public static final String RESULTING             = 'Resulting';
	 public static final String REVIEWING_REPORT      = 'Reviewing_Report';
	 public static final String UPDATING              = 'Updating';
 
	 public static final String FRAUD_INVESTIGATING   = 'Fraud Investigating';
 
	 // Mixed
	 public static final String INITIAL               = 'Initial';
	 public static final String NEW_STATUS            = 'New';
	 public static final String RE_INITIAL            = 'Re-initial';
 
	 public static final String FRAUD_SEC_INVESTIGATING = 'Fraud/SEC Investigating';
	 public static final String FRAUD_REVIEW            = 'Fraud review';
 
	 // Final
	 public static final String END_STATUS            = 'End';
	 public static final String POLICING              = 'Policing';
	 public static final String CANCELED              = 'Canceled';
	 public static final String PRE_CANCEL            = 'Pre_Cancel';
 
	 public static final String RESOLVED_COMPLETED    = 'Resolved-Completed';
	 public static final String RESOLVED_CANCEL       = 'Resolved-Cancel';
 
	 // CS
	 public static final String CS_UPDATING            = 'CS_Updating';
	 public static final String PROVIDE_INFORMATION    = 'Provide Information';

	
}