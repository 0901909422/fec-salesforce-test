/****************************************************************************************
 * File Name    : FEC_GetAddressesList
 * Author       : Quangdv7
 * Date         : 2026-01-21
 * Description  : Get data for API service
 * ===============================================================
 * Ver      Date           Author              Modification
 * ===============================================================
   1.0      2026-01-21    Quangdv7             Create
 
****************************************************************************************/
public with sharing class FEC_GetAddressesList {

    /* =====================================================
       CONSTANTS
       ===================================================== */
    private static final String ENDPOINT = '/CIF_CustomerInfo';
    private static final String MOCKUP_ENDPOINT =
        'https://3541590e-4fb6-48e7-9dba-5a3259e62dc5.mock.pstmn.io';

    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public String CIFNumber;
        public List<AddressInfo> Addresses;
    }

    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }

    public class AddressInfo {
        public String AddressId;
        public String AddressType;
        public String NumberStr;
        public String Building;
        public String Street;
        public String Ward;
        public String District;
        public String City;
        public String CountryCode;
        public String CountryName;
        public String ZipCode;
        public String PropertyStatus;
        public Integer Years;
        public Integer Months;
    }

    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetAddressesList(
        String transID,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {

        validateRequest(transID, requestorId, dateTimeStr, cifNumber);

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();

        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            apiSetting?.FEC_Call_Mock__c
                ? MOCKUP_ENDPOINT
                : apiSetting.FEC_Endpoint__c + ENDPOINT
        );
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader(
            'SOAPAction',
            'http://fecredit.com.vn/CIF_CustomerInfo/GetAddressesList'
        );

        String soapBody =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            'xmlns:cif="http://fecredit.com.vn/CIF_CustomerInfo">' +
                '<soapenv:Header/>' +
                '<soapenv:Body>' +
                    '<cif:GetAddressesList>' +
                        '<Sys>' +
                            '<TransID>' + transID + '</TransID>' +
                            '<RequestorID>' + requestorId + '</RequestorID>' +
                            '<DateTime>' + dateTimeStr + '</DateTime>' +
                        '</Sys>' +
                        '<CIFNumber>' + cifNumber + '</CIFNumber>' +
                    '</cif:GetAddressesList>' +
                '</soapenv:Body>' +
            '</soapenv:Envelope>';

        req.setBody(soapBody);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException(
                'GetAddressesList returned HTTP ' + res.getStatusCode()
            );
        }

        ResponseWrapper response = parseResponse(res.getBody());

        if (response.Sys == null || response.Sys.Code != 1) {
            throw new CalloutException(
                response.Sys != null
                    ? response.Sys.Description
                    : 'GetAddressesList service error'
            );
        }

        return response;
    }

    // =========================================================================
    // REQUEST VALIDATION (reuse pattern)
    // =========================================================================
    private static void validateRequest(
        String transID,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
        if (String.isBlank(transID) || transID.length() > 36) {
            throw new CalloutException('TransID is invalid');
        }
        if (String.isBlank(requestorId)) {
            throw new CalloutException('RequestorID is invalid');
        }
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException('DateTime is invalid');
        }
        if (String.isBlank(cifNumber)) {
            throw new CalloutException('CIFNumber is invalid');
        }

        Set<String> validRequestors = new Set<String>{
            'APS', 'CRM', 'PORTAL', 'MOBILE_APP'
        };
        if (!validRequestors.contains(requestorId)) {
            throw new CalloutException(
                'Invalid RequestorID: ' + requestorId
            );
        }

        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                'DateTime must be ISO-8601 format'
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
            .getChildElement(
                'Body',
                'http://schemas.xmlsoap.org/soap/envelope/'
            );

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

        // ADDRESSES
        result.Addresses = new List<AddressInfo>();
        Dom.XmlNode addrNode = responseNode.getChildElement('Addresses', null);
        if (addrNode != null) {
            for (Dom.XmlNode a : addrNode.getChildElements()) {
                AddressInfo ad = new AddressInfo();
                ad.AddressId = getVal(a, 'AddressId');
                ad.AddressType = getVal(a, 'AddressType');
                ad.NumberStr = getVal(a, 'Number');
                ad.Building = getVal(a, 'Building');
                ad.Street = getVal(a, 'Street');
                ad.Ward = getVal(a, 'Ward');
                ad.District = getVal(a, 'District');
                ad.City = getVal(a, 'City');
                ad.CountryCode = getVal(a, 'CountryCode');
                ad.CountryName = getVal(a, 'CountryName');
                ad.ZipCode = getVal(a, 'ZipCode');
                ad.PropertyStatus = getVal(a, 'PropertyStatus');
                ad.Years = toInt(getVal(a, 'Years'));
                ad.Months = toInt(getVal(a, 'Months'));
                result.Addresses.add(ad);
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