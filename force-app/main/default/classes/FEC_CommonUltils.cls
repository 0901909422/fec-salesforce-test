public with sharing class FEC_CommonUltils {

  public static Boolean isLengthValid(String str, Integer maxLength) {
    if (String.isBlank(str)) {
      return false;
    }

    return str.length() <= maxLength;
  }

  public static Boolean isMail(String email) {
    if (String.isBlank(email)) {
      return false;
    }

    String regex =
      '^[A-Za-z0-9]+(\\.[A-Za-z0-9]+)*' + // local part: john.smith.dev
      '@' +
      '[A-Za-z0-9]+' + // domain root: gmail
      '(\\.[A-Za-z]{2,5})+'; // one or more .com .co .jp etc

    return Pattern.matches(regex, email);
  }

  public static Boolean isPhone(String phone) {
    if (String.isBlank(phone)) {
      return false;
    }

    // Must contain digits only
    if (!Pattern.matches('\\d+', phone)) {
      return false;
    }

    // Case 1: starts with 0 → must be 10 digits
    if (phone.startsWith('0')) {
      return phone.length() == 10;
    }

    // Case 2: starts with 84 → must be 11 digits
    if (phone.startsWith('84')) {
      return phone.length() == 11;
    }

    return false;
  }

  public static Boolean isValidDateByFormat(String input) {
    if (String.isBlank(input))
      return false;

    // Step 1: Strict format check
    Pattern p = Pattern.compile('^\\d{4}-\\d{2}-\\d{2}$');
    if (!p.matcher(input).matches())
      return false;

    // Step 2: Real date validation
    try {
      Date d = Date.valueOf(input); // Salesforce expects YYYY-MM-DD
      return true;
    } catch (Exception e) {
      return false; // catches 2024-02-30, 2023-13-01, etc.
    }
  }

  public static List<PicklistOption> getPicklistOptions(
    String objectName,
    String fieldName
  ) {
    List<PicklistOption> options = new List<PicklistOption>();
    try {
      // Get the object and field tokens
      Schema.SObjectType sObjectType = Schema.getGlobalDescribe()
        .get(objectName);
      Schema.DescribeSObjectResult sObjectDescribe = sObjectType.getDescribe();
      Schema.DescribeFieldResult fieldDescribe = sObjectDescribe.fields.getMap()
        .get(fieldName)
        .getDescribe();

      // Retrieve the picklist values
      List<Schema.PicklistEntry> picklistValues = fieldDescribe.getPicklistValues();

      for (Schema.PicklistEntry entry : picklistValues) {
        options.add(
          new PicklistOption(entry.getLabel(), entry.getValue(), null)
        );
      }
    } catch (Exception e) {
      // Log the error for debugging
      System.debug('Error in getPicklistOptions: ' + e.getMessage());
    }
    return options;
  }
  
  public static String resolveTemplate(String template, SObject c) {
    if (String.isBlank(template) || c == null) {
      return template;
    }
    
    // Find all {{...}} placeholders
    Pattern p = Pattern.compile('\\{\\{([^}]+)\\}\\}');
    Matcher m = p.matcher(template);
    
    String result = template;
    
    while (m.find()) {
      String fullMatch = m.group(0); // {{Account.Name}}
      String fieldPath = m.group(1); // Account.Name
      
      String value = getFieldValue(c, fieldPath);
      result = result.replace(fullMatch, value);
    }
    
    return result;
  }
  
  public static Set<String> extractFieldPaths(List<String> templates) {
    Set<String> fieldSet = new Set<String>();
    
    if (templates == null || templates.isEmpty()) {
      return new Set<String>();
    }
    
    Pattern p = Pattern.compile('\\{\\{([^}]+)\\}\\}');
    
    for (String template : templates) {
      if (String.isBlank(template))
        continue;
      
      Matcher m = p.matcher(template);
      while (m.find()) {
        fieldSet.add(m.group(1)); // Account.Name, Custom__r.Field__c
      }
    }
    
    return fieldSet;
  }
  
  private static String getFieldValue(SObject sobj, String fieldPath) {
    try {
      List<String> parts = fieldPath.split('\\.');
      
      // Simple field: {{Name}}
      if (parts.size() == 1) {
        Object val = sobj.get(parts[0]);
        return val == null ? '' : String.valueOf(val);
      }
      
      // Parent field: {{Account.Name}}
      SObject parent = sobj.getSObject(parts[0]);
      if (parent == null)
        return '';
      
      Object val = parent.get(parts[1]);
      return val == null ? '' : String.valueOf(val);
    } catch (Exception e) {
      // Invalid field → return empty string safely
      return '';
    }
  }
  
  public class PicklistOption {
    @AuraEnabled
    public string label { get; set; }

    @AuraEnabled
    public string value { get; set; }

    @AuraEnabled
    public string helpText { get; set; }

    public PicklistOption() {
    }

    public PicklistOption(String label, String value, String helpText) {
      this.label = label;
      this.value = value;
      this.helpText = helpText;
    }
  }
  
  @AuraEnabled
  public static void logSensitiveAccess(
    String section,
    String name,
    String userName,
    String userRole,
    Id relatedCaseId
  ) {
    FEC_Sensitive_Data__c sensitiveData = new FEC_Sensitive_Data__c(
      FEC_Section__c = section,
      Name = name,
      FEC_User__c = userName,
      FEC_User_Role__c = userRole,
      FEC_Related_Case__c = relatedCaseId
    );
    insert sensitiveData;
  }
  
  public static String getXmlValue(Dom.XmlNode n, String name) {
    Dom.XmlNode c = (n == null) ? null : n.getChildElement(name, null);
    return (c == null) ? null : c.getText();
  }

  public static Decimal xmlValToDecimal(Dom.XmlNode n, String name) {
    String v = getXmlValue(n, name);
    return String.isBlank(v) ? null : Decimal.valueOf(v);
  }

  public static Date xmlValToDate(Dom.XmlNode n, String name) {
    String v = getXmlValue(n, name);
    return parseDate(v);
  }

  public static Dom.XmlNode findChildByName(Dom.XmlNode parent, String nodeName) {
    if (parent == null) return null;
    for (Dom.XmlNode child : parent.getChildElements()) {
      if (child.getName() == nodeName || child.getName().endsWith(':' + nodeName)) {
        return child;
      }
    }
    return null;
  }

  public static Integer toInt(String v) {
    return String.isBlank(v) ? null : Integer.valueOf(v);
  }

  public static Date toDate(String v) {
    return String.isBlank(v) ? null : Date.valueOf(v);
  }

  public static Datetime toDatetime(String v) {
    return String.isBlank(v) ? null : Datetime.valueOf(v.replace('T', ' '));
  }

  /**
   * Mask số thẻ: hiển thị 6 số đầu và 4 số cuối, các số còn lại là '*'
   */
  public static String maskCardNumber(String cardNumber) {
    if (String.isBlank(cardNumber) || cardNumber.length() < 10) {
      return cardNumber;
    }
    String first6 = cardNumber.substring(0, 6);
    String last4 = cardNumber.substring(cardNumber.length() - 4);
    String middle = '';
    for (Integer i = 6; i < cardNumber.length() - 4; i++) {
      middle += '*';
    }
    return first6 + middle + last4;
  }

  /**
   * Format API trả về: yyyyMMdd (VD: 20281031) hoặc YYYY-MM-DD
   * @param dateStr - Chuỗi ngày tháng từ API
   * @return Đối tượng Date
   */
  public static Date parseDate(String dateStr) {
    if (String.isBlank(dateStr))
      return null;

    // Loại bỏ trường hợp 00000000 (không có ngày)
    if (dateStr == '00000000' || dateStr == '0')
      return null;

    try {
      // Format API trả về: yyyyMMdd (VD: 20281031)
      if (dateStr.length() == 8 && dateStr.isNumeric()) {
        Integer year = Integer.valueOf(dateStr.substring(0, 4));
        Integer month = Integer.valueOf(dateStr.substring(4, 6));
        Integer day = Integer.valueOf(dateStr.substring(6, 8));
        return Date.newInstance(year, month, day);
      }

      // Fallback: Format YYYY-MM-DD
      return Date.valueOf(dateStr);
    } catch (Exception e) {
      System.debug(
        'convertDateSafeForOtherCard error for "' +
          dateStr +
          '": ' +
          e.getMessage()
      );
      return null;
    }
  }

  public static Datetime parseDateTime(String dateTimeStr) {
    if (String.isBlank(dateTimeStr)) {
      return null;
    }
    try {
      // Format: 2025-10-31T14:00:10.491Z
      dateTimeStr = dateTimeStr.replace('T', ' ').replace('Z', '');
      if (dateTimeStr.contains('.')) {
        dateTimeStr = dateTimeStr.substringBefore('.');
      }
      return Datetime.valueOf(dateTimeStr);
    } catch (Exception e) {
      System.debug(
        'Failed to parse datetime: ' +
          dateTimeStr +
          ', Error: ' +
          e.getMessage()
      );
      return null;
    }
  }

  public static HttpResponse calloutApi(
    String endpoint,
    String method,
    String contentType,
    String soapAction,
    Dom.Document docBody,
    String body
  ) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod(method);
    req.setHeader('Content-Type', contentType);
    if (String.isNotBlank(soapAction)) {
      req.setHeader('SOAPAction', soapAction);
    }
    if (docBody != null) {
      req.setBodyDocument(docBody);
    } else {
      req.setBody(body);
    }
    req.setTimeout(120000); // 120 seconds timeout

    Http http = new Http();
    HttpResponse res = http.send(req);
    return res;
  }

  public static String generateTransactionId() {
    return Datetime.now().getTime() +
      '_' +
      String.valueOf(Math.abs(Crypto.getRandomInteger())).substring(0, 6);
  }

  public static String formatCurrency(Decimal amount, Integer scale) {
    if (amount == null)
      return '';
    return amount.setScale(scale).format();
  }

  public static String formatDate(Date d) {
    if (d == null)
      return '';
    return d.format();
  }

  public static String decimalToString(Decimal d) {
    return d == null ? '' : d.format();
  }
  /**
   * Mask National ID (CCCD) hoặc Passport ID để hiển thị an toàn.
   * - CCCD: 9 hoặc 12 ký tự (chỉ số) → thay giữa bằng "*", hiển thị 3 số đầu + 3 số cuối.
   * - Passport: 8 ký tự (ký tự đầu là chữ, 7 ký tự sau là số) → thay giữa bằng "*", hiển thị 2 ký tự đầu + 3 ký tự cuối.
   * @param value National ID hoặc Passport ID (raw)
   * @return Chuỗi đã mask, hoặc value gốc nếu blank/không khớp format
   */
  public static String maskNationalIdOrPassport(String value) {
    if (String.isBlank(value)) {
      return value;
    }
    String s = value.trim();

    // CCCD: 9 hoặc 12 ký tự, chỉ gồm số
    if ((s.length() == 9 || s.length() == 12) && Pattern.matches('\\d+', s)) {
      if (s.length() < 6)
        return s;
      String first3 = s.substring(0, 3);
      String last3 = s.substring(s.length() - 3);
      String middle = '';
      for (Integer i = 3; i < s.length() - 3; i++) {
        middle += '*';
      }
      return first3 + middle + last3;
    }

    // Passport: 8 ký tự, ký tự đầu là chữ, 7 ký tự sau là số
    if (s.length() == 8 && Pattern.matches('[A-Za-z]\\d{7}', s)) {
      String first2 = s.substring(0, 2);
      String last3 = s.substring(5, 8);
      String middle = '***';
      return first2 + middle + last3;
    }

    // Fallback: không khớp format → 3 đầu + 3 cuối
    if (s.length() < 6)
      return s;
    String first3 = s.substring(0, 3);
    String last3 = s.substring(s.length() - 3);
    String middle = '';
    for (Integer i = 3; i < s.length() - 3; i++) {
      middle += '*';
    }
    return first3 + middle + last3;
  }

  public static void createProcessActionHistory(
    String name,
    String stage,
    Boolean isSuccess
  ) {
    List<User> userlst = [
      SELECT Email, UserRole.Name
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];

    if (userlst.isEmpty())
      return;

    FEC_Process_Action_History__c action = new FEC_Process_Action_History__c(
      Name = name,
      FEC_Stage_Name__c = stage,
      FEC_Action_Result__c = isSuccess ? 'Success' : 'Fail',
      FEC_User__c = userlst.get(0).Email.split('@')[0],
      FEC_User_Role__c = userlst.get(0).UserRole.Name
    );

    insert action;
  }

 public static String maskPhone(String phone) {
        if (String.isBlank(phone)) {
            return phone;
        }
        
        Integer len = phone.length();
        
        // Nếu quá ngắn thì không mask
        if (len <= 7) {
            return phone;
        }
        
        return phone.substring(0, 4)
            + '***'
            + phone.substring(len - 3);
    } 
}