//PhongBT 02/06/26: Kiểm tra tên file import khớp chính xác tên file export (template bind BP + user group).
public with sharing class FEC_BCH_ImportFileNameValidator {

  public static final String ERR_FILE_NAME_MISMATCH =
    'Tên file không khớp template Bulk Actions của quy trình và nhóm người dùng.';
  public static final String ERR_SELECT_ONE_BUSINESS_PROCESS =
    'Vui lòng chọn đúng một quy trình trước khi import.';
  private static final String XLSX = '.xlsx';

  public class ValidationResult {
    @AuraEnabled public Boolean valid;
    @AuraEnabled public String message;
    @AuraEnabled public String expectedTemplateName;
  }

  @AuraEnabled
  public static ValidationResult validateImportFileNameAura(
    String fileName,
    String businessProcessCode,
    String businessProcessName,
    String clientTemplateName,
    Integer selectedBusinessProcessCount
  ) {
    ValidationResult out = new ValidationResult();
    out.valid = false;
    String error = validateForImport(
      fileName,
      businessProcessCode,
      businessProcessName,
      clientTemplateName,
      selectedBusinessProcessCount
    );
    out.message = error;
    out.valid = String.isBlank(error);
    out.expectedTemplateName = resolveExpectedTemplateName(
      fileName,
      businessProcessCode,
      businessProcessName,
      selectedBusinessProcessCount
    );
    return out;
  }

  public static String validateForImport(
    String fileName,
    String businessProcessCode,
    String businessProcessName,
    String clientTemplateName
  ) {
    return validateForImport(
      fileName,
      businessProcessCode,
      businessProcessName,
      clientTemplateName,
      null
    );
  }

  public static String validateForImport(
    String fileName,
    String businessProcessCode,
    String businessProcessName,
    String clientTemplateName,
    Integer selectedBusinessProcessCount
  ) {
    if (String.isBlank(fileName)) {
      return FEC_ConstantCommon.STR_EMPTY;
    }
    if (selectedBusinessProcessCount != null && selectedBusinessProcessCount > 1) {
      return ERR_SELECT_ONE_BUSINESS_PROCESS;
    }
    String expected = resolveExpectedTemplateName(
      businessProcessCode,
      businessProcessName,
      clientTemplateName,
      selectedBusinessProcessCount
    );
    if (String.isBlank(expected)) {
      return ERR_FILE_NAME_MISMATCH;
    }
    return validateExactFileNameMatch(fileName, expected) ? null : ERR_FILE_NAME_MISMATCH;
  }

  public static Boolean validateExactFileNameMatch(String fileName, String expectedTemplateName) {
    if (String.isBlank(fileName) || String.isBlank(expectedTemplateName)) {
      return false;
    }
    return normalizeFileCore(fileName) == normalizeFileCore(expectedTemplateName);
  }

  public static String normalizeFileCore(String name) {
    if (String.isBlank(name)) {
      return FEC_ConstantCommon.STR_EMPTY;
    }
    return name.trim().toLowerCase().replace(XLSX, FEC_ConstantCommon.STR_EMPTY);
  }

  public static String resolveExpectedTemplateName(
    String businessProcessCode,
    String businessProcessName,
    String clientTemplateName,
    Integer selectedBusinessProcessCount
  ) {
    if (selectedBusinessProcessCount != null && selectedBusinessProcessCount > 1) {
      return null;
    }
    String userGroup = resolveCurrentUserGroup();
    List<SObject> templateRows = FEC_BatchCaseHandlingTemplateHelper.queryActiveBatchCaseHandlingTemplates();
    if (String.isNotBlank(businessProcessCode) || String.isNotBlank(businessProcessName)) {
      return resolveBindingTemplateName(
        businessProcessCode,
        businessProcessName,
        userGroup,
        templateRows
      );
    }
    return resolveUniqueTemplateNameFromFileAmongBindings(
      clientTemplateName,
      userGroup,
      templateRows
    );
  }

  private static String resolveBindingTemplateName(
    String businessProcessCode,
    String businessProcessName,
    String userGroup,
    List<SObject> templateRows
  ) {
    if (templateRows == null || templateRows.isEmpty()) {
      return FEC_ConstantCommon.STR_EMPTY;
    }
    if (String.isBlank(businessProcessCode) && String.isBlank(businessProcessName)) {
      return FEC_ConstantCommon.STR_EMPTY;
    }
    Map<Id, String> urlByTemplateId = new Map<Id, String>();
    Map<Id, Id> versionIdByTemplateId = new Map<Id, Id>();
    Set<Id> templateIds = new Set<Id>();
    for (SObject row : templateRows) {
      templateIds.add((Id) row.get('Id'));
    }
    if (!templateIds.isEmpty()) {
      FEC_BatchCaseHandlingTemplateHelper.populateTemplateContentVersionMaps(
        templateIds,
        versionIdByTemplateId,
        urlByTemplateId
      );
    }
    FEC_BatchCaseHandlingTemplateHelper.TemplateExportBinding binding =
      FEC_BatchCaseHandlingTemplateHelper.resolveExportTemplateBinding(
        businessProcessCode,
        businessProcessName,
        userGroup,
        templateRows,
        versionIdByTemplateId,
        urlByTemplateId
      );
    if (
      binding == null ||
      !FEC_BatchCaseHandlingTemplateHelper.hasExportTemplateBinding(binding)
    ) {
      return FEC_ConstantCommon.STR_EMPTY;
    }
    return binding.templateName.trim();
  }

  private static String resolveUniqueTemplateNameFromFileAmongBindings(
    String fileName,
    String userGroup,
    List<SObject> templateRows
  ) {
    if (String.isBlank(fileName) || templateRows == null || templateRows.isEmpty()) {
      return FEC_ConstantCommon.STR_EMPTY;
    }
    String fileCore = normalizeFileCore(fileName);
    List<String> matched = new List<String>();
    for (SObject row : templateRows) {
      if (!FEC_BatchCaseHandlingTemplateHelper.importTemplateRowMatchesUserGroup(row, userGroup)) {
        continue;
      }
      String name = row.get('Name') == null
        ? FEC_ConstantCommon.STR_EMPTY
        : String.valueOf(row.get('Name')).trim();
      if (String.isBlank(name)) {
        continue;
      }
      if (normalizeFileCore(name) == fileCore) {
        matched.add(name);
      }
    }
    if (matched.size() == 1) {
      return matched[0];
    }
    return FEC_ConstantCommon.STR_EMPTY;
  }

  private static String resolveCurrentUserGroup() {
    Map<String, Schema.SObjectField> userFields = User.SObjectType.getDescribe().fields.getMap();
    if (!userFields.containsKey('FEC_User_Group__c')) {
      return FEC_ConstantCommon.STR_EMPTY;
    }
    User u = [
      SELECT FEC_User_Group__c
      FROM User
      WHERE Id = :UserInfo.getUserId()
      LIMIT 1
    ];
    return String.isBlank(u.FEC_User_Group__c)
      ? FEC_ConstantCommon.STR_EMPTY
      : u.FEC_User_Group__c.trim();
  }
}
