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

            String soapBody =
                '<?xml version="1.0" encoding="utf-8"?>' +
                '<soapenv:Envelope xmlns:soapenv="' + FEC_ConstantCommon.SOAP_ENV + '" ' +
                'xmlns:cif="' + CIF_NS + '">' +
                    '<soapenv:Header/>' +
                    '<soapenv:Body>' +
                        '<cif:GetCustomerInfoBasic>' +
                            '<Sys>' +
                                '<TransID>' + transId + '</TransID>' +
                                '<RequestorID>' + requestorId + '</RequestorID>' +
                                '<DateTime>' + dateTimeStr + '</DateTime>' +
                            '</Sys>' +
                            '<CIFNumber>' + cifNumber + '</CIFNumber>' +
                        '</cif:GetCustomerInfoBasic>' +
                    '</soapenv:Body>' +
                '</soapenv:Envelope>';

            FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
            FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Customer_Info_Basic');

            String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CUSTOMER_INFO_BASIC_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
            HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);

            if (res.getStatusCode() != 200)
                throw new CalloutException('HTTP_ERROR: ' + res.getStatusCode());
            if (String.isBlank(res.getBody()))
                throw new CalloutException('Empty response body');

            return parseResponse(res.getBody());
        }
        catch (Exception ex) {
            System.debug('### GET CUSTOMER INFO BASIC ERROR: ' + ex.getMessage());
            throw ex;
        }
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
    if (String.isBlank(transId)) {
            throw new CalloutException('TransID is null or invalid');
    }
    if (transId.length() > 36) {
            throw new CalloutException('TransID must not exceed 36 characters');
    }

    if (String.isBlank(requestorId)) {
        throw new CalloutException('RequestorID is null or invalid');
    }

        Set<String> validRequestorIds = new Set<String>{ FEC_ConstantCommon.REQUESTOR_CRM,FEC_ConstantCommon.REQUESTOR_PORTAL,FEC_ConstantCommon.REQUESTOR_MOBILE_APP };
    if (!validRequestorIds.contains(requestorId)) {
        throw new CalloutException(
            'RequestorID "' + requestorId + '" is not valid'
        );
    }

    if (String.isBlank(dateTimeStr)) {
        throw new CalloutException('DateTime is null or invalid');
    }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T', ' '));
        } catch (Exception e) {
        throw new CalloutException(
            'DateTime "' + dateTimeStr + '" is not valid Datetime'
        );
        }

    if (String.isBlank(cifNumber)) {
            throw new CalloutException('CIFNumber is null or invalid');
    }

    if (!Pattern.matches('\\d+', cifNumber)) {
            throw new CalloutException('CIFNumber must be numeric');
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
            throw new CalloutException('Missing GetCustomerInfoBasicResponse');

        ResponseWrapper r = new ResponseWrapper();

        /* ===== SYS ===== */
        Dom.XmlNode sysNode =
            responseNode.getChildElement('Sys', null);

        if (sysNode == null)
            throw new CalloutException('Missing Sys node');

        r.Sys = new SysResponse();
        r.Sys.TransID = getVal(sysNode, 'TransID', null);
        r.Sys.DateTime_x = getVal(sysNode, 'DateTime', null);
        r.Sys.Code = getVal(sysNode, 'Code', null);
        r.Sys.Description = getVal(sysNode, 'Description', null);

        if (r.Sys.Code != '1')
            throw new CalloutException('API FAIL: ' + r.Sys.Description);

        /* ===== CUSTOMER ===== */
        Dom.XmlNode c =
            responseNode.getChildElement('CustomerBasicInfo', null);

        r.CustomerBasicInfo = new CustomerBasicInfo();
        r.CustomerBasicInfo.CIFNumber = getVal(c, 'CIFNumber', null);
        r.CustomerBasicInfo.CIFDWH = getVal(c, 'CIFDWH', null);
        r.CustomerBasicInfo.FirstName = getVal(c, 'FirstName', null);
        r.CustomerBasicInfo.MiddleName = getVal(c, 'MiddleName', null);
        r.CustomerBasicInfo.LastName = getVal(c, 'LastName', null);
        r.CustomerBasicInfo.FullName = getVal(c, 'FullName', null);
        r.CustomerBasicInfo.ShortName = getVal(c, 'ShortName', null);
        r.CustomerBasicInfo.Title = getVal(c, 'Title', null);
        r.CustomerBasicInfo.Birthday = getDate(c, 'Birthday', null);
        r.CustomerBasicInfo.Gender = getVal(c, 'Gender', null);
        r.CustomerBasicInfo.Citizenship = getVal(c, 'Citizenship', null);
        r.CustomerBasicInfo.SocialStatus = getVal(c, 'SocialStatus', null);
        r.CustomerBasicInfo.MaritalStatus = getVal(c, 'MaritalStatus', null);
        r.CustomerBasicInfo.CustomerStatus = getVal(c, 'CustomerStatus', null);
        r.CustomerBasicInfo.CustomerValue = getVal(c, 'CustomerValue', null);

        r.CustomerBasicInfo.CurrentAddresses = new List<CurrentAddress>();
        Dom.XmlNode currAddrsNode = c.getChildElement('CurrentAddresses', null);
        if (currAddrsNode != null) {
            for (Dom.XmlNode addrNode : currAddrsNode.getChildElements()) {
                if (addrNode.getName() != 'Address') continue;
                CurrentAddress ca = new CurrentAddress();
                ca.Address = new Address();
                ca.Address.AddressId = getVal(addrNode, 'AddressId', null);
                ca.Address.AddressType = getVal(addrNode, 'AddressType', null);
                ca.Address.HouseNumber = getVal(addrNode, 'Number', null);
                ca.Address.Street = getVal(addrNode, 'Street', null);
                ca.Address.Ward = getVal(addrNode, 'Ward', null);
                ca.Address.District = getVal(addrNode, 'District', null);
                ca.Address.City = getVal(addrNode, 'City', null);
                ca.Address.CountryCode = getVal(addrNode, 'CountryCode', null);
                ca.Address.CountryName = getVal(addrNode, 'CountryName', null);
                ca.Address.ZipCode = getVal(addrNode, 'ZipCode', null);
                ca.Address.PropertyStatus = getVal(addrNode, 'PropertyStatus', null);
                ca.Address.Years = toInt(getVal(addrNode, 'Years', null));
                ca.Address.Months = toInt(getVal(addrNode, 'Months', null));
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
                pc.Contact.ContactId = getVal(ctNode, 'ContactId', null);
                pc.Contact.Channel = getVal(ctNode, 'Channel', null);
                pc.Contact.CommunicationType = getVal(ctNode, 'CommunicationType', null);
                pc.Contact.ContactString = getVal(ctNode, 'ContactString', null);
                pc.Contact.OfficeExtension = getVal(ctNode, 'OfficeExtension', null);
                r.CustomerBasicInfo.PreferredContacts.add(pc);
            }
        }

        r.CustomerBasicInfo.Relatives = new List<Relative>();
        Dom.XmlNode relativesNode = c.getChildElement('Relatives', null);
        if (relativesNode != null) {
            for (Dom.XmlNode rNode : relativesNode.getChildElements()) {
                if (rNode.getName() != 'Relative') continue;
                Relative rel = new Relative();
                rel.RelationType = getVal(rNode, 'RelationType', null);
                rel.FullName = getVal(rNode, 'FullName', null);
                rel.PhoneNumber = getVal(rNode, 'PhoneNumber', null);
                rel.HouseNumber = getVal(rNode, 'Number', null);
                rel.Street = getVal(rNode, 'Street', null);
                rel.Ward = getVal(rNode, 'Ward', null);
                rel.City = getVal(rNode, 'City', null);
                r.CustomerBasicInfo.Relatives.add(rel);
            }
        }

        r.CustomerBasicInfo.Employers = new List<Employer>();
        return r;
    }

    /* =====================================================
       HELPERS
       ===================================================== */

    private static String getVal(Dom.XmlNode n, String name, String ns) {
        if (n == null) return null;
        Dom.XmlNode c = n.getChildElement(name, ns);
        return c == null ? null : c.getText();
    }

    private static Integer toInt(String v) {
        return String.isBlank(v) ? null : Integer.valueOf(v);
    }

    private static Date getDate(Dom.XmlNode n, String name, String ns) {
        String v = getVal(n, name, ns);
        return String.isBlank(v) ? null : Date.valueOf(v);
    }
}