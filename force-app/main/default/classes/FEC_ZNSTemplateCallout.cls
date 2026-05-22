/**
 * FEC_ZNSTemplateCallout
 * Chứa: DTO response, logic gọi 2 API, mapping sang 2 SF object:
 *   ZNSTemp  → FEC_Template__c
 *   ParamMap → FEC_Notification_ZNS_Param_Mapping__c
 *
 * API 1: GET /GetTemplates       → danh sách template
 * API 2: GET /GetTemplateByID    → chi tiết params của từng template
 */
public with sharing class FEC_ZNSTemplateCallout {

    // ─── Endpoint ────────────────────────────────────────────────────────────
    public static final String API_GET_TEMPLATES = 'FEC_GetTemplates';
    public static final String API_GET_TEMPLATE_BY_ID = 'FEC_GetTemplateByID';
    public static FEC_ResponseLog responseLogGetTemplates;
    public static FEC_ResponseLog responseLogGetTemplateByID;

    // =========================================================================
    // Result wrapper – trả về cả 2 list cho Service
    // =========================================================================
    public class CalloutResult {
        public List<FEC_Template__c>                       templates  = new List<FEC_Template__c>();
        public List<FEC_Notification_ZNS_Param_Mapping__c> paramMaps  = new List<FEC_Notification_ZNS_Param_Mapping__c>();

        public Boolean isEmpty() {
            return templates.isEmpty() && paramMaps.isEmpty();
        }
    }

    // =========================================================================
    // DTO – Response từ API GetTemplates
    // =========================================================================
    public class GetTemplatesResponse {
        public SysInfo            Sys;
        public List<TemplateItem> templates;
    }

    public class SysInfo {
        public Integer Code;
        public String  Description;
    }

    /** Pega class: FECredit-Data-GetTempl-Templates */
    public class TemplateItem {
        public String template_id;      // → FEC_Template__c.Template_ID__c
        public String template_name;    // → FEC_Template__c.Name__c
        public String template_status;  // → FEC_Template__c.Template_Status__c
        public String department;
    }

    // =========================================================================
    // DTO – Response từ API GetTemplateByID
    // =========================================================================
    public class GetTemplateByIDResponse {
        public SysInfo        Sys;
        public TemplateDetail result;
        public Integer        zalo_code;
        public String         zalo_message;
    }

    public class TemplateDetail {
        public String           templateId;
        public String           templateName;
        public String           status;
        public String           previewUrl;
        public List<ParamItem>  listParams;
        public List<ButtonItem> listButtons;
        public Long             timeout;
        public String           templateQuality;
        public String           templateTag;
        public String           price;
        public Boolean          applyTemplateQuota;
        public String           reason;
        public String           price_uid;
        public String           price_sdt;
    }

    /** Pega class: FECredit-Data-TempltsByID-ListParams */
    public class ParamItem {
        public String  name;        //               → Param_Name__c
        public Boolean require;     //               → Require__c
        public String  type;        //               → Param_Type__c
        public Integer maxLength;   //               → Max_Length__c
        public Integer minLength;   //               → Min_Length__c
        public Boolean acceptNull;  //               → Accept_Null__c
    }

    public class ButtonItem {
        public Integer type;
        public String  title;
        public String  content;
    }

    // =========================================================================
    // Public entry point
    // Gọi cả 2 API, map sang 2 object, trả về CalloutResult
    // =========================================================================
    public CalloutResult fetchAndMap() {
        CalloutResult calloutResult = new CalloutResult();

        // ── Bước 1: Lấy danh sách template ───────────────────────────────────
        List<TemplateItem> templateItems = callGetTemplates();

        // Pega Step 1: When @LengthOfPageList > 0, otherwise end
        if (templateItems == null || templateItems.isEmpty()) {
            return calloutResult;
        }

        // ── Bước 2: Vòng lặp từng template (Pega Step 3.0) ───────────────────
        for (TemplateItem tmpl : templateItems) {

            // Pega Step 3.2: Set local params tempid, tempname, template_status
            String tempId     = tmpl.template_id;
            String tempName   = tmpl.template_name;
            String tempStatus = tmpl.template_status;
            String previewUrl = '';

            // Pega Step 3.4: Gọi GetTemplateByID → lấy previewUrl + listParams
            GetTemplateByIDResponse byIdResp = callGetTemplateById(tempId);

            List<ParamItem> listParams = new List<ParamItem>();
            if (byIdResp?.result != null) {
                previewUrl = byIdResp.result.previewUrl != null
                    ? byIdResp.result.previewUrl : '';
                if (byIdResp.result.listParams != null) {
                    listParams = byIdResp.result.listParams;
                }
            }

            // Pega Step 3.1 – 3.3: Map ZNSTemp → FEC_Template__c
            calloutResult.templates.add(
                mapTemplate(tempId, tempName, tempStatus, previewUrl)
            );

            // Pega Step 3.4.0 – 3.4.4: For each param → FEC_Notification_ZNS_Param_Mapping__c
            for (ParamItem param : listParams) {
                calloutResult.paramMaps.add(
                    mapParamRecord(param, tempId, tempName, tempStatus)
                );
            }
        }

        //log api
        logApiResponse(responseLogGetTemplates);
        logApiResponse(responseLogGetTemplateByID);

        return calloutResult;
    }

    // =========================================================================
    // Private: HTTP callouts
    // =========================================================================
    private List<TemplateItem> callGetTemplates() {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiGetTemplates = FEC_API_Config__mdt.getInstance(API_GET_TEMPLATES);

        String baseEndpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_TEMPLATES
            : (apiSetting?.FEC_Endpoint__c + apiGetTemplates?.FEC_Endpoint__c);

        String endpoint = baseEndpoint + '?Department=cs';
        String transId = FEC_CommonUltils.generateTransactionUUID();

        Map<String, String> headers = new Map<String, String>{
            'TransID'      => transId,
            'DateTime'     => FEC_CommonUltils.formatTimestamp(Datetime.now(), FEC_ConstantCommon.STR_DATETIME_FORMAT_Z),
            'RequestorID'  => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };

        HttpResponse res = sendRequest(endpoint, headers);

        FEC_ResponseLog responseLogGetTemplates = new FEC_ResponseLog(
            'FEC_GetTemplates',
            endpoint,
            FEC_ConstantCommon.API_METHOD_GET,
            FEC_ConstantCommon.API_BLANK_BODY,
            res,
            null
        );

        if (!isSuccess(res)) {
            System.debug('[ZNSTemplateCallout] GetTemplates thất bại: ' + statusOf(res));
            return null;
        }

        GetTemplatesResponse parsed = (GetTemplatesResponse) JSON.deserialize(res.getBody(), GetTemplatesResponse.class);

        if (parsed?.Sys?.Code != 1) {
            System.debug('[ZNSTemplateCallout] GetTemplates lỗi business: '+ parsed?.Sys?.Description);
            return null;
        }
        return parsed.templates;
    }

    private GetTemplateByIDResponse callGetTemplateById(String templateId) {
        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiGetTemplateByID = FEC_API_Config__mdt.getInstance(API_GET_TEMPLATE_BY_ID);

        String baseEndpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_TEMPLATE_BY_ID
            : (apiSetting?.FEC_Endpoint__c + apiGetTemplateByID?.FEC_Endpoint__c);

        String endpoint = baseEndpoint + '?TemplateID=' + templateId + '&Department=cs';
        String transId = FEC_CommonUltils.generateTransactionUUID();

        Map<String, String> headers = new Map<String, String>{
            'TransID'      => transId,
            'DateTime'     => FEC_CommonUltils.formatTimestamp(Datetime.now(), FEC_ConstantCommon.STR_DATETIME_FORMAT_Z),
            'RequestorID'  => FEC_ConstantCommon.REQUESTOR_PEGA_CSM_HYPHEN
        };

        HttpResponse res = sendRequest(endpoint, headers);

        FEC_ResponseLog responseLogGetTemplateByID = new FEC_ResponseLog(
            'FEC_GetTemplateByID',
            endpoint,
            FEC_ConstantCommon.API_METHOD_GET,
            FEC_ConstantCommon.API_BLANK_BODY,
            res,
            null
        );

        if (!isSuccess(res)) {
            System.debug('[ZNSTemplateCallout] GetTemplateByID thất bại [id='+ templateId + ']: ' + statusOf(res));
            return null;
        }

        GetTemplateByIDResponse parsed = (GetTemplateByIDResponse)
            JSON.deserialize(res.getBody(), GetTemplateByIDResponse.class);

        if (parsed?.zalo_code != 0) {
            System.debug('[ZNSTemplateCallout] GetTemplateByID lỗi Zalo [id='+ templateId + ']: ' + parsed?.zalo_message);
            return null;
        }
        return parsed;
    }

    // =========================================================================
    // Private: Mapping DTO → SF Objects
    // =========================================================================

    /**
     * Pega Step 3.2: Map ZNSTemp → FEC_Template__c
     *
     * Pega field            Pega property      → SF field
     * ──────────────────────────────────────────────────────────
     * ZNSTemp.pyRuleName  = template_id        → Template_ID__c
     * ZNSTemp.Name        = template_name      → Name__c
     * ZNSTemp.TempStatus  = template_status    → Template_Status__c
     * ZNSTemp.DisplayName = previewUrl         → Display_Name__c
     */
    private FEC_Template__c mapTemplate(
        String tempId,
        String tempName,
        String tempStatus,
        String previewUrl
    ) {
        return new FEC_Template__c(
            Name     = tempName,
            FEC_Subject_Line__c   = tempId,
            FEC_Template_ZNS_Status__c = tempStatus,
            FEC_Preview_ZNS_Url__c    = previewUrl,
            FEC_Is_ZNS_Template__c   = TRUE,
            FEC_Active__c = (tempStatus == 'ENABLE') ? TRUE : FALSE
        );
    }

    /**
     * Pega Step 3.4.4: Map ParamMap → FEC_Notification_ZNS_Param_Mapping__c
     *
     * Pega field                Pega property      → SF field
     * ────────────────────────────────────────────────────────────────────
     * ParamMap.ParamName      = param.name (name2) → Name
     * ParamMap.TemplateID     = tempid             → Template_ID__c
     * ParamMap.AcceptNull     = param.acceptNull   → Accept_Null__c
     * ParamMap.MaxLength      = param.maxLength    → Max_Length__c
     * ParamMap.MinLength      = param.minLength    → Min_Length__c
     * ParamMap.ParamType      = param.type         → Param_Type__c
     * ParamMap.Require        = param.require      → Require__c
     */
    private FEC_Notification_ZNS_Param_Mapping__c mapParamRecord(
        ParamItem param,
        String    tempId,
        String    tempName,
        String    tempStatus
    ) {
        return new FEC_Notification_ZNS_Param_Mapping__c(
            Name      = param.name,
            Template_ID__c     = tempId,
            Accept_Null__c     = param.acceptNull,
            Max_Length__c      = param.maxLength,
            Min_Length__c      = param.minLength,
            Param_Type__c      = param.type,
            Require__c         = param.require
        );
    }

    // =========================================================================
    // Private: HTTP utility
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
        return res == null ? 'null response' : res.getStatusCode() + ' ' + res.getStatus();
    }

    private void logApiResponse(FEC_ResponseLog responseLog) {
    if (responseLog != null) {
      FEC_CommonUltils.logApi(
        responseLog.apiName,
        responseLog.endpoint,
        responseLog.method,
        responseLog.requestBody,
        responseLog.response,
        responseLog.errorMessage
      );
      responseLog = null;
    }
  }
}