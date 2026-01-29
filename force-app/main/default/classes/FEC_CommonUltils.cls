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
}