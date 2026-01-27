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

    private static final String ENDPOINT = '/CIF_CustomerSearch';
    private static final String MOCKUP_ENDPOINT = 'https://731059cf-33c6-4cf7-b251-898b563c112b.mock.pstmn.io';

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

        FEC_API_Setting__c apiSetting = FEC_API_Setting__c.getOrgDefaults();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
        apiSetting?.FEC_Call_Mock__c
            ? MOCKUP_ENDPOINT
            : (apiSetting?.FEC_Endpoint__c + ENDPOINT)
        );
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'text/xml; charset=utf-8');
        req.setHeader('SOAPAction', 'http://fecredit.com.vn/CIF_CustomerSearch/GetCustomerList');

        String transId = String.valueOf(UUID.randomUUID());
        String dateTimeStr = Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSS');

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
        req.setBody(buildSoapBody(
            transId, requestorId, dateTimeStr,
            phoneNumber, isReferenceSearch,
            fullName, nationalId, applicationId,
            creditCardNumber, accountNumber,
            contractNumber, email, personId
        ));

        Http http = new Http();
        HttpResponse res = http.send(req);

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

        String xml =
            '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            'xmlns:cif="http://fecredit.com.vn/CIF_CustomerSearch">' +
            '<soapenv:Header/>' +
            '<soapenv:Body>' +
            '<cif:GetCustomerList>' +
            '<Sys>' +
            '<TransID>' + transId + '</TransID>' +
            '<RequestorID>' + requestorId + '</RequestorID>' +
            '<DateTime>' + dateTimeStr + '</DateTime>' +
            '</Sys>' +
            '<Parameters>';

        if (String.isNotBlank(phoneNumber)) {
            xml += '<PhoneNumber IsReferencesSearch="' +
                String.valueOf(isReferenceSearch) + '">' +
                phoneNumber + '</PhoneNumber>';
        }
        if (String.isNotBlank(fullName))
            xml += '<FullName>' + fullName + '</FullName>';
        if (String.isNotBlank(nationalId))
            xml += '<NationalID>' + nationalId + '</NationalID>';
        if (String.isNotBlank(applicationId))
            xml += '<ApplicationID>' + applicationId + '</ApplicationID>';
        if (String.isNotBlank(creditCardNumber))
            xml += '<CreditCardNumber>' + creditCardNumber + '</CreditCardNumber>';
        if (String.isNotBlank(accountNumber))
            xml += '<AccountNumber>' + accountNumber + '</AccountNumber>';
        if (String.isNotBlank(contractNumber))
            xml += '<ContractNumber>' + contractNumber + '</ContractNumber>';
        if (String.isNotBlank(email))
            xml += '<Email>' + email + '</Email>';
        if (String.isNotBlank(personId))
            xml += '<PersonId>' + personId + '</PersonId>';

        xml += '</Parameters>' +
               '</cif:GetCustomerList>' +
               '</soapenv:Body>' +
               '</soapenv:Envelope>';

        return xml;
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
            'http://schemas.xmlsoap.org/soap/envelope/'
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
    res.Sys.TransID     = getVal(sysNode, 'TransID');
    res.Sys.DateTime_x  = toDatetime(getVal(sysNode, 'DateTime'));
    res.Sys.Code        = getVal(sysNode, 'Code');
    res.Sys.Description = getVal(sysNode, 'Description');

    /* ===== COUNT ===== */
    res.Count = toInt(getVal(resNode, 'Count'));

    /* ===== CUSTOMERS ===== */
    Dom.XmlNode customersNode = resNode.getChildElement('Customers', null);
        if (customersNode != null) {
            for (Dom.XmlNode cNode : customersNode.getChildElements()) {

                Customer c = new Customer();
                c.CIFNumber   = getVal(cNode, 'CIFNumber');
                c.FullName    = getVal(cNode, 'FullName');
                c.LastName    = getVal(cNode, 'LastName');
                c.FirstName   = getVal(cNode, 'FirstName');
                c.NationalID  = getVal(cNode, 'NationalID');
                c.DateOfBirth = toDate(getVal(cNode, 'DateOfBirth'));

                /* ===== PHONES ===== */
                Dom.XmlNode phonesNode = cNode.getChildElement('Phones', null);
                if (phonesNode != null) {
                    c.Phones = new List<Phone>();
                    for (Dom.XmlNode p : phonesNode.getChildElements()) {
                        Phone ph = new Phone();
                        ph.Type  = getVal(p, 'Type');
                        ph.Phone = getVal(p, 'Phone');
                        c.Phones.add(ph);
                    }
                }

                /* ===== APPLICATIONS ===== */
                Dom.XmlNode appsNode = cNode.getChildElement('Applications', null);
                if (appsNode != null) {
                    c.Applications = new List<Application>();
                    for (Dom.XmlNode a : appsNode.getChildElements()) {
                        Application app = new Application();
                        app.ApplicationID  = getVal(a, 'ApplicationID');
                        app.AccountNumber  = getVal(a, 'AccountNumber');
                        app.ContractNumber = getVal(a, 'ContractNumber');
                        app.Status         = getVal(a, 'Status');
                        app.Product        = getVal(a, 'Product');
                        app.SchemeID       = getVal(a, 'SchemeID');
                        app.SchemeDesc     = getVal(a, 'SchemeDesc');
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
                        ad.AddressType = getVal(a, 'AddressType');
                        ad.HouseNumber = getVal(a, 'Number');
                        ad.Building    = getVal(a, 'Building');
                        ad.Street      = getVal(a, 'Street');
                        ad.Ward        = getVal(a, 'Ward');
                        ad.District    = getVal(a, 'District');
                        ad.City        = getVal(a, 'City');
                        ad.CountryCode = getVal(a, 'CountryCode');
                        ad.CountryName = getVal(a, 'CountryName');
                        ad.ZipCode     = getVal(a, 'ZipCode');
                        ad.PropertyStatus = getVal(a, 'PropertyStatus');
                        c.Addresses.add(ad);
                    }
                }

                res.Customers.add(c);
            }
        }

        return res;
    }

    /* ================================
     * HELPERS
     * ================================ */
    private static String getVal(Dom.XmlNode n, String name) {
        Dom.XmlNode c = (n == null) ? null : n.getChildElement(name, null);
        return (c == null) ? null : c.getText();
    }

    private static Integer toInt(String v) {
        return String.isBlank(v) ? null : Integer.valueOf(v);
    }

    private static Date toDate(String v) {
        return String.isBlank(v) ? null : Date.valueOf(v);
    }

    private static Datetime toDatetime(String v) {
        return String.isBlank(v) ? null : Datetime.valueOf(v.replace('T', ' '));
    }

    private static final Set<String> VALID_REQUESTORS = new Set<String>{
        'CRM', 'CORE', 'MOBILE', 'PORTAL','PEGA'
    };

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

        /* ================= TransID ================= */
        if (String.isBlank(transId) || transId.length() > 36) {
            throw new CalloutException(
                'TransID is null or no longer than 36 characters'
            );
        }

        /* ================= RequestorID ================= */
        if (String.isBlank(requestorId) || !VALID_REQUESTORS.contains(requestorId)) {
            throw new CalloutException(
                'RequestorID is null or invalid'
            );
        }
        // ===================== DATETIME =====================
        if (String.isBlank(dateTimeStr)) {
            throw new CalloutException('DateTime is null or invalid');
        }
        try {
            Datetime.valueOfGmt(dateTimeStr.replace('T',' '));
        } catch(Exception e) {
            throw new CalloutException('DateTime is null or invalid "' + dateTimeStr + '" is not type of Datetime');
        }

        /* ================= Phone ================= */
        if (String.isNotBlank(phoneNumber) &&
            !Pattern.matches('^(0\\d{9}|84\\d{9})$', phoneNumber)) {
            throw new CalloutException(
                'Phone number must start with 0 (10 digits) or 84 (11 digits)'
            );
        }

        /* ================= NationalID ================= */
        if (String.isNotBlank(nationalId) &&
            !Pattern.matches('^(\\d{9}|\\d{12})$', nationalId)) {
            throw new CalloutException(
                'National ID must be 9 characters or 12 characters'
            );
        }

        /* ================= ApplicationID ================= */
        if (String.isNotBlank(applicationId) &&
            !Pattern.matches('^(\\d{6}|\\d{8}|\\d{9})$', applicationId)) {
            throw new CalloutException(
                'ApplicationID must be 6 characters or 8 characters or 9 characters'
            );
        }

        /* ================= AccountNumber ================= */
        if (String.isNotBlank(accountNumber) &&
            !Pattern.matches('^(\\d{16}|\\d{19})$', accountNumber)) {
            throw new CalloutException(
                'AccountNumber must be 16 characters or 19 characters'
            );
        }

        /* ================= ContractNumber ================= */
        if (String.isNotBlank(contractNumber) &&
            !Pattern.matches(
                '^(\\d{8}-\\d{6}-\\d{4}|\\d{8}-\\d{7}-\\d{3}|\\d{8}-\\d{7}-\\d{2}|\\d{8}-\\d{7}-\\d{1}|\\d{8}-\\d{7}|\\d{2}-\\d{2}-\\d{2}-\\d{2})$',
                contractNumber
            )) {
            throw new CalloutException(
                'ContractNumber must be one of: (8)-(6)-(4) | (8)-(7)-(3) | (8)-(7)-(2) | (8)-(7)-(1) | (8)-(7) | (2)-(2)-(2)-(2) digits'
            );
        }

        /* ================= Email ================= */
        if (String.isNotBlank(email) &&
            !Pattern.matches(
                '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,5}(\\.[A-Za-z]{2,5})?$',
                email
            )) {
            throw new CalloutException(
                'Email must be one of (randomString1)@(randomString2).(2-5 chars) or (randomString1)@(randomString2).(2-5 chars).(2-5 chars)'
            );
        }

        /* ================= PersonID ================= */
        if (String.isNotBlank(personId) && !isValidPersonId(personId)) {
            throw new CalloutException(
                'PersonID is invalid'
            );
        }
    }

    // MOCK CHECK – bạn thay bằng SOQL thật
    private static Boolean isValidPersonId(String personId) {
        return personId.startsWith('P');
    }
}