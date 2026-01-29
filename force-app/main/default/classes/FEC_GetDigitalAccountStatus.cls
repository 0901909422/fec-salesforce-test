/****************************************************************************************
 * File Name    : FEC_GetDigitalAccountStatus
 * Author       : Quangdv7
 * Date         : 2026-01-17
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-01-17    Quangdv7             Create
 
****************************************************************************************/
public with sharing class FEC_GetDigitalAccountStatus {

    /* =====================================================
       CONSTANTS
       ===================================================== */
    private static final String ENDPOINT = '/DigitalChannelWS';
    private static final String MOCKUP_ENDPOINT =
        'https://87eaeec6-b7ab-4552-997b-6aa7b7e55628.mock.pstmn.io';

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public List<DigitalAccountInfo> DigitalAccounts;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class DigitalAccountInfo {
        public String Type;
        public String Status;
    }

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetDigitalAccountStatus(
        String transId,
        String requestorId,
        String dateTimeStr,
        String phone,
        String cifNumber
    ) {

        try {

            validateRequest(
                transId,
                requestorId,
                dateTimeStr,
                phone,
                cifNumber
            );

            FEC_API_Setting__c apiSetting =
                FEC_API_Setting__c.getOrgDefaults();

            HttpRequest req = new HttpRequest();
            req.setEndpoint(
                apiSetting?.FEC_Call_Mock__c
                    ? MOCKUP_ENDPOINT
                    : (apiSetting?.FEC_Endpoint__c + ENDPOINT)
            );
            req.setMethod('POST');
            req.setTimeout(120000);

            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader(
                'SOAPAction',
                'http://fecredit.com.vn/DigitalChannelWS/GetDigitalAccountStatus'
            );

            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:dig="http://fecredit.com.vn/DigitalChannelWS">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<dig:GetDigitalAccountStatus>' +
                            '<Sys>' +
                                '<TransID>' + transId + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</Sys>' +
                            '<Phone>' + phone + '</Phone>' +
                            '<CIFNumber>' + cifNumber + '</CIFNumber>' +
                        '</dig:GetDigitalAccountStatus>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            req.setBody(soapBody);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    'GetDigitalAccountStatus service returned HTTP error: ' +
                    res.getStatusCode()
                );
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys == null || response.Sys.Code != 1) {
                throw new CalloutException(
                    response.Sys != null
                        ? response.Sys.Description
                        : 'GetDigitalAccountStatus service returned error'
                );
            }

            return response;

        } catch (Exception ex) {
            System.debug(
                '### GET DIGITAL ACCOUNT STATUS ERROR: ' + ex.getMessage()
            );
            throw ex;
        }
    }

    // =========================================================================
    // REQUEST VALIDATION (GIỮ ĐÚNG STYLE CLASS MẪU)
    // =========================================================================
    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String phone,
        String cifNumber
    ) {

        // ===================== TRANSID =====================
        if (String.isBlank(transId)) {
            throw new CalloutException('TransID is null or invalid');
        }
        if (transId.length() > 36) {
            throw new CalloutException(
                'TransID is null or invalid or no longer than 36 characters'
            );
        }

        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds =
            new Set<String>{ 'APS', 'CRM', 'PORTAL', 'PEGA' };

        if (String.isBlank(requestorId)
            || !validRequestorIds.contains(requestorId)) {

            throw new CalloutException(
                'RequestorID is null or invalid, "' +
                requestorId +
                '" is not type of RequestorID'
            );
        }

        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException('DateTime is null or invalid');
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                'DateTime is null or invalid, "' +
                dateTimeStr +
                '" is not type of Datetime'
            );
        }

        // ===================== PHONE =====================
        if (String.isBlank(phone)) {
            throw new CalloutException('Phone is null or invalid');
        }
        if (String.isNotBlank(phone) &&
            !Pattern.matches('^(0\\d{9}|84\\d{9})$', phone)) {

            throw new CalloutException(
                'Phone number must start with 0 (10 digits) or 84 (11 digits)'
            );
        }

        // ===================== CIF NUMBER =====================
        if (String.isBlank(cifNumber)) {
            throw new CalloutException('CIFNumber is null or invalid');
        }
        if (cifNumber.length() > 255) {
            throw new CalloutException(
                'CIFNumber is null or invalid or no longer than 255 characters'
            );
        }

        Boolean cifExists = true;
        if (!cifExists) {
            throw new CalloutException('CIFNumber is null or invalid');
        }
    }

    // =========================================================================
    // SOAP RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode envelope = doc.getRootElement();
        Dom.XmlNode bodyNode =
            envelope.getChildElement(
                'Body',
                'http://schemas.xmlsoap.org/soap/envelope/'
            );

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // ================= SYS =================
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
        if (sysNode != null) {
            result.Sys = new SysResponse();
            result.Sys.TransID = getVal(sysNode, 'TransID');
            result.Sys.DateTimeStr = getVal(sysNode, 'DateTime');
            result.Sys.Code = toInteger(getVal(sysNode, 'Code'));
            result.Sys.Description = getVal(sysNode, 'Description');
        }

        // ================= DIGITAL ACCOUNTS =================
        result.DigitalAccounts = new List<DigitalAccountInfo>();

        Dom.XmlNode accountStatusNode =
            responseNode.getChildElement('AccountStatus', null);

        if (accountStatusNode != null) {
            for (Dom.XmlNode dNode : accountStatusNode.getChildElements()) {
                if (dNode.getName() == 'DigitalAccount') {
                    DigitalAccountInfo d = new DigitalAccountInfo();
                    d.Type = getVal(dNode, 'Type');
                    d.Status = getVal(dNode, 'Status');
                    result.DigitalAccounts.add(d);
                }
            }
        }

        return result;
    }

    // =========================================================================
    // HELPERS
    // =========================================================================
    private static String getVal(Dom.XmlNode node, String name) {
        if (node == null) return null;
        Dom.XmlNode c = node.getChildElement(name, null);
        return c == null ? null : c.getText();
    }

    private static Integer toInteger(String v) {
        return String.isBlank(v) ? null : Integer.valueOf(v);
    }
}