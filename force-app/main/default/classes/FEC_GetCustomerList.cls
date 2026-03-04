public with sharing class FEC_GetCustomerList {
    /* ================================
     * RESPONSE MODELS
     * ================================ */
    public class ResponseWrapper {
        public SysResponse Sys;
        public Integer Count;
        public List<Customer> Customers;
    }

    public class SysResponse {
        public String TransID;
        public Datetime DateTime_x;
        public String Code;
        public String Description;
    }

    public class Customer {
        public String CIFNumber;
        public String FullName;
        public String LastName;
        public String FirstName;
        public String NationalID;
        public Date DateOfBirth;
        public List<Phone> Phones;
        public List<EmailInfo> Emails;
        public List<Application> Applications;
        public List<Address> Addresses;
    }

    public class Phone {
        public String Type;
        public String Phone;
    }

    public class EmailInfo {
        public String Email;
    }

    public class Application {
        public String ApplicationID;
        public String AccountNumber;
        public String ContractNumber;
        public String Status;
        public String Product;
        public String Email;
        public String SchemeID;
        public String SchemeDesc;
    }

    public class Address {
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
    }

    /* ================================
     * PUBLIC CALL METHOD
     * ================================ */
    public static ResponseWrapper getCustomerList(
        String requestorId,
        String phoneNumber,
        Boolean isReferenceSearch,
        String fullName,
        String nationalId,
        String applicationId,
        String creditCardNumber,
        String accountNumber,
        String contractNumber,
        String email,
        String personId
    ) {
        
        String transId = String.valueOf(UUID.randomUUID());
        String dateTimeStr = Datetime.now().format(FEC_ConstantCommon.STR_DATETIME_FORMAT);

        validate(
            transId,
            requestorId,
            dateTimeStr,
            phoneNumber,
            nationalId,
            applicationId,
            accountNumber,
            contractNumber,
            email,
            personId
        );
        
        String soapBody = buildSoapBody(
                transId,
                requestorId,
                dateTimeStr,
                phoneNumber,
                isReferenceSearch,
                fullName,
                nationalId,
                applicationId,
                creditCardNumber,
                accountNumber,
                contractNumber,
                email,
                personId
            );

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        FEC_API_Config__mdt apiConfig = FEC_API_Config__mdt.getInstance('FEC_Get_Customer_List');
        
         String endpoint = apiSetting?.FEC_Call_Mock__c
                ? FEC_MockupEndpoint.GET_CUSTOMER_LIST_ENDPOINT_MOCKUP
                : (apiSetting?.FEC_Endpoint__c + apiConfig?.FEC_Endpoint__c);
                    
        HttpResponse res = FEC_CommonUltils.calloutApi(endpoint, 'POST', FEC_ConstantCommon.API_CONTENT_TYPE, apiConfig?.FEC_SOAP_Action__c, null, soapBody);
               
        // ===== LOG REQUEST + RESPONSE =====
            // FEC_CommonUltils.logApi(
            //     'FEC_GetCustomerList',
            //     endpoint,
            //     'POST',
            //     String.valueOf(res.getStatusCode()),
            //     soapBody,
            //     res.getBody(),
            //     res.getStatusCode() == 200,
            //     null
            // );

        if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {
            return parseResponse(res.getBody());
        }
        return null;
    }

    /* ================================
     * SOAP BODY BUILDER
     * ================================ */
    private static String buildSoapBody(
        String transId,
        String requestorId,
        String dateTimeStr,
        String phoneNumber,
        Boolean isReferenceSearch,
        String fullName,
        String nationalId,
        String applicationId,
        String creditCardNumber,
        String accountNumber,
        String contractNumber,
        String email,
        String personId
    ) {
        Dom.Document doc = new Dom.Document();
        
        Dom.XmlNode envelope = doc.createRootElement(
            'soapenv:Envelope',
            null,
            null
        );
        
        envelope.setAttribute(
            'xmlns:soapenv',
            FEC_ConstantCommon.SOAP_ENV
        );
        
        envelope.setAttribute(
            'xmlns:cif',
            'http://fecredit.com.vn/CIF_CustomerSearch'
        );
        
         // ===== Header =====
        envelope.addChildElement('soapenv:Header', null, null);
        
        // ===== Body =====
        Dom.XmlNode body =
            envelope.addChildElement('soapenv:Body', null, null);
        
        // ===== Main Action =====
        Dom.XmlNode action =
            body.addChildElement('ns1:GetCustomerList', null, null);
        
        action.setAttribute(
            'xmlns:ns1',
            'http://fecredit.com.vn/CIF_CustomerSearch'
        );

        Dom.XmlNode sys = action.addChildElement('Sys', null, null);
        sys.addChildElement('TransID', null, null).addTextNode(transId);
        sys.addChildElement('RequestorID', null, null).addTextNode(requestorId);
        sys.addChildElement('DateTime', null, null).addTextNode(dateTimeStr);

        Dom.XmlNode params = action.addChildElement('Parameters', null, null);

        if (String.isNotBlank(phoneNumber)) {
            Dom.XmlNode phone = params.addChildElement('PhoneNumber', null, null);
            phone.setAttribute(
                'IsReferencesSearch',
                String.valueOf(isReferenceSearch)
            );
            phone.addTextNode(phoneNumber);
        }

        if (String.isNotBlank(fullName))
            params.addChildElement('FullName', null, null).addTextNode(fullName);

        if (String.isNotBlank(nationalId))
            params.addChildElement('NationalID', null, null).addTextNode(nationalId);

        if (String.isNotBlank(applicationId))
            params.addChildElement('ApplicationID', null, null).addTextNode(applicationId);

        if (String.isNotBlank(creditCardNumber))
            params.addChildElement('CreditCardNumber', null, null)
                  .addTextNode(creditCardNumber);

        if (String.isNotBlank(accountNumber))
            params.addChildElement('AccountNumber', null, null)
                  .addTextNode(accountNumber);

        if (String.isNotBlank(contractNumber))
            params.addChildElement('ContractNumber', null, null)
                  .addTextNode(contractNumber);

        if (String.isNotBlank(email))
            params.addChildElement('Email', null, null).addTextNode(email);

        if (String.isNotBlank(personId))
            params.addChildElement('PersonId', null, null).addTextNode(personId);

        return doc.toXmlString();
    }

    /* ================================
     * RESPONSE PARSER
     * ================================ */
    public static ResponseWrapper parseResponse(String xml) {

    Dom.Document doc = new Dom.Document();
    doc.load(xml);

    Dom.XmlNode body = doc.getRootElement()
        .getChildElement(
            'Body',
            FEC_ConstantCommon.SOAP_ENV
        );

    Dom.XmlNode resNode;
    for (Dom.XmlNode n : body.getChildElements()) {
        if (n.getName().endsWith('GetCustomerListResponse')) {
            resNode = n;
            break;
        }
    }

    if (resNode == null) {
        throw new CalloutException('Cannot find GetCustomerListResponse');
    }

    ResponseWrapper res = new ResponseWrapper();
    res.Customers = new List<Customer>();

    /* ===== SYS ===== */
    Dom.XmlNode sysNode = resNode.getChildElement('Sys', null);
    res.Sys = new SysResponse();
    res.Sys.TransID     = FEC_CommonUltils.getXmlValue(sysNode, 'TransID');
    res.Sys.DateTime_x  = FEC_CommonUltils.toDatetime(FEC_CommonUltils.getXmlValue(sysNode, 'DateTime'));
    res.Sys.Code        = FEC_CommonUltils.getXmlValue(sysNode, 'Code');
    res.Sys.Description = FEC_CommonUltils.getXmlValue(sysNode, 'Description');

    /* ===== COUNT ===== */
    res.Count = FEC_CommonUltils.toInt(FEC_CommonUltils.getXmlValue(resNode, 'Count'));

    /* ===== CUSTOMERS ===== */
    Dom.XmlNode customersNode = resNode.getChildElement('Customers', null);
        if (customersNode != null) {
            for (Dom.XmlNode cNode : customersNode.getChildElements()) {

                Customer c = new Customer();
                c.CIFNumber   = FEC_CommonUltils.getXmlValue(cNode, 'CIFNumber');
                c.FullName    = FEC_CommonUltils.getXmlValue(cNode, 'FullName');
                c.LastName    = FEC_CommonUltils.getXmlValue(cNode, 'LastName');
                c.FirstName   = FEC_CommonUltils.getXmlValue(cNode, 'FirstName');
                c.NationalID  = FEC_CommonUltils.getXmlValue(cNode, 'NationalID');
                c.DateOfBirth = FEC_CommonUltils.toDate(FEC_CommonUltils.getXmlValue(cNode, 'DateOfBirth'));

                /* ===== PHONES ===== */
                Dom.XmlNode phonesNode = cNode.getChildElement('Phones', null);
                if (phonesNode != null) {
                    c.Phones = new List<Phone>();
                    for (Dom.XmlNode p : phonesNode.getChildElements()) {
                        Phone ph = new Phone();
                        ph.Type  = FEC_CommonUltils.getXmlValue(p, 'Type');
                        ph.Phone = FEC_CommonUltils.getXmlValue(p, 'Phone');
                        c.Phones.add(ph);
                    }
                }

                /* ===== APPLICATIONS ===== */
                Dom.XmlNode appsNode = cNode.getChildElement('Applications', null);
                if (appsNode != null) {
                    c.Applications = new List<Application>();
                    for (Dom.XmlNode a : appsNode.getChildElements()) {
                        Application app = new Application();
                        app.ApplicationID  = FEC_CommonUltils.getXmlValue(a, 'ApplicationID');
                        app.AccountNumber  = FEC_CommonUltils.getXmlValue(a, 'AccountNumber');
                        app.ContractNumber = FEC_CommonUltils.getXmlValue(a, 'ContractNumber');
                        app.Status         = FEC_CommonUltils.getXmlValue(a, 'Status');
                        app.Product        = FEC_CommonUltils.getXmlValue(a, 'Product');
                        app.SchemeID       = FEC_CommonUltils.getXmlValue(a, 'SchemeID');
                        app.SchemeDesc     = FEC_CommonUltils.getXmlValue(a, 'SchemeDesc');
                        c.Applications.add(app);
                    }
                }
                
                /* ===== EMAILS ===== */
                Dom.XmlNode emailsNode = cNode.getChildElement('Emails', null);
                if (emailsNode != null) {
                    c.Emails = new List<EmailInfo>();
                    for (Dom.XmlNode e : emailsNode.getChildElements()) {
                        EmailInfo em = new EmailInfo();
                        em.Email = e.getText();
                        c.Emails.add(em);
                    }
                }

                /* ===== ADDRESSES ===== */
                Dom.XmlNode addrNode = cNode.getChildElement('Addresses', null);
                if (addrNode != null) {
                    c.Addresses = new List<Address>();
                    for (Dom.XmlNode a : addrNode.getChildElements()) {
                        Address ad = new Address();
                        ad.AddressType = FEC_CommonUltils.getXmlValue(a, 'AddressType');
                        ad.HouseNumber = FEC_CommonUltils.getXmlValue(a, 'Number');
                        ad.Building    = FEC_CommonUltils.getXmlValue(a, 'Building');
                        ad.Street      = FEC_CommonUltils.getXmlValue(a, 'Street');
                        ad.Ward        = FEC_CommonUltils.getXmlValue(a, 'Ward');
                        ad.District    = FEC_CommonUltils.getXmlValue(a, 'District');
                        ad.City        = FEC_CommonUltils.getXmlValue(a, 'City');
                        ad.CountryCode = FEC_CommonUltils.getXmlValue(a, 'CountryCode');
                        ad.CountryName = FEC_CommonUltils.getXmlValue(a, 'CountryName');
                        ad.ZipCode     = FEC_CommonUltils.getXmlValue(a, 'ZipCode');
                        ad.PropertyStatus = FEC_CommonUltils.getXmlValue(a, 'PropertyStatus');
                        c.Addresses.add(ad);
                    }
                }

                res.Customers.add(c);
            }
        }

        return res;
    }

    public static void validate(
        String transId,
        String requestorId,
        String dateTimeStr,
        String phoneNumber,
        String nationalId,
        String applicationId,
        String accountNumber,
        String contractNumber,
        String email,
        String personId
    ) {
        Set<String> validRequestors = new Set<String>{'CRM', 'CORE', 'MOBILE', 'PORTAL','PEGA'};
        /* ================= TransID ================= */
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(
                System.Label.FEC_MSG_TransID_Null
            );
        }

        /* ================= RequestorID ================= */
        if (String.isBlank(requestorId) || !validRequestors.contains(requestorId)) {
            throw new CalloutException(
                System.Label.FEC_MSG_RequestorID_Null
            );
        }
        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException(System.Label.FEC_MSG_Datetime_Null);
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T',' '));
        } catch(Exception e) {
            throw new CalloutException(String.format(System.Label.FEC_MSG_Datetime_Invalid, new List<String>{dateTimeStr}));
        }

        /* ================= Phone ================= */
        if (String.isNotBlank(phoneNumber) &&
            !Pattern.matches(FEC_ConstantCommon.PATTERN_PHONE_NUMBER, phoneNumber)) {
            throw new CalloutException(
                System.Label.FEC_MSG_Phone_Number_Invalid
            );
        }

        /* ================= NationalID ================= */
        if (String.isNotBlank(nationalId) &&
            !Pattern.matches(FEC_ConstantCommon.PATTERN_NATIONAL_ID, nationalId)) {
            throw new CalloutException(
                System.Label.FEC_MSG_National_ID_Invalid
            );
        }

        /* ================= ApplicationID ================= */
        if (String.isNotBlank(applicationId) &&
            !Pattern.matches(FEC_ConstantCommon.PATTERN_APPLICATION_ID, applicationId)) {
            throw new CalloutException(
                System.Label.FEC_MSG_ApplicationID_Invalid
            );
        }

        /* ================= AccountNumber ================= */
        if (String.isNotBlank(accountNumber) &&
            !Pattern.matches(FEC_ConstantCommon.PATTERN_ACCOUNT_NUMBER, accountNumber)) {
            throw new CalloutException(
                System.Label.FEC_MSG_AccountNumber_Invalid
            );
        }

        /* ================= ContractNumber ================= */
        if (String.isNotBlank(contractNumber) &&
            !Pattern.matches(
                FEC_ConstantCommon.PATTERN_CONTRACT_NUMBER,
                contractNumber
            )) {
            throw new CalloutException(
                System.Label.FEC_MSG_ContractNumber_Invalid
            );
        }

        /* ================= Email ================= */
        if (String.isNotBlank(email) &&
            !Pattern.matches(
                FEC_ConstantCommon.PATTERN_EMAIL,
                email
            )) {
            throw new CalloutException(
                System.Label.FEC_MSG_Email_Invalid
            );
        }

        /* ================= PersonID ================= */
        if (String.isNotBlank(personId) && !isValidPersonId(personId)) {
            throw new CalloutException(
                System.Label.FEC_MSG_PersonID_Invalid
            );
        }
    }

    // MOCK CHECK – bạn thay bằng SOQL thật
    private static Boolean isValidPersonId(String personId) {
        return personId.startsWith('P');
    }
}