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

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Addresses_List');

        String endpoint = apiSetting?.FEC_Call_Mock__c
            ? FEC_MockupEndpoint.GET_ADDRESSES_LIST_ENDPOINT_MOCKUP
            : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
        HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);

        if (res.getStatusCode() != 200 || String.isBlank(res.getBody())) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()})
            );
        }

        ResponseWrapper response = parseResponse(res.getBody());

        if (response.Sys != null && response.Sys.Code != 1) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_API_Error, new List<String>{response.Sys.Description})
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
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
        if (String.isBlank(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        if (String.isBlank(cifNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CifNumber'}));
        }

        Set<String> validRequestors = new Set<String>{
            FEC_ConstantCommon.REQUESTOR_APS, FEC_ConstantCommon.REQUESTOR_CRM, FEC_ConstantCommon.REQUESTOR_PORTAL, FEC_ConstantCommon.REQUESTOR_MOBILE_APP
        };
        if (!validRequestors.contains(requestorId)) {
            throw new CalloutException(
                System.Label.FEC_MSG_RequestorID_Null
            );
        }

        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Datetime_Format_Invalid, new List<String>{dateTimeStr})
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
                FEC_ConstantCommon.SOAP_ENV
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
        result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
        result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
        result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
        result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');

        // CIF NUMBER
        result.CIFNumber = FEC_CommonUltils.getXmlValue(responseNode, 'CIFNumber');

        // ADDRESSES
        result.Addresses = new List<AddressInfo>();
        Dom.XmlNode addrNode = responseNode.getChildElement('Addresses', null);
        if (addrNode != null) {
            for (Dom.XmlNode a : addrNode.getChildElements()) {
                AddressInfo ad = new AddressInfo();
                ad.AddressId = FEC_CommonUltils.getXmlValue(a, 'AddressId');
                ad.AddressType = FEC_CommonUltils.getXmlValue(a, 'AddressType');
                ad.NumberStr = FEC_CommonUltils.getXmlValue(a, 'Number');
                ad.Building = FEC_CommonUltils.getXmlValue(a, 'Building');
                ad.Street = FEC_CommonUltils.getXmlValue(a, 'Street');
                ad.Ward = FEC_CommonUltils.getXmlValue(a, 'Ward');
                ad.District = FEC_CommonUltils.getXmlValue(a, 'District');
                ad.City = FEC_CommonUltils.getXmlValue(a, 'City');
                ad.CountryCode = FEC_CommonUltils.getXmlValue(a, 'CountryCode');
                ad.CountryName = FEC_CommonUltils.getXmlValue(a, 'CountryName');
                ad.ZipCode = FEC_CommonUltils.getXmlValue(a, 'ZipCode');
                ad.PropertyStatus = FEC_CommonUltils.getXmlValue(a, 'PropertyStatus');
                ad.Years = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(a, 'Years'));
                ad.Months = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(a, 'Months'));
                result.Addresses.add(ad);
            }
        }

        return result;
    }

}