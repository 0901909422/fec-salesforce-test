public with sharing class FEC_CommonUltils {
  public static void notifyUsers(
    Set<String> recipientsIds,
    String targetId,
    String targetPageRef,
    String title,
    String body
  ) {
    // Get the Id for our custom notification type
    CustomNotificationType notificationType = [
      SELECT Id, DeveloperName
      FROM CustomNotificationType
      WHERE DeveloperName = 'Custom_Notification'
    ];

    // Create a new custom notification
    Messaging.CustomNotification notification = new Messaging.CustomNotification();

    // Set the contents for the notification
    notification.setTitle(title);
    notification.setBody(body);

    // Set the notification type and target
    notification.setNotificationTypeId(notificationType.Id);
    if (String.isNotBlank(targetId)) {
      notification.setTargetId(targetId);
    } else {
      notification.setTargetPageRef(targetPageRef);
    }

    // Actually send the notification
    try {
      notification.send(recipientsIds);
    } catch (Exception e) {
      System.debug('Problem sending notification: ' + e.getMessage());
    }
  }

  public static void notifyUsers(
    Set<String> recipientsIds,
    Id targetId,
    String targetPageRef,
    String title,
    String body,
    CustomNotificationType notificationType
  ) {
    // Create a new custom notification
    Messaging.CustomNotification notification = new Messaging.CustomNotification();

    // Set the contents for the notification
    notification.setTitle(title);
    notification.setBody(body);

    // Set the notification type and target
    notification.setNotificationTypeId(notificationType.Id);
    if (String.isNotBlank(targetId)) {
      notification.setTargetId(targetId);
    } else {
      notification.setTargetPageRef(targetPageRef);
    }

    // Actually send the notification
    try {
      notification.send(recipientsIds);
    } catch (Exception e) {
      System.debug('Problem sending notification: ' + e.getMessage());
    }
  }

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

  /**
   * Kiểm tra Case Status có thuộc nhóm Resolved hay không (bắt đầu bằng prefix Resolved).
   * @param status Case Status (có thể null)
   * @return true nếu status không rỗng và bắt đầu bằng FEC_ConstantCommon.CASE_STATUS_PREFIX_RESOLVED
   */
  public static Boolean isCaseStatusResolved(String status) {
    return String.isNotBlank(status) && status.startsWith(FEC_ConstantCommon.CASE_STATUS_PREFIX_RESOLVED);
  }

  /**
   * Trả về chuỗi gốc nếu không blank, ngược lại trả về STR_EMPTY.
   * @param str Chuỗi cần kiểm tra (có thể null)
   * @return str nếu không blank, ngược lại FEC_ConstantCommon.STR_EMPTY
   */
  public static String defaultToEmpty(String str) {
    return String.isNotBlank(str) ? str : FEC_ConstantCommon.STR_EMPTY;
  }

  /**
   * Trả về String.valueOf(obj) nếu obj != null, ngược lại STR_EMPTY.
   * @param obj Giá trị bất kỳ (Id, String, ... có thể null)
   * @return Chuỗi biểu diễn obj hoặc FEC_ConstantCommon.STR_EMPTY
   */
  public static String defaultToEmpty(Object obj) {
    return obj != null ? String.valueOf(obj) : FEC_ConstantCommon.STR_EMPTY;
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

  /**
   * Kiểm tra AccountNumber có hợp lệ không (16 hoặc 19 chữ số)
   * @param accountNumber - Account Number cần kiểm tra
   * @return true nếu hợp lệ (16 hoặc 19 chữ số), false nếu không
   */
  public static Boolean isValidAccountNumber(String accountNumber) {
    if (String.isBlank(accountNumber)) {
      return false;
    }
    // AccountNumber phải có 16 hoặc 19 chữ số theo requirement của API GetCustomerList
    return Pattern.matches('^\\d{16}$', accountNumber) || Pattern.matches('^\\d{19}$', accountNumber);
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

  public static String getXmlValueHasNamspace(Dom.XmlNode n, String name) {
    if (n == null) return null;

    for (Dom.XmlNode child : n.getChildElements()) {
        if (child.getName() == name) {
            return child.getText();
        }
    }
    return null;
  }

  public static Decimal xmlValToDecimal(Dom.XmlNode n, String name) {
    String v = getXmlValue(n, name);
    if (String.isBlank(v)) {
      return null;
    }

    v = v.trim(); 
    if (v == '') {
        return null;
    }
    try {
        return Decimal.valueOf(v);
    } catch (Exception e) {
      System.debug('Invalid decimal for tag ' + name + ': [' + v + ']');
      return null; 
    }
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

  public static String getValueSafe(Dom.XmlNode parent,String nodeName) {
    if (parent == null) return null;

    Dom.XmlNode node = findChildByName(parent, nodeName);

    return node == null ? null : node.getText();
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

    if (dateStr == '00000000' || dateStr == '99999999') {
      return null;
    }
    
    try {
      // Format API trả về: yyyyMMdd (VD: 20281031)
      if (dateStr.length() == 8 && dateStr.isNumeric()) {
        Integer year = Integer.valueOf(dateStr.substring(0, 4));
        Integer month = Integer.valueOf(dateStr.substring(4, 6));
        Integer day = Integer.valueOf(dateStr.substring(6, 8));
        return Date.newInstance(year, month, day);
      }

      // Fallback: Format YYYY-MM-DD
      return Date.valueOf(dateStr.substring(0, 10));
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

  public static HttpResponse calloutApiWithHeaders(
    String endpoint,
    String method,
    Map<String,String> headers,
    String body
){
    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod(method);

    if(headers != null){
        for(String key : headers.keySet()){
            req.setHeader(key, headers.get(key));
        }
    }

    if(body != null){
        req.setBody(body);
    }

    req.setTimeout(120000);

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

  public static String formatTimestamp(Datetime timestamp ,String format) {
    return Datetime.valueOf(timestamp).format(format);
  }

  public static String decimalToString(Decimal d) {
    return d == null ? '' : d.format();
  }
  
  /**
   * Build help text map for any SObject type
   * @param sobjType - Schema.SObjectType
   * @return Map of field API name to help text
   */
  public static Map<String, String> buildHelpTextMap(Schema.SObjectType sobjType) {
    Map<String, String> m = new Map<String, String>();
    try {
      for (Schema.SObjectField f : sobjType.getDescribe().fields.getMap().values()) {
        Schema.DescribeFieldResult fieldDescribe = f.getDescribe();
        if (String.isNotBlank(fieldDescribe.getInlineHelpText())) {
          m.put(fieldDescribe.getName(), fieldDescribe.getInlineHelpText());
        }
      }
    } catch (Exception e) {
      System.debug('buildHelpTextMap error: ' + e.getMessage());
    }
    return m;
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

    // Passport: bắt đầu bằng chữ → 2 ký tự đầu + 3 ký tự cuối (theo quy định)
    if (s.length() >= 5 && Pattern.matches('^[A-Za-z].*', s)) {
      String first2 = s.substring(0, 2);
      String last3 = s.substring(s.length() - 3);
      String middle = '';
      for (Integer i = 2; i < s.length() - 3; i++) {
        middle += '*';
      }
      return first2 + middle + last3;
    }

    // CCCD: chỉ gồm số → 3 số đầu + 3 số cuối
    if (Pattern.matches('\\d+', s)) {
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
    Case selectedCase,
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
      FEC_Stage_Name__c = selectedCase.FEC_Current_Case_Stage__r?.Name,
      FEC_Action_Result__c = isSuccess ? 'Success' : 'Fail',
      FEC_User__c = userlst.get(0).Email.split('@')[0],
      FEC_User_Role__c = userlst.get(0).UserRole.Name,
      Case__c = selectedCase.Id
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

    public static String cleanResponseBody(String responseBody) {
        if (String.isBlank(responseBody)) {
            return responseBody;
        }
        
        responseBody = responseBody.trim();
        if (responseBody.startsWith('\uFEFF')) {
            responseBody = responseBody.substring(1);
        }
        while (responseBody.length() > 0 && !responseBody.startsWith('<')) {
            responseBody = responseBody.substring(1);
        }
        return responseBody;
    }

  public static String normalizeInsuranceFlag(String value) {
    if (String.isBlank(value)) return null;

    value = value.trim().toUpperCase();

    switch on value {
        when 'Y', 'YES' { 
            return 'Yes'; 
        }
        when 'N', 'NO' { 
            return 'No'; 
        }
        when else { 
            return null; 
        }
    }
  }

  public static String checkEcomFlag(Boolean eComFlag) {
    if (eComFlag == true) {
        return 'Inactive';
    }
    return 'Active';
  }

  public static String checkActiveAndInacive(String cardStatus) {
    if (cardStatus == 'Y') {
        return 'Active';
    }
    return 'Inactive';
  }

  public static Date toDateStr(String v) {
    if (String.isBlank(v)) return null;

    v = v.trim();

    try {

        // Format: yyyy-MM-dd
        if (v.contains('-')) {
            return Date.valueOf(v);
        }

        // Format: dd/MM/yyyy
        if (v.contains('/')) {
            List<String> parts = v.split('/');
            Integer day = Integer.valueOf(parts[0]);
            Integer month = Integer.valueOf(parts[1]);
            Integer year = Integer.valueOf(parts[2]);
            return Date.newInstance(year, month, day);
        }

    } catch (Exception e) {
        System.debug('Invalid date: ' + v);
    }

    return null;
  }

  /**
   * Format address 
   */
  public static String formatAddress(
    String numberStr,
    String building,
    String street,
    String ward,
    String district,
    String city,
    String countryName,
    String zipCode
  ) {
    List<String> parts = new List<String>();

    if (!String.isBlank(numberStr)) parts.add(numberStr);
    if (!String.isBlank(building)) parts.add(building);
    if (!String.isBlank(street)) parts.add(street);
    if (!String.isBlank(ward)) parts.add(ward);
    if (!String.isBlank(district)) parts.add(district);
    if (!String.isBlank(city)) parts.add(city);
    if (!String.isBlank(countryName)) parts.add(countryName);
    if (!String.isBlank(zipCode)) parts.add(zipCode);

    return String.join(parts, ', ');
  }

  public static Boolean checkLength(String fieldName, String value, Integer length) {
    if (String.isNotBlank(value) && value.length() > length) {
      return false;
    }
    return true;
  }

  public static void addTextNodeSafe(Dom.XmlNode parent, String tagName, String value) {
    parent.addChildElement(tagName, null, null)
      .addTextNode(value == null ? '' : value);
  }

  public static void logApi(
    String apiName,
    String endpoint,
    String method,
    String requestBody,
    HttpResponse response,
    String errorMessage
  ){
    Boolean isSuccess = (response.getStatusCode() == 200);
    String statusCode =  String.valueOf(response.getStatusCode());
    String responseBody = response.getBody();
    try {
      FEC_API_Log__c log = new FEC_API_Log__c();

      log.Name = apiName;
      log.FEC_Endpoint__c = endpoint;
      log.FEC_Method__c = method;
      log.FEC_Request_String__c = requestBody;
      log.FEC_Status_Code__c =  statusCode;
      log.FEC_Response_String__c = responseBody;
      log.FEC_Is_Success__c = isSuccess;
      log.FEC_Error_Message__c = errorMessage;

      insert log;

    } catch(Exception e) {
      System.debug('LOG INSERT ERROR: ' + e.getMessage());
    }
  }

  public static String getFieldType(String objectName, String fieldName) {
    try {

        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
        if (sObjectType == null) return null;
        Schema.DescribeSObjectResult objDescribe = sObjectType.getDescribe();
        Schema.SObjectField fieldToken = objDescribe.fields.getMap().get(fieldName);
        if (fieldToken == null) return null;
        Schema.DisplayType t = fieldToken.getDescribe().getType();
        switch on t {
            when Picklist {
                return FEC_ConstantCommon.KEY_PICKLIST;
            }
            when Boolean {
                return FEC_ConstantCommon.KEY_CHECKBOX;
            }
            when Date {
                return FEC_ConstantCommon.KEY_DATE;
            }
            when DateTime {
                return FEC_ConstantCommon.KEY_DATETIME;
            }
            when Integer, Double {
                return FEC_ConstantCommon.KEY_NUMBER;
            }
            when else {
                return FEC_ConstantCommon.KEY_TEXT;
            }
        }
    } catch (Exception e) {
        System.debug('getFieldType error: ' + e.getMessage());
        return null;
    }
  }

  public static Integer toInt(Decimal d) {
    return d == null ? null : Integer.valueOf(d);
  }

  public static String getFieldLabel(String objectName, String fieldName) {
    try {
        Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectName);
        if (sObjectType == null) return null;

        Schema.DescribeSObjectResult objDescribe = sObjectType.getDescribe();
        Schema.SObjectField fieldToken = objDescribe.fields.getMap().get(fieldName);
        if (fieldToken == null) return null;

        return fieldToken.getDescribe().getLabel();
    } catch (Exception e) {
        System.debug('getFieldLabel error: ' + e.getMessage());
        return null;
    }
  }
  public static List<FEC_GetCSMasterDataService.AvailableValueType> mapToAvailableValues(
      List<PicklistOption> options
  ) {
      List<FEC_GetCSMasterDataService.AvailableValueType> result =
          new List<FEC_GetCSMasterDataService.AvailableValueType>();

      for (PicklistOption opt : options) {
          FEC_GetCSMasterDataService.AvailableValueType v =
              new FEC_GetCSMasterDataService.AvailableValueType();
          v.ID = opt.value;
          v.Name = opt.label;
          v.NameVN = opt.label;
          result.add(v);
      }

      return result;
  }
  public static String escapeXml(String s) {
    if (s == null)
      return '';
    return s.replace('&', '&amp;')
      .replace('<', '&lt;')
      .replace('>', '&gt;')
      .replace('"', '&quot;')
      .replace('\'', '&apos;');
  }

}