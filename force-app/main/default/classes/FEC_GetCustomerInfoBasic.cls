/****************************************************************************************
* File Name    : FEC_GetCustomerInfoBasic
* Author       : Quangdv7
* Date         : 2026-01-07
* Description  : Get data for API service
* ===============================================================
* Ver      Date           Author              Modification
* ===============================================================
   1.0      2026-01-07     Quangdv7             Create
 
****************************************************************************************/
 
public with sharing class FEC_GetCustomerInfoBasic {
 
    private static final String CIF_NS ='http://fecredit.com.vn/CIF_CustomerInfo';
    
    /* =====================================================
       RESPONSE MODELS
       ===================================================== */
 
    public class ResponseWrapper {
        public SysResponse Sys;
        public CustomerBasicInfo CustomerBasicInfo;
    }
 
    public class SysResponse {
        public String TransID;
        public String DateTime_x;
        public String Code;
        public String Description;
    }
 
    public class CustomerBasicInfo {
        public String CIFNumber;
        public String CIFDWH;
        public String FirstName;
        public String MiddleName;
        public String LastName;
        public String FullName;
        public String ShortName;
        public String Title;
        public Date Birthday;
        public String Gender;
        public String Citizenship;
        public String SocialStatus;
        public String MaritalStatus;
        public String CustomerStatus;
        public String CustomerValue;
 
        public List<CurrentAddress> CurrentAddresses;
        public List<PreferredContact> PreferredContacts;
        public List<Relative> Relatives;
        public List<Employer> Employers;
    }
 
    public class CurrentAddress {
        public Address Address;
    }
 
    public class Address {
        public String AddressId;
        public String AddressType;
        public String HouseNumber;
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
 
    public class PreferredContact {
        public Contact Contact;
    }
 
    public class Contact {
        public String ContactId;
        public String Channel;
        public String CommunicationType;
        public String ContactString;
        public String OfficeExtension;
    }
 
    public class Relative {
        public String RelationType;
        public String FullName;
        public String PhoneNumber;
        public String HouseNumber;
        public String Building;
        public String Street;
        public String Ward;
        public String City;
    }
 
    public class Employer {
    }
 
    /* =====================================================
       PUBLIC METHOD
       ===================================================== */
 
    public static ResponseWrapper callGetCustomerInfoBasic(
        String transId,    
        String requestorId,
        String dateTimeStr,
        String cifNumber
    ) {
        try {
 
            // FIX typo duy nhất
            validateRequest(transId, requestorId, dateTimeStr, cifNumber);
 
            String soapBody = buildSoapRequest(
                transId,
                requestorId,
                dateTimeStr,
                cifNumber
            );
 
            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Customer_Info_Basic');
 
            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CUSTOMER_INFO_BASIC_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, FEC_ConstantCommon.API_METHOD_POST, FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
            // ===== LOG REQUEST + RESPONSE =====
            FEC_CommonUltils.logApi(
                'FEC_GetCustomerInfoBasic',
                endpoint,
                'POST',
                soapBody,
                res,
                null
            );
 
            if (res.getStatusCode() != 200) {
                throw new CalloutException(String.format(System.Label.FEC_MSG_HTTP_Error, new List<String>{res.getStatusCode().toString()}));
            }
            if (String.isBlank(res.getBody())) {
                throw new CalloutException(System.Label.FEC_MSG_Response_Null);
            }
 
            return parseResponse(res.getBody());
        }
        catch (Exception ex) {
            System.debug('### GET CUSTOMER INFO BASIC ERROR: ' + ex.getMessage());
            throw ex;
        }
    }

    /* =====================================================
       BUILD SOAP REQUEST
       ===================================================== */

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

        envelope.setAttribute('xmlns:cif', CIF_NS);

        envelope.addChildElement('soapenv:Header', null, null);

        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);

        Dom.XmlNode getInfo =
            body.addChildElement(
                'cif:GetCustomerInfoBasic',
                null,
                null
            );

        Dom.XmlNode sys = getInfo.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transId);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        getInfo
            .addChildElement('CIFNumber', null, null)
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
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(System.Label.FEC_MSG_TransID_Null);
        }
        if (String.isBlank(requestorId)) {
            throw new CalloutException(System.Label.FEC_MSG_RequestorID_Null);
        }
 
        Set<String> validRequestorIds = new Set<String>{ FEC_ConstantCommon.REQUESTOR_CRM,FEC_ConstantCommon.REQUESTOR_PORTAL,FEC_ConstantCommon.REQUESTOR_MOBILE_APP };
        if (!validRequestorIds.contains(requestorId)) {
            throw new CalloutException(
                System.Label.FEC_MSG_RequestorID_Null
            );
        }
 
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
 
        if (String.isBlank(cifNumber)) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Required, new List<String>{'CifNumber'}));
        }
 
        if (!cifNumber.isNumeric()) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Param_Must_Number, new List<String>{'CifNumber'}));
        }
    }
 
 
    /* =====================================================
       RESPONSE PARSER
       ===================================================== */
 
    private static ResponseWrapper parseResponse(String xml) {
 
        Dom.Document doc = new Dom.Document();
        doc.load(xml);
 
        Dom.XmlNode bodyNode =
            doc.getRootElement().getChildElement('Body', FEC_ConstantCommon.SOAP_ENV);
 
        // ===== FIX: ignore namespace for response =====
        Dom.XmlNode responseNode =
            bodyNode.getChildElement('GetCustomerInfoBasicResponse', null);
 
        if (responseNode == null)
            throw new CalloutException(System.Label.FEC_MSG_Response_Null);
 
        ResponseWrapper r = new ResponseWrapper();
 
        /* ===== SYS ===== */
        Dom.XmlNode sysNode =
            responseNode.getChildElement('Sys', null);
 
        if (sysNode == null)
            throw new CalloutException(System.Label.FEC_MSG_Response_Sys_Null);
 
        r.Sys = new SysResponse();
        r.Sys.TransID = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
        r.Sys.DateTime_x = FEC_CommonUltils.getXmlValue(sysNode, 'DateTime');
        r.Sys.Code = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
        r.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');
 
        if (r.Sys.Code != '1')
            throw new CalloutException(String.format(System.Label.FEC_MSG_API_Error, new List<String>{r.Sys.Description}));
 
        /* ===== CUSTOMER ===== */
        Dom.XmlNode c =
            responseNode.getChildElement('CustomerBasicInfo', null);
 
        r.CustomerBasicInfo = new CustomerBasicInfo();
        r.CustomerBasicInfo.CIFNumber = FEC_CommonUltils.getXmlValue(c, 'CIFNumber');
        r.CustomerBasicInfo.CIFDWH = FEC_CommonUltils.getXmlValue(c, 'CIFDWH');
        r.CustomerBasicInfo.FirstName = FEC_CommonUltils.getXmlValue(c, 'FirstName');
        r.CustomerBasicInfo.MiddleName = FEC_CommonUltils.getXmlValue(c, 'MiddleName');
        r.CustomerBasicInfo.LastName = FEC_CommonUltils.getXmlValue(c, 'LastName');
        r.CustomerBasicInfo.FullName = FEC_CommonUltils.getXmlValue(c, 'FullName');
        r.CustomerBasicInfo.ShortName = FEC_CommonUltils.getXmlValue(c, 'ShortName');
        r.CustomerBasicInfo.Title = FEC_CommonUltils.getXmlValue(c, 'Title');
        r.CustomerBasicInfo.Birthday = FEC_CommonUltils.xmlValToDate(c, 'Birthday');
        r.CustomerBasicInfo.Gender = FEC_CommonUltils.getXmlValue(c, 'Gender');
        r.CustomerBasicInfo.Citizenship = FEC_CommonUltils.getXmlValue(c, 'Citizenship');
        r.CustomerBasicInfo.SocialStatus = FEC_CommonUltils.getXmlValue(c, 'SocialStatus');
        r.CustomerBasicInfo.MaritalStatus = FEC_CommonUltils.getXmlValue(c, 'MaritalStatus');
        r.CustomerBasicInfo.CustomerStatus = FEC_CommonUltils.getXmlValue(c, 'CustomerStatus');
        r.CustomerBasicInfo.CustomerValue = FEC_CommonUltils.getXmlValue(c, 'CustomerValue');
 
        r.CustomerBasicInfo.CurrentAddresses = new List<CurrentAddress>();
        Dom.XmlNode currAddrsNode = c.getChildElement('CurrentAddresses', null);
        if (currAddrsNode != null) {
            for (Dom.XmlNode addrNode : currAddrsNode.getChildElements()) {
                if (addrNode.getName() != 'Address') continue;
                CurrentAddress ca = new CurrentAddress();
                ca.Address = new Address();
                ca.Address.AddressId = FEC_CommonUltils.getXmlValue(addrNode, 'AddressId');
                ca.Address.AddressType = FEC_CommonUltils.getXmlValue(addrNode, 'AddressType');
                ca.Address.HouseNumber = FEC_CommonUltils.getXmlValue(addrNode, 'Number');
                ca.Address.Street = FEC_CommonUltils.getXmlValue(addrNode, 'Street');
                ca.Address.Ward = FEC_CommonUltils.getXmlValue(addrNode, 'Ward');
                ca.Address.District = FEC_CommonUltils.getXmlValue(addrNode, 'District');
                ca.Address.City = FEC_CommonUltils.getXmlValue(addrNode, 'City');
                ca.Address.CountryCode = FEC_CommonUltils.getXmlValue(addrNode, 'CountryCode');
                ca.Address.CountryName = FEC_CommonUltils.getXmlValue(addrNode, 'CountryName');
                ca.Address.ZipCode = FEC_CommonUltils.getXmlValue(addrNode, 'ZipCode');
                ca.Address.PropertyStatus = FEC_CommonUltils.getXmlValue(addrNode, 'PropertyStatus');
                ca.Address.Years = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(addrNode, 'Years'));
                ca.Address.Months = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(addrNode, 'Months'));
                r.CustomerBasicInfo.CurrentAddresses.add(ca);
            }
        }
 
        r.CustomerBasicInfo.PreferredContacts = new List<PreferredContact>();
        Dom.XmlNode contactsNode = c.getChildElement('PreferredContacts', null);
        if (contactsNode != null) {
            for (Dom.XmlNode ctNode : contactsNode.getChildElements()) {
                if (ctNode.getName() != 'Contact') continue;
                PreferredContact pc = new PreferredContact();
                pc.Contact = new Contact();
                pc.Contact.ContactId = FEC_CommonUltils.getXmlValue(ctNode, 'ContactId');
                pc.Contact.Channel = FEC_CommonUltils.getXmlValue(ctNode, 'Channel');
                pc.Contact.CommunicationType = FEC_CommonUltils.getXmlValue(ctNode, 'CommunicationType');
                pc.Contact.ContactString = FEC_CommonUltils.getXmlValue(ctNode, 'ContactString');
                pc.Contact.OfficeExtension = FEC_CommonUltils.getXmlValue(ctNode, 'OfficeExtension');
                r.CustomerBasicInfo.PreferredContacts.add(pc);
            }
        }
 
        r.CustomerBasicInfo.Relatives = new List<Relative>();
        Dom.XmlNode relativesNode = c.getChildElement('Relatives', null);
        if (relativesNode != null) {
            for (Dom.XmlNode rNode : relativesNode.getChildElements()) {
                if (rNode.getName() != 'Relative') continue;
                Relative rel = new Relative();
                rel.RelationType = FEC_CommonUltils.getXmlValue(rNode, 'RelationType');
                rel.FullName = FEC_CommonUltils.getXmlValue(rNode, 'FullName');
                rel.PhoneNumber = FEC_CommonUltils.getXmlValue(rNode, 'PhoneNumber');
                rel.HouseNumber = FEC_CommonUltils.getXmlValue(rNode, 'Number');
                rel.Street = FEC_CommonUltils.getXmlValue(rNode, 'Street');
                rel.Ward = FEC_CommonUltils.getXmlValue(rNode, 'Ward');
                rel.City = FEC_CommonUltils.getXmlValue(rNode, 'City');
                r.CustomerBasicInfo.Relatives.add(rel);
            }
        }
 
        r.CustomerBasicInfo.Employers = new List<Employer>();
        return r;
    }
 
}