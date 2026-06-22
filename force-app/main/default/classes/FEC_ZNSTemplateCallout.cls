/**
 * FEC_ZNSTemplateCallout
 * Chứa: DTO response, logic gọi 2 API, mapping sang 2 SF object:
 *   ZNSTemp  → FEC_Template__c
 *   ParamMap → FEC_Notification_ZNS_Param_Mapping__c
 *
 * API 1: GET /GetTemplates       → danh sách template
 * API 2: GET /GetTemplateByID    → chi tiết params của từng template
 *
 * Logic xử lý template:
 *   - Sort ASC theo template_id.
 *   - Dedup toàn cục theo template_name.
 *   - Nếu nhiều template cùng template_name, giữ template có template_id cuối cùng/lớn nhất.
 *
 * FIX "System.LimitException: Too many callouts: 101":
 *   - 1 callout cho GetTemplates + N callout GetTemplateByID.
 *   - Chỉ gọi GetTemplateByID đồng bộ cho tối đa MAX_DETAIL_CALLOUTS_PER_RUN.
 *   - Phần template còn lại được xử lý bất đồng bộ qua Queueable.
 *
 * FIX log bug:
 *   - Không khai báo local variable trùng tên static variable.
 *   - Gán đúng vào FEC_ZNSTemplateCallout.responseLogGetTemplates /
 *     FEC_ZNSTemplateCallout.responseLogGetTemplateByID.
 *   - Dùng finally để vẫn ghi log khi method return sớm.
 *   - Clear static log sau khi ghi để tránh reuse log cũ.
 */
public with sharing class FEC_ZNSTemplateCallout {

    public static final String API_GET_TEMPLATES = 'FEC_GetTemplates';
    public static final String API_GET_TEMPLATE_BY_ID = 'FEC_GetTemplateByID';

    public static FEC_ResponseLog responseLogGetTemplates;
    public static FEC_ResponseLog responseLogGetTemplateByID;

    private static final Integer MAX_DETAIL_CALLOUTS_PER_RUN = 90;

    @TestVisible
    private static Boolean suppressQueueableChainingForTest = false;

    @TestVisible
    private static Integer queueableChainSkippedCountForTest = 0;

    // =========================================================================
    // Result wrapper
    // =========================================================================
    public class CalloutResult {
        public List<FEC_Template__c> templates = new List<FEC_Template__c>();
        public List<FEC_Notification_ZNS_Param_Mapping__c> paramMaps =
            new List<FEC_Notification_ZNS_Param_Mapping__c>();

        public Boolean isEmpty() {
            return templates.isEmpty() && paramMaps.isEmpty();
        }
    }

    // =========================================================================
    // DTO – Response từ API GetTemplates
    // =========================================================================
    public class GetTemplatesResponse {
        public SysInfo Sys;
        public List<TemplateItem> templates;
    }

    public class SysInfo {
        public Integer Code;
        public String Description;
    }

    public class TemplateItem implements Comparable {
        public String template_id;
        public String template_name;
        public String template_status;
        public String department;

        public Integer compareTo(Object compareToObject) {
            TemplateItem other = (TemplateItem) compareToObject;

            if (other == null) {
                return -1;
            }

            return FEC_ZNSTemplateCallout.compareTemplateIdAsc(
                this.template_id,
                other.template_id
            );
        }
    }

    // =========================================================================
    // DTO – Response từ API GetTemplateByID
    // =========================================================================
    public class GetTemplateByIDResponse {
        public SysInfo Sys;
        public TemplateDetail result;
        public Integer zalo_code;
        public String zalo_message;
    }

    public class TemplateDetail {
        public String templateId;
        public String templateName;
        public String status;
        public String previewUrl;
        public List<ParamItem> listParams;
        public List<ButtonItem> listButtons;
        public Long timeout;
        public String templateQuality;
        public String templateTag;
        public String price;
        public Boolean applyTemplateQuota;
        public String reason;
        public String price_uid;
        public String price_sdt;
    }

    public class ParamItem {
        public String name;
        public Boolean require;
        public String type;
        public Integer maxLength;
        public Integer minLength;
        public Boolean acceptNull;
    }

    public class ButtonItem {
        public Integer type;
        public String title;
        public String content;
    }

    // =========================================================================
    // Public entry point
    // =========================================================================
    public CalloutResult fetchAndMap() {
        CalloutResult calloutResult = new CalloutResult();

        try {
            List<TemplateItem> templateItems = callGetTemplates();

            if (templateItems == null || templateItems.isEmpty()) {
                return calloutResult;
            }

            // Sort ASC theo template_id, dedup toàn cục theo template_name,
            // giữ template có template_id cuối cùng/lớn nhất cho mỗi template_name.
            templateItems = sortByTemplateIdAscAndKeepLatestByTemplateName(templateItems);

            Integer syncLimit = Math.min(templateItems.size(), MAX_DETAIL_CALLOUTS_PER_RUN);
            List<TemplateItem> remainingItems = new List<TemplateItem>();

            for (Integer i = 0; i < templateItems.size(); i++) {
                TemplateItem tmpl = templateItems[i];

                String tempId = tmpl.template_id;
                String tempName = tmpl.template_name;
                String tempStatus = tmpl.template_status;

                if (i >= syncLimit) {
                    calloutResult.templates.add(
                        mapTemplate(tempId, tempName, tempStatus, '')
                    );
                    remainingItems.add(tmpl);
                    continue;
                }

                String previewUrl = '';
                GetTemplateByIDResponse byIdResp = callGetTemplateById(tempId);

                List<ParamItem> listParams = new List<ParamItem>();

                if (byIdResp?.result != null) {
                    previewUrl = byIdResp.result.previewUrl != null
                        ? byIdResp.result.previewUrl
                        : '';

                    if (byIdResp.result.listParams != null) {
                        listParams = byIdResp.result.listParams;
                    }
                }

                calloutResult.templates.add(
                    mapTemplate(tempId, tempName, tempStatus, previewUrl)
                );

                for (ParamItem param : listParams) {
                    calloutResult.paramMaps.add(
                        mapParamRecord(param, tempId, tempName, tempStatus)
                    );
                }
            }

            if (!remainingItems.isEmpty()) {
                enqueueTemplateDetailQueueable(remainingItems, 0);
            }

            return calloutResult;
        } finally {
            logAndClearApiResponses();
        }
    }

    // =========================================================================
    // Queueable xử lý phần GetTemplateByID còn lại
    // =========================================================================
    public with sharing class ZNSTemplateDetailQueueable implements Queueable, Database.AllowsCallouts {
        private List<TemplateItem> items;
        private Integer startIndex;

        public ZNSTemplateDetailQueueable(List<TemplateItem> items, Integer startIndex) {
            this.items = items == null ? new List<TemplateItem>() : items;
            this.startIndex = startIndex == null ? 0 : startIndex;
        }

        public void execute(QueueableContext ctx) {
            FEC_ZNSTemplateCallout calloutHelper = new FEC_ZNSTemplateCallout();

            try {
                Integer endIndex = Math.min(
                    items.size(),
                    startIndex + MAX_DETAIL_CALLOUTS_PER_RUN
                );

                List<FEC_Notification_ZNS_Param_Mapping__c> paramsToInsert =
                    new List<FEC_Notification_ZNS_Param_Mapping__c>();

                Map<String, String> previewUrlByTempId = new Map<String, String>();

                for (Integer i = startIndex; i < endIndex; i++) {
                    TemplateItem tmpl = items[i];

                    GetTemplateByIDResponse byIdResp =
                        calloutHelper.callGetTemplateById(tmpl.template_id);

                    String previewUrl = '';
                    List<ParamItem> listParams = new List<ParamItem>();

                    if (byIdResp?.result != null) {
                        previewUrl = byIdResp.result.previewUrl != null
                            ? byIdResp.result.previewUrl
                            : '';

                        if (byIdResp.result.listParams != null) {
                            listParams = byIdResp.result.listParams;
                        }
                    }

                    previewUrlByTempId.put(tmpl.template_id, previewUrl);

                    for (ParamItem param : listParams) {
                        paramsToInsert.add(
                            calloutHelper.mapParamRecord(
                                param,
                                tmpl.template_id,
                                tmpl.template_name,
                                tmpl.template_status
                            )
                        );
                    }
                }

                updatePreviewUrls(previewUrlByTempId);
                insertParamMappingsDedup(paramsToInsert);

                if (endIndex < items.size()) {
                    enqueueTemplateDetailQueueable(items, endIndex);
                }
            } finally {
                FEC_ZNSTemplateCallout.logAndClearApiResponses();
            }
        }

        private void updatePreviewUrls(Map<String, String> previewUrlByTempId) {
            if (previewUrlByTempId == null || previewUrlByTempId.isEmpty()) {
                return;
            }

            List<FEC_Template__c> templatesToUpdate = [
                SELECT Id, FEC_Subject_Line__c
                FROM FEC_Template__c
                WHERE FEC_Subject_Line__c IN :previewUrlByTempId.keySet()
                AND FEC_Is_ZNS_Template__c = TRUE
                LIMIT 10000
            ];

            for (FEC_Template__c t : templatesToUpdate) {
                t.FEC_Preview_ZNS_Url__c =
                    previewUrlByTempId.get(t.FEC_Subject_Line__c);
            }

            if (!templatesToUpdate.isEmpty()) {
                update templatesToUpdate;
            }
        }

        private void insertParamMappingsDedup(
            List<FEC_Notification_ZNS_Param_Mapping__c> newParamMaps
        ) {
            if (newParamMaps == null || newParamMaps.isEmpty()) {
                return;
            }

            Set<String> templateIds = new Set<String>();

            for (FEC_Notification_ZNS_Param_Mapping__c p : newParamMaps) {
                if (String.isNotBlank(p.Template_ID__c)) {
                    templateIds.add(p.Template_ID__c);
                }
            }

            Set<String> existingKeys = new Set<String>();

            if (!templateIds.isEmpty()) {
                for (FEC_Notification_ZNS_Param_Mapping__c existing : [
                    SELECT Id, Name, Template_ID__c
                    FROM FEC_Notification_ZNS_Param_Mapping__c
                    WHERE Template_ID__c IN :templateIds
                    LIMIT 10000
                ]) {
                    existingKeys.add(buildKey(existing.Template_ID__c, existing.Name));
                }
            }

            List<FEC_Notification_ZNS_Param_Mapping__c> toInsert =
                new List<FEC_Notification_ZNS_Param_Mapping__c>();

            Set<String> newKeys = new Set<String>();

            for (FEC_Notification_ZNS_Param_Mapping__c p : newParamMaps) {
                String key = buildKey(p.Template_ID__c, p.Name);

                if (
                    String.isBlank(key) ||
                    existingKeys.contains(key) ||
                    newKeys.contains(key)
                ) {
                    continue;
                }

                toInsert.add(p);
                newKeys.add(key);
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
        }

        private String buildKey(String templateId, String name) {
            if (String.isBlank(templateId) || String.isBlank(name)) {
                return null;
            }

            return templateId.trim().toLowerCase() + '|' + name.trim().toLowerCase();
        }
    }

    // =========================================================================
    // HTTP callouts
    // =========================================================================
    private List<TemplateItem> callGetTemplates() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiGetTemplates =
            FEC_API_Config__mdt.getInstance(API_GET_TEMPLATES);

        String endpointSuffix = apiGetTemplates == null
            ? ''
            : String.valueOf(apiGetTemplates.FEC_Endpoint__c);

        String baseEndpoint = apiSetting?.FEC_Call_Mock__c == true
            ? FEC_MockupEndpoint.GET_TEMPLATES
            : String.valueOf(apiSetting?.FEC_Endpoint__c) + endpointSuffix;

        String endpoint = baseEndpoint + '?Department=cs';
        String transId = FEC_CommonUltils.generateTransactionUUID();

        Map<String, String> headers = new Map<String, String>{
            'TransID' => transId,
            'DateTime' => FEC_CommonUltils.formatTimestamp(
                Datetime.now(),
                FEC_ConstantCommon.STR_DATETIME_FORMAT_Z
            ),
            'RequestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };

        HttpResponse res = sendRequest(endpoint, headers);

        FEC_ZNSTemplateCallout.responseLogGetTemplates = new FEC_ResponseLog(
            API_GET_TEMPLATES,
            endpoint,
            FEC_ConstantCommon.API_METHOD_GET,
            FEC_ConstantCommon.API_BLANK_BODY,
            res,
            null
        );

        if (!isSuccess(res)) {
            System.debug(
                '[ZNSTemplateCallout] GetTemplates failed: ' + statusOf(res)
            );
            return null;
        }

        GetTemplatesResponse parsed =
            (GetTemplatesResponse) JSON.deserialize(
                res.getBody(),
                GetTemplatesResponse.class
            );

        if (parsed?.Sys?.Code != 1) {
            System.debug(
                '[ZNSTemplateCallout] GetTemplates business error: ' +
                parsed?.Sys?.Description
            );
            return null;
        }

        return parsed.templates;
    }

    private GetTemplateByIDResponse callGetTemplateById(String templateId) {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiGetTemplateByID =
            FEC_API_Config__mdt.getInstance(API_GET_TEMPLATE_BY_ID);

        String endpointSuffix = apiGetTemplateByID == null
            ? ''
            : String.valueOf(apiGetTemplateByID.FEC_Endpoint__c);

        String baseEndpoint = apiSetting?.FEC_Call_Mock__c == true
            ? FEC_MockupEndpoint.GET_TEMPLATE_BY_ID
            : String.valueOf(apiSetting?.FEC_Endpoint__c) + endpointSuffix;

        String encodedTemplateId =
            EncodingUtil.urlEncode(String.valueOf(templateId), 'UTF-8');

        String endpoint =
            baseEndpoint + '?TemplateID=' + encodedTemplateId + '&Department=cs';

        String transId = FEC_CommonUltils.generateTransactionUUID();

        Map<String, String> headers = new Map<String, String>{
            'TransID' => transId,
            'DateTime' => FEC_CommonUltils.formatTimestamp(
                Datetime.now(),
                FEC_ConstantCommon.STR_DATETIME_FORMAT_Z
            ),
            'RequestorID' => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };

        HttpResponse res = sendRequest(endpoint, headers);

        FEC_ZNSTemplateCallout.responseLogGetTemplateByID = new FEC_ResponseLog(
            API_GET_TEMPLATE_BY_ID,
            endpoint,
            FEC_ConstantCommon.API_METHOD_GET,
            FEC_ConstantCommon.API_BLANK_BODY,
            res,
            null
        );

        if (!isSuccess(res)) {
            System.debug(
                '[ZNSTemplateCallout] GetTemplateByID failed [id=' +
                templateId +
                ']: ' +
                statusOf(res)
            );
            return null;
        }

        GetTemplateByIDResponse parsed =
            (GetTemplateByIDResponse) JSON.deserialize(
                res.getBody(),
                GetTemplateByIDResponse.class
            );

        if (parsed?.zalo_code != 0) {
            System.debug(
                '[ZNSTemplateCallout] GetTemplateByID Zalo error [id=' +
                templateId +
                ']: ' +
                parsed?.zalo_message
            );
            return null;
        }

        return parsed;
    }

    // =========================================================================
    // Mapping DTO → SF Objects
    // =========================================================================
    private FEC_Template__c mapTemplate(
        String tempId,
        String tempName,
        String tempStatus,
        String previewUrl
    ) {
        return new FEC_Template__c(
            Name = tempName,
            FEC_Subject_Line__c = tempId,
            FEC_Template_ZNS_Status__c = tempStatus,
            FEC_Preview_ZNS_Url__c = previewUrl,
            FEC_Is_ZNS_Template__c = true,
            FEC_Active__c = String.isNotBlank(tempStatus) &&
                tempStatus.trim().equalsIgnoreCase('ENABLE')
        );
    }

    private FEC_Notification_ZNS_Param_Mapping__c mapParamRecord(
        ParamItem param,
        String tempId,
        String tempName,
        String tempStatus
    ) {
        return new FEC_Notification_ZNS_Param_Mapping__c(
            Name = param.name,
            Template_ID__c = tempId,
            Accept_Null__c = param.acceptNull,
            Max_Length__c = param.maxLength,
            Min_Length__c = param.minLength,
            Param_Type__c = param.type,
            Require__c = param.require
        );
    }

    // =========================================================================
    // HTTP utility
    // =========================================================================
    private HttpResponse sendRequest(String endpoint, Map<String, String> headers) {
        return FEC_CommonUltils.calloutApiWithHeaders(
            endpoint,
            FEC_ConstantCommon.API_METHOD_GET,
            headers,
            null
        );
    }

    private Boolean isSuccess(HttpResponse res) {
        return res != null && res.getStatusCode() == 200;
    }

    private String statusOf(HttpResponse res) {
        return res == null
            ? 'null response'
            : res.getStatusCode() + ' ' + res.getStatus();
    }

    private static void logAndClearApiResponses() {
        try {
            logApiResponse(FEC_ZNSTemplateCallout.responseLogGetTemplates);
            logApiResponse(FEC_ZNSTemplateCallout.responseLogGetTemplateByID);
        } finally {
            FEC_ZNSTemplateCallout.responseLogGetTemplates = null;
            FEC_ZNSTemplateCallout.responseLogGetTemplateByID = null;
        }
    }

    private static void logApiResponse(FEC_ResponseLog responseLog) {
        if (responseLog == null) {
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
    // Sort + dedup template
    // =========================================================================
    @TestVisible
    private static List<TemplateItem> sortByTemplateIdAscAndKeepLatestByTemplateName(
        List<TemplateItem> templateItems
    ) {
        List<TemplateItem> sortedItems = new List<TemplateItem>();

        if (templateItems == null || templateItems.isEmpty()) {
            return sortedItems;
        }

        sortedItems.addAll(templateItems);
        sortedItems.sort();

        Map<String, TemplateItem> latestTemplateByName = new Map<String, TemplateItem>();

        for (TemplateItem item : sortedItems) {
            if (item == null) {
                continue;
            }

            String templateNameKey = buildTemplateNameKey(item);

            // Vì list đã sort ASC theo template_id, put() sẽ overwrite record cũ.
            // Kết quả cuối cùng là template_id lớn nhất/cuối cùng cho mỗi template_name.
            latestTemplateByName.put(templateNameKey, item);
        }

        List<TemplateItem> latestItems = new List<TemplateItem>();
        latestItems.addAll(latestTemplateByName.values());

        // Sort lại để output cuối cùng vẫn ASC theo template_id.
        latestItems.sort();

        return latestItems;
    }

    private static String buildTemplateNameKey(TemplateItem item) {
        if (item == null) {
            return null;
        }

        // Không gom chung toàn bộ blank template_name để tránh mất data ngoài ý muốn.
        if (String.isBlank(item.template_name)) {
            return 'BLANK_TEMPLATE_NAME|' + String.valueOf(item.template_id);
        }

        return item.template_name.trim().toLowerCase();
    }

    public static Integer compareTemplateIdAsc(String leftTemplateId, String rightTemplateId) {
        if (String.isBlank(leftTemplateId) && String.isBlank(rightTemplateId)) {
            return 0;
        }

        if (String.isBlank(leftTemplateId)) {
            return 1;
        }

        if (String.isBlank(rightTemplateId)) {
            return -1;
        }

        Decimal leftNumber = tryParseDecimal(leftTemplateId);
        Decimal rightNumber = tryParseDecimal(rightTemplateId);

        if (leftNumber != null && rightNumber != null) {
            if (leftNumber == rightNumber) {
                return 0;
            }

            return leftNumber < rightNumber ? -1 : 1;
        }

        String leftText = leftTemplateId.trim().toLowerCase();
        String rightText = rightTemplateId.trim().toLowerCase();

        Integer textCompareResult = leftText.compareTo(rightText);

        if (textCompareResult == 0) {
            return 0;
        }

        return textCompareResult < 0 ? -1 : 1;
    }

    private static Decimal tryParseDecimal(String value) {
        if (String.isBlank(value)) {
            return null;
        }

        try {
            return Decimal.valueOf(value.trim());
        } catch (Exception ex) {
            return null;
        }
    }

    // =========================================================================
    // Queueable enqueue helper
    // =========================================================================
    @TestVisible
    private static void enqueueTemplateDetailQueueable(
        List<TemplateItem> items,
        Integer startIndex
    ) {
        if (Test.isRunningTest() && suppressQueueableChainingForTest) {
            queueableChainSkippedCountForTest++;
            return;
        }

        System.enqueueJob(new ZNSTemplateDetailQueueable(items, startIndex));
    }
}