/****************************************************************************************
* File Name    : FEC_GetDocumentsList
* Author       : Quangdv7
* Date         : 2026-01-17
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-01-17    Quangdv7             Create
 
****************************************************************************************/
public with sharing class FEC_GetDocumentsList {
 
    // =========================================================================
    // RESPONSE MODELS
    // =========================================================================
    public class ResponseWrapper {
        public SysResponse Sys;
        public String CIFNumber;
        public List<DocumentInfo> Documents;
    }
 
    public class SysResponse {
        public String TransID;
        public String DateTimeStr;
        public Integer Code;
        public String Description;
    }
 
    public class DocumentInfo {
        public String DocumentID;
        public String DocumentType;
        public Date IssueDate;
        public String IDDocumentNumber;
        public String IssuePlace;
        public String OmnidocsLink;
    }
 
    // =========================================================================
    // PUBLIC METHOD
    // =========================================================================
    public static ResponseWrapper callGetDocumentsList(
        String transId,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
 
        try {
 
            validateRequest(transId, requestorId, dateTimeStr, cifNumber);
            
            String soapBody = buildSoapRequest(
                transId,
                requestorId,
                dateTimeStr,
                cifNumber
            );
 
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Documents_List');
 
            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_DOCUMENTS_LIST_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
 
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
 
        } catch (Exception ex) {
            System.debug('### GET DOCUMENTS LIST ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    // =========================================================================
    // BUILD SOAP REQUEST
    // =========================================================================
    private static String buildSoapRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
        Dom.Document doc = new Dom.Document();

        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            FEC_ConstantCommon.SOAP_ENV,
            null
        );

        envelope.setAttribute('xmlns:cif', 'http://fecredit.com.vn/CIF_CustomerInfo');

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode getDocs =
            body.addChildElement(
                'cif:GetDocumentsList',
                null,
                null
            );

        Dom.XmlNode sys =
            getDocs.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null)
           .addTextNode(transId);
        sys.addChildElement('RequestorID', null, null)
           .addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null)
           .addTextNode(dateTimeStr);

        getDocs.addChildElement('CIFNumber', null, null)
               .addTextNode(cifNumber);

        return doc.toXmlString();
    }
 
    // =========================================================================
    // REQUEST VALIDATION
    // =========================================================================
    private static void validateRequest(
        String transId,
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
 
        // ===================== TRANSID =====================
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
        
        // ===================== REQUESTORID =====================
        Set<String> validRequestorIds = new Set<String>{ FEC_ConstantCommon.REQUESTOR_APS, FEC_ConstantCommon.REQUESTOR_CRM, FEC_ConstantCommon.REQUESTOR_PORTAL };
        if (String.isBlank(requestorId)
            || !validRequestorIds.contains(requestorId)) {
 
            throw new CalloutException(
                System.Label.FEC_MSG_RequestorID_Null
            );
        }
 
        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Datetime_Format_Invalid, new List<String>{dateTimeStr})
            );
        }
 
        // ===================== CIF NUMBER =====================
        if (String.isBlank(cifNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CifNumber'}));
        }
        if (cifNumber.length() > 255) {
            throw new CalloutException(
                String.format(System.Label.FEC_MSG_Param_Maxlength, new List<String>{'CifNumber', '255'})
            );
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
                FEC_ConstantCommon.SOAP_ENV
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
            result.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
            result.Sys.DateTimeStr = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
            result.Sys.Code = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(sysNode, 'Code'));
            result.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
        }
 
        // ================= CIF NUMBER =================
        result.CIFNumber = FEC_CommonUltils.getXmlValue(responseNode, 'CIFNumber');
 
        // ================= DOCUMENTS =================
        result.Documents = new List<DocumentInfo>();
 
        Dom.XmlNode documentsNode =
            responseNode.getChildElement('Documents', null);
 
        if (documentsNode != null) {
            for (Dom.XmlNode dNode : documentsNode.getChildElements()) {
                if (dNode.getName() == 'Document') {
                    DocumentInfo d = new DocumentInfo();
                    d.DocumentID = FEC_CommonUltils.getXmlValue(dNode, 'DocumentID');
                    d.DocumentType = FEC_CommonUltils.getXmlValue(dNode, 'DocumentType');
                    d.IssueDate = FEC_CommonUltils.toDate(FEC_CommonUltils.getXmlValue(dNode, 'IssueDate'));
                    d.IDDocumentNumber = FEC_CommonUltils.getXmlValue(dNode, 'IDDocumentNumber');
                    d.IssuePlace = FEC_CommonUltils.getXmlValue(dNode, 'IssuePlace');
                    d.OmnidocsLink = FEC_CommonUltils.getXmlValue(dNode, 'OmnidocsLink');
                    result.Documents.add(d);
                }
            }
        }
 
        return result;
    }
 
}