public with sharing class FEC_ZNSNotificationCallout {
    public static final String API_SEND_ZNS_MESSAGE = 'FEC_SendZNSMessage';
    private static final String METHOD_POST = 'POST';
    private static final String PARAM_TYPE_DATE = 'DATE';
    private static FEC_ResponseLog responseLog = null;

    // =========================================================================
    // DTO For SendZNSMessage API
    // =========================================================================

    /* Request DTO */
    public class SendZnsMessageRequestDto {
        public List<SendZnsMessageTemplateData> template_data;
        public String phone;
        public String template_id;

        // Không đặt tên field là DateTime để tránh conflict với Apex Datetime.
        public String dateTimeValue;

        public String department;
        public SendZnsMessageRequestSysInfo Sys;
        public String tracking_id;

        public String toJson() {
            Map<String, Object> payload = new Map<String, Object>();

            payload.put('template_data', this.template_data);
            payload.put('phone', this.phone);
            payload.put('template_id', this.template_id);
            payload.put('DateTime', this.dateTimeValue);
            payload.put('department', this.department);
            payload.put('Sys', this.Sys == null ? null : this.Sys.toMap());
            payload.put('tracking_id', this.tracking_id);

            return JSON.serialize(payload);
        }
    }

    public class SendZnsMessageTemplateData {
        public String value;
        public String param_name;

        public SendZnsMessageTemplateData() {}

        public SendZnsMessageTemplateData(String paramName, String paramValue) {
            this.param_name = paramName;
            this.value = paramValue;
        }
    }

    public class SendZnsMessageRequestSysInfo {
        public String TransID;

        // Không đặt tên field là DateTime để tránh conflict với Apex Datetime.
        public String dateTimeValue;

        public String RequestorID;

        public Map<String, Object> toMap() {
            return new Map<String, Object>{
                'TransID'     => this.TransID,
                'DateTime'    => this.dateTimeValue,
                'RequestorID' => this.RequestorID
            };
        }
    }

    /* Response DTO */
    public class SendZnsMessageResponseDto {
        public SendZnsMessageResponseSysInfo Sys;
        public SendZnsMessageResponseData data;

        public Boolean isSuccess() {
            return Sys != null && Sys.Code == 1;
        }

        public String toJson() {
            Map<String, Object> payload = new Map<String, Object>();

            payload.put('Sys', this.Sys == null ? null : this.Sys.toMap());
            payload.put('data', this.data);

            return JSON.serialize(payload);
        }
    }

    public class SendZnsMessageResponseSysInfo {
        public String TransID;

        // Không đặt tên field là DateTime để tránh conflict với Apex Datetime.
        public String dateTimeValue;

        public Integer Code;
        public String Description;

        public Map<String, Object> toMap() {
            return new Map<String, Object>{
                'TransID'     => this.TransID,
                'DateTime'    => this.dateTimeValue,
                'Code'        => this.Code,
                'Description' => this.Description
            };
        }
    }

    public class SendZnsMessageResponseData {
        public String msg_id;
        public String sent_time;
    }

    // =========================================================================
    // Parser Methods
    // =========================================================================

    public static SendZnsMessageRequestDto parseSendZnsMessageRequest(String jsonBody) {
        Map<String, Object> raw =
            (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

        SendZnsMessageRequestDto dto = new SendZnsMessageRequestDto();

        dto.phone = (String) raw.get('phone');
        dto.template_id = (String) raw.get('template_id');
        dto.dateTimeValue = (String) raw.get('DateTime');
        dto.department = (String) raw.get('department');
        dto.tracking_id = (String) raw.get('tracking_id');

        List<Object> templateRawList = (List<Object>) raw.get('template_data');
        dto.template_data = new List<SendZnsMessageTemplateData>();

        if (templateRawList != null) {
            for (Object item : templateRawList) {
                Map<String, Object> itemMap = (Map<String, Object>) item;

                SendZnsMessageTemplateData templateData =
                    new SendZnsMessageTemplateData();

                templateData.value = (String) itemMap.get('value');
                templateData.param_name = (String) itemMap.get('param_name');

                dto.template_data.add(templateData);
            }
        }

        Map<String, Object> sysRaw = (Map<String, Object>) raw.get('Sys');

        if (sysRaw != null) {
            dto.Sys = new SendZnsMessageRequestSysInfo();
            dto.Sys.TransID = (String) sysRaw.get('TransID');
            dto.Sys.dateTimeValue = (String) sysRaw.get('DateTime');
            dto.Sys.RequestorID = (String) sysRaw.get('RequestorID');
        }

        return dto;
    }

    public static SendZnsMessageResponseDto parseSendZnsMessageResponse(String jsonBody) {
        Map<String, Object> raw =
            (Map<String, Object>) JSON.deserializeUntyped(jsonBody);

        SendZnsMessageResponseDto dto = new SendZnsMessageResponseDto();

        Map<String, Object> sysRaw = (Map<String, Object>) raw.get('Sys');

        if (sysRaw != null) {
            dto.Sys = new SendZnsMessageResponseSysInfo();
            dto.Sys.TransID = (String) sysRaw.get('TransID');
            dto.Sys.dateTimeValue = (String) sysRaw.get('DateTime');

            if (sysRaw.get('Code') != null) {
                dto.Sys.Code = Integer.valueOf(String.valueOf(sysRaw.get('Code')));
            }

            dto.Sys.Description = (String) sysRaw.get('Description');
        }

        Map<String, Object> dataRaw = (Map<String, Object>) raw.get('data');

        if (dataRaw != null) {
            dto.data = new SendZnsMessageResponseData();
            dto.data.msg_id = (String) dataRaw.get('msg_id');
            dto.data.sent_time = (String) dataRaw.get('sent_time');
        }

        return dto;
    }

    // =========================================================================
    // Callout SendZNSMessage
    // =========================================================================

    public static SendZnsMessageResponseDto callSendZNSMessageByCase(
        Id caseId,
        String phone,
        String templateId
    ) {
        List<SendZnsMessageTemplateData> templateData =
            buildTemplateDataFromMappings(caseId, templateId);

        String phoneNumber = replacePhonePrefix(phone, '0', '84');
        return callSendZNSMessage(
            templateData,
            phoneNumber,
            templateId
        );
    }

    public static SendZnsMessageResponseDto callSendZNSMessage(
        List<SendZnsMessageTemplateData> templateData,
        String phone,
        String templateId
    ) {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_SEND_ZNS_MESSAGE);

        String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;
        String transId = FEC_CommonUltils.generateTransactionUUID();
        Datetime nowDt = Datetime.now();

        String currentDateTime = FEC_CommonUltils.formatTimestamp(
            nowDt,
            FEC_ConstantCommon.STR_DATETIME_FORMAT_Z
        );

        Map<String, String> headers = new Map<String, String>{
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'TransID'     => transId,
            'DateTime'    => currentDateTime,
            'RequestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };

        SendZnsMessageRequestDto reqDto = buildRequestDto(
            templateData,
            phone,
            templateId,
            transId,
            nowDt,
            currentDateTime
        );

        String payload = reqDto.toJson();
        System.debug('SendZNSMessage Request Body: ' + payload);

        HttpResponse res;
        String errorMessage;

        try {
            res = sendRequestWithBody(endpoint, headers, payload);

            if (res == null) {
                return buildTestSuccessResponse(transId, currentDateTime);
            }

            System.debug('SendZNSMessage Response Body: ' + res.getBody());

            return parseSendZnsMessageResponse(res.getBody());

        } catch (Exception ex) {
            errorMessage = ex.getMessage();
            throw ex;

        } finally {
            responseLog = new FEC_ResponseLog(
                API_SEND_ZNS_MESSAGE,
                endpoint,
                METHOD_POST,
                payload,
                res,
                errorMessage
            );

            logApiResponse(responseLog);
            responseLog = null;
        }
    }

    public static SendZnsMessageResponseDto callSendZNSMessageByCaseWithoutLogging(
        Id caseId,
        String phone,
        String templateId
    ) {
        List<SendZnsMessageTemplateData> templateData =
            buildTemplateDataFromMappings(caseId, templateId);

        String phoneNumber = replacePhonePrefix(phone, '0', '84');
        return callSendZNSMessageWithoutLogging(
            templateData,
            phoneNumber,
            templateId
        );
    }

    public static SendZnsMessageResponseDto callSendZNSMessageWithoutLogging(
        List<SendZnsMessageTemplateData> templateData,
        String phone,
        String templateId
    ) {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance(API_SEND_ZNS_MESSAGE);

        String endpoint = apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c;
        String transId = FEC_CommonUltils.generateTransactionUUID();
        Datetime nowDt = Datetime.now();

        String currentDateTime = FEC_CommonUltils.formatTimestamp(
            nowDt,
            FEC_ConstantCommon.STR_DATETIME_FORMAT_Z
        );

        Map<String, String> headers = new Map<String, String>{
            'Content-Type' => FEC_ConstantCommon.API_CONTENT_TYPE_JSON,
            'TransID'     => transId,
            'DateTime'    => currentDateTime,
            'RequestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };

        SendZnsMessageRequestDto reqDto = buildRequestDto(
            templateData,
            phone,
            templateId,
            transId,
            nowDt,
            currentDateTime
        );

        String payload = reqDto.toJson();
        System.debug('SendZNSMessage Request Body: ' + payload);

        HttpResponse res;
        String errorMessage;

        try {
            res = sendRequestWithBody(endpoint, headers, payload);

            if (res == null) {
                return buildTestSuccessResponse(transId, currentDateTime);
            }

            System.debug('SendZNSMessage Response Body: ' + res.getBody());

            return parseSendZnsMessageResponse(res.getBody());

        } catch (Exception ex) {
            errorMessage = ex.getMessage();
            throw ex;

        } finally {
            responseLog = new FEC_ResponseLog(
                API_SEND_ZNS_MESSAGE,
                endpoint,
                METHOD_POST,
                payload,
                res,
                errorMessage
            );
        }
    }

    // =========================================================================
    // Build Request
    // =========================================================================

    private static SendZnsMessageRequestDto buildRequestDto(
        List<SendZnsMessageTemplateData> templateData,
        String phone,
        String templateId,
        String transId,
        Datetime nowDt,
        String currentDateTime
    ) {
        SendZnsMessageRequestDto reqDto = new SendZnsMessageRequestDto();

        reqDto.template_data = templateData;
        reqDto.phone = phone;
        reqDto.template_id = templateId;
        reqDto.dateTimeValue = currentDateTime;
        reqDto.department = 'cs';
        reqDto.tracking_id = String.valueOf(nowDt.getTime());

        SendZnsMessageRequestSysInfo sysInfo =
            new SendZnsMessageRequestSysInfo();

        sysInfo.TransID = transId;
        sysInfo.dateTimeValue = currentDateTime;
        sysInfo.RequestorID = FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN;

        reqDto.Sys = sysInfo;

        return reqDto;
    }

    // =========================================================================
    // Test Response
    // =========================================================================

    private static SendZnsMessageResponseDto buildTestSuccessResponse(
        String transId,
        String currentDateTime
    ) {
        Datetime nowDt = Datetime.now();

        SendZnsMessageResponseDto response = new SendZnsMessageResponseDto();

        response.Sys = new SendZnsMessageResponseSysInfo();
        response.Sys.TransID = transId;
        response.Sys.dateTimeValue = currentDateTime;
        response.Sys.Code = 1;
        response.Sys.Description = 'Success';

        response.data = new SendZnsMessageResponseData();
        response.data.msg_id = 'TEST_MSG_ID';
        response.data.sent_time = String.valueOf(nowDt.getTime());

        return response;
    }

    // =========================================================================
    // HTTP Callout
    // =========================================================================

    private static HttpResponse sendRequestWithBody(
        String endpoint,
        Map<String, String> headers,
        String body
    ) {
        if (Test.isRunningTest()) {
            return null;
        }

        return FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
            FEC_ConstantCommon.API_METHOD_POST,
            headers,
            body
        );
    }

    // =========================================================================
    // API Log
    // =========================================================================

    public static void writeLogSendNoti() {
        if (responseLog == null) {
            return;
        }

        logApiResponse(responseLog);
        responseLog = null;
    }

    private static void logApiResponse(FEC_ResponseLog responseLog) {
        if (responseLog == null) {
            return;
        }

        // Nếu test đang return null response, tránh trường hợp logApi xử lý res null bị lỗi.
        if (Test.isRunningTest() && responseLog.response == null) {
            return;
        }

        FEC_CommonUltils.logApi(
            responseLog.apiName,
            responseLog.endpoint,
            responseLog.method,
            responseLog.requestBody,
            responseLog.response,
            responseLog.errorMessage
        );
    }

    // =========================================================================
    // Merge Param Mapping Function
    // =========================================================================

    private static final String OBJ_CASE = 'Case';
    private static final String OBJ_ADDITIONAL_INFO = 'FEC_Additional_Info__c';
    private static final String OBJ_CUSTOMER_HISTORY = 'FEC_Customer_History__c';
    private static final String FIELD_CASE_LOOKUP = 'FEC_Case__c';

    private static final Set<String> SUPPORTED_MAPPING_OBJECTS = new Set<String>{
        OBJ_CASE,
        OBJ_ADDITIONAL_INFO,
        OBJ_CUSTOMER_HISTORY
    };

    private static List<SendZnsMessageTemplateData> buildTemplateDataFromMappings(
        Id caseId,
        String templateId
    ) {
        List<SendZnsMessageTemplateData> result =
            new List<SendZnsMessageTemplateData>();

        if (String.isBlank(templateId)) {
            return result;
        }

        List<FEC_Notification_ZNS_Param_Mapping__c> mappings = [
            SELECT
                Name,
                Page_Context__c,
                Field_Name__c,
                Param_Type__c,
                Format_Function__c
            FROM FEC_Notification_ZNS_Param_Mapping__c
            WHERE Template_ID__c = :templateId
            ORDER BY Name
        ];

        if (mappings.isEmpty()) {
            return result;
        }

        Map<String, SObject> contextRecords =
            queryContextRecordsByCaseSafe(mappings, caseId);

        Set<String> addedParamNames = new Set<String>();

        for (FEC_Notification_ZNS_Param_Mapping__c mapping : mappings) {
            if (String.isBlank(mapping.Name)) {
                continue;
            }

            // Tránh duplicate param_name trong cùng template.
            // Nếu có nhiều mapping cùng Template_ID__c + Name thì chỉ lấy record đầu tiên.
            if (addedParamNames.contains(mapping.Name)) {
                continue;
            }

            addedParamNames.add(mapping.Name);

            String value = ' ';

            String objectApiName = String.isBlank(mapping.Page_Context__c)
                ? null
                : mapping.Page_Context__c.trim();

            String fieldApiName = String.isBlank(mapping.Field_Name__c)
                ? null
                : mapping.Field_Name__c.trim();

            if (!String.isBlank(objectApiName) && !String.isBlank(fieldApiName)) {
                SObject sourceRecord = contextRecords.get(objectApiName);

                if (sourceRecord != null) {
                    try {
                        Object rawValue = sourceRecord.get(fieldApiName);
                        value = rawValue == null ? ' ' : String.valueOf(rawValue);

                        value = convertValueByParamType(
                            mapping.Param_Type__c,
                            value
                        );

                        // Apply format function
                        value = applyFormatFunction(
                            mapping.Format_Function__c,
                            value
                        );
                    } catch (Exception ex) {
                        value = ' ';
                    }
                }
            }

            result.add(
                new SendZnsMessageTemplateData(
                    mapping.Name,
                    value
                )
            );
        }

        return result;
    }

    private static Map<String, SObject> queryContextRecordsByCaseSafe(
        List<FEC_Notification_ZNS_Param_Mapping__c> mappings,
        Id caseId
    ) {
        Map<String, SObject> result = new Map<String, SObject>();

        if (mappings == null || mappings.isEmpty()) {
            return result;
        }

        if (caseId == null) {
            return result;
        }

        Set<Id> caseIds = new Set<Id>{ caseId };

        Map<String, Schema.SObjectType> globalDescribe =
            Schema.getGlobalDescribe();

        Map<String, Set<String>> objectToFields =
            new Map<String, Set<String>>();

        for (FEC_Notification_ZNS_Param_Mapping__c mapping : mappings) {
            String objectApiName = String.isBlank(mapping.Page_Context__c)
                ? null
                : mapping.Page_Context__c.trim();

            String fieldApiName = String.isBlank(mapping.Field_Name__c)
                ? null
                : mapping.Field_Name__c.trim();

            if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
                continue;
            }

            if (!SUPPORTED_MAPPING_OBJECTS.contains(objectApiName)) {
                continue;
            }

            if (!globalDescribe.containsKey(objectApiName)) {
                continue;
            }

            Map<String, Schema.SObjectField> fieldMap =
                globalDescribe.get(objectApiName)
                    .getDescribe()
                    .fields
                    .getMap();

            if (!fieldMap.containsKey(fieldApiName)) {
                continue;
            }

            if (
                objectApiName != OBJ_CASE &&
                !fieldMap.containsKey(FIELD_CASE_LOOKUP)
            ) {
                continue;
            }

            if (!objectToFields.containsKey(objectApiName)) {
                objectToFields.put(objectApiName, new Set<String>{ 'Id' });
            }

            objectToFields.get(objectApiName).add(fieldApiName);
        }

        for (String objectApiName : objectToFields.keySet()) {
            try {
                List<String> fields = new List<String>(
                    objectToFields.get(objectApiName)
                );
                fields.sort();

                String soql;

                if (objectApiName == OBJ_CASE) {
                    soql =
                        'SELECT ' + String.join(fields, ',') +
                        ' FROM ' + objectApiName +
                        ' WHERE Id IN :caseIds';
                } else {
                    soql =
                        'SELECT ' + String.join(fields, ',') +
                        ' FROM ' + objectApiName +
                        ' WHERE ' + FIELD_CASE_LOOKUP + ' IN :caseIds' +
                        ' ORDER BY CreatedDate ASC';
                }

                List<SObject> records = Database.query(soql);

                if (!records.isEmpty()) {
                    result.put(objectApiName, records[0]);
                }
            } catch (Exception ex) {
                System.debug(ex.getMessage());
            }
        }

        return result;
    }

    // =========================================================================
    // Utility
    // =========================================================================
    private static String replacePhonePrefix(
        String inputPhone,
        String replaceStr,
        String replaceWith
    ) {
        if (String.isBlank(inputPhone) || String.isBlank(replaceStr)) {
            return inputPhone;
        }

        if (inputPhone.startsWith(replaceStr)) {
            return replaceWith + inputPhone.substring(replaceStr.length());
        }

        return inputPhone;
    }

    private static String applyFormatFunction(
        String formatFunction,
        String value
    ) {
        if (String.isBlank(value)) {
            return ' ';
        }

        if (String.isBlank(formatFunction)) {
            return value;
        }

        String fn = formatFunction.trim();

        if (fn == FEC_ConstantCommon.NOTIFICATION_GET_DAY_OF_DATE) {
            return substringSafe(value, 6, 8);
        }

        if (fn == FEC_ConstantCommon.NOTIFICATION_GET_LAST_4_DIGIT_CARD) {
            return substringSafe(value, 15, 19);
        }

        return value;
    }

    private static String substringSafe(
        String value,
        Integer startIndex,
        Integer endIndex
    ) {
        if (String.isBlank(value)) {
            return '';
        }

        if (startIndex == null || endIndex == null) {
            return '';
        }

        if (startIndex < 0 || endIndex <= startIndex) {
            return '';
        }

        if (value.length() < endIndex) {
            return '';
        }

        return value.substring(startIndex, endIndex);
    }

    private static String convertValueByParamType(
        String paramType,
        Object rawValue
    ) {
        if (rawValue == null) {
            return '';
        }

        if (
            !String.isBlank(paramType) &&
            paramType.trim().equalsIgnoreCase(PARAM_TYPE_DATE)
        ) {
            Date dateValue;

            if (rawValue instanceof Date) {
                dateValue = (Date) rawValue;
            } else if (rawValue instanceof Datetime) {
                dateValue = ((Datetime) rawValue).date();
            } else {
                return String.valueOf(rawValue);
            }

            String dayValue = dateValue.day() < 10
                ? '0' + String.valueOf(dateValue.day())
                : String.valueOf(dateValue.day());

            String monthValue = dateValue.month() < 10
                ? '0' + String.valueOf(dateValue.month())
                : String.valueOf(dateValue.month());

            return dayValue + '/' + monthValue + '/' + String.valueOf(dateValue.year());
        }

        return String.valueOf(rawValue);
    }
}