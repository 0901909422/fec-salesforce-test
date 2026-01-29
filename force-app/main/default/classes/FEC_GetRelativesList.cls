/****************************************************************************************
 * File Name    : FEC_GetRelativesList
 * Author       : Quangdv7
 * Date         : 2026-01-10
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-01-10    Quangdv7             Create
 
****************************************************************************************/

public with sharing class FEC_GetRelativesList {

    /* =====================================================
       CONSTANTS
       ===================================================== 
    */
    private static final String ENDPOINT = '/CIF_CustomerInfo';
    private static final String MOCKUP_ENDPOINT = 'https://4fe9b5aa-83ad-47f8-801a-eba4fd18faf3.mock.pstmn.io';

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public String CIFNumber;
        public List<RelativeInfo> Relatives;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class RelativeInfo {
        public String RelationType;
        public String FullName;
        public String PhoneNumber;
        public String NumberStr;
        public String Building;
        public String Street;
        public String Ward;
        public String City;
    }

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetRelativesList(
        String transID,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
        try {

            validateRequest(transID, requestorId, dateTimeStr, cifNumber);

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            HttpRequest req = new HttpRequest();
            req.setEndpoint(apiSetting?.FEC_Call_Mock__c ? MOCKUP_ENDPOINT : (apiSetting?.FEC_Endpoint__c + ENDPOINT));
            req.setMethod('POST');
            req.setTimeout(120000);
            req.setHeader('Content-Type', 'text/xml; charset=utf-8');
            req.setHeader('SOAPAction', 'http://fecredit.com.vn/CIF_CustomerInfo/GetRelativesList');

            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                'xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfo">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<cif:GetRelativesList>' +
                            '<Sys>' +
                                '<TransID>' + transID + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</Sys>' +
                            '<CIFNumber>' + cifNumber + '</CIFNumber>' +
                        '</cif:GetRelativesList>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            req.setBody(soapBody);

            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('### ENDPOINT USED: ' + req.getEndpoint());

            if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
                throw new CalloutException(
                    'GetRelativesList service returned HTTP error: ' + res.getStatusCode()
                );
            }

            ResponseWrapper response = parseResponse(res.getBody());

            if (response.Sys == null || response.Sys.Code != 1) {
                throw new CalloutException(
                    response.Sys != null
                    ? response.Sys.Description
                    : 'GetRelativesList service returned error'
                );
            }

            return response;

        } catch (Exception ex) {
            System.debug('### GET RELATIVES LIST ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // REQUEST VALIDATION
    // =========================================================================
    private static void validateRequest(
        String transID,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
        if (String.isBlank(transID)) {
            throw new CalloutException('TransID is null or invalid');
        }
        if (String.isBlank(requestorId)) {
            throw new CalloutException('RequestorID is null or invalid');
        }
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException('DateTime is null or invalid');
        }
        if (String.isBlank(cifNumber)) {
            throw new CalloutException('CIFNumber is null or invalid');
        }

        if (transID.length() > 36) {
            throw new CalloutException(
                'TransID must not exceed 36 characters'
            );
        }

        Set<String> validRequestorIds = new Set<String>{
            'APS',
            'CRM',
            'PORTAL',
            'MOBILE_APP'
        };
        if (!validRequestorIds.contains(requestorId)) {
            throw new CalloutException(
                'RequestorID is invalid: ' + requestorId
            );
        }

        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                'DateTime is invalid ISO format: ' + dateTimeStr
            );
        }
    }

    // =========================================================================
    // RESPONSE PARSER
    // =========================================================================
    private static ResponseWrapper parseResponse(String xml) {

        Dom.Document doc = new Dom.Document();
        doc.load(xml);

        Dom.XmlNode bodyNode = doc.getRootElement()
            .getChildElement('Body', 'http://schemas.xmlsoap.org/soap/envelope/');

        Dom.XmlNode responseNode;
        for (Dom.XmlNode n : bodyNode.getChildElements()) {
            responseNode = n;
            break;
        }

        ResponseWrapper result = new ResponseWrapper();

        // SYS
        Dom.XmlNode sysNode = responseNode.getChildElement('Sys', null);
        result.Sys = new SysResponse();
        result.Sys.TransID = getVal(sysNode, 'TransID');
        result.Sys.DateTimeStr = getVal(sysNode, 'DateTime');
        result.Sys.Code = toInt(getVal(sysNode, 'Code'));
        result.Sys.Description = getVal(sysNode, 'Description');

        // CIF NUMBER
        result.CIFNumber = getVal(responseNode, 'CIFNumber');

        // RELATIVES
        result.Relatives = new List<RelativeInfo>();
        Dom.XmlNode relativesNode = responseNode.getChildElement('Relatives', null);
        if (relativesNode != null) {
            for (Dom.XmlNode r : relativesNode.getChildElements()) {
                RelativeInfo rel = new RelativeInfo();
                rel.RelationType = getVal(r, 'RelationType');
                rel.FullName = getVal(r, 'FullName');
                rel.PhoneNumber = getVal(r, 'PhoneNumber');
                rel.NumberStr = getVal(r, 'Number');
                rel.Building = getVal(r, 'Building');
                rel.Street = getVal(r, 'Street');
                rel.Ward = getVal(r, 'Ward');
                rel.City = getVal(r, 'City');
                result.Relatives.add(rel);
            }
        }

        return result;
    }

    // =========================================================================
    // HELPERS
    // =========================================================================
    private static String getVal(Dom.XmlNode n, String name) {
        if (n == null) return null;
        Dom.XmlNode c = n.getChildElement(name, null);
        return c == null ? null : c.getText();
    }

    private static Integer toInt(String v) {
        return String.isBlank(v) ? null : Integer.valueOf(v);
    }
}