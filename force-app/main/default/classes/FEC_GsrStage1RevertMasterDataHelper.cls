/**
 * GSR Stage 1 sau Revert: bổ sung dòng Master Data LWC Original Info từ Stage 2 vào danh sách Stage 1.
 */
public without sharing class FEC_GsrStage1RevertMasterDataHelper {
  private static final String TYPE_LWC = 'LWC';

  private FEC_GsrStage1RevertMasterDataHelper() {
  }

  /**
   * Master Data Stage 1 thường không có LWC Original Info (chỉ cấu hình ở Stage 2).
   * Lấy dòng FEC_Sub_Section__c = Original Info, FEC_Type__c = LWC từ Stage 2 cùng bộ NOC rồi chèn vào masterDatalst.
   */
  public static void appendStage2OriginalInfoLwc(
    List<SObject> masterDatalst,
    String masterDataSettingObj,
    String natureOfCaseFieldApi,
    String natureOfCaseId,
    Id templateNatureIdForCaseStages
  ) {
    if (masterDatalst == null || String.isBlank(natureOfCaseId)) {
      return;
    }
    for (SObject existing : masterDatalst) {
      if (
        FEC_ConstantCommon.ORIGINAL_INFO.equals(
          (String) existing.get('FEC_Sub_Section__c')
        ) &&
        TYPE_LWC.equals((String) existing.get('FEC_Type__c'))
      ) {
        return;
      }
    }
    Id stage2Id = resolveCaseStageIdForNatureByNameFragment(
      templateNatureIdForCaseStages,
      FEC_ConstantCommon.STAGE_TWO
    );
    if (stage2Id == null) {
      return;
    }
    SObject stage2OriginalInfoLwc = queryOriginalInfoLwcMasterDataRow(
      masterDataSettingObj,
      natureOfCaseFieldApi,
      natureOfCaseId,
      stage2Id
    );
    if (stage2OriginalInfoLwc == null) {
      return;
    }
    insertMasterDataRowInDisplayOrder(masterDatalst, stage2OriginalInfoLwc);
  }

  private static Id resolveCaseStageIdForNatureByNameFragment(
    Id templateNatureId,
    String stageNameFragment
  ) {
    if (templateNatureId == null || String.isBlank(stageNameFragment)) {
      return null;
    }
    String stageNamePattern = '%' + stageNameFragment + '%';
    List<FEC_Case_Stage__c> stageLst = [
      SELECT Id
      FROM FEC_Case_Stage__c
      WHERE
        FEC_Nature_of_Cases__c = :templateNatureId
        AND FEC_Active__c = TRUE
        AND Name LIKE :stageNamePattern
      ORDER BY Name
      LIMIT 1
    ];
    return stageLst.isEmpty() ? null : stageLst[0].Id;
  }

  private static SObject queryOriginalInfoLwcMasterDataRow(
    String masterDataSettingObj,
    String natureOfCaseFieldApi,
    String natureOfCaseId,
    Id stageId
  ) {
    String fieldsSoql =
      'Id, FEC_Field_API_Name__c, FEC_Field_Editable__c, ' +
      'FEC_Field_Mandatory__c, FEC_Field_Object_Name__c, ' +
      'FEC_Field_ReadOnly__c, FEC_Section__c, FEC_Field_Order_Display__c,' +
      'FEC_Field_Label_Name__c, FEC_Editable_User_Group__c, FEC_Field_Masking__c, FEC_Masking_Type__c, ' +
      'FEC_Sub_Section__c, FEC_Sub_Section_Order__c, FEC_Sub_Section_Layout__c, FEC_Field_Reverted__c, FEC_Sub_Section_Field_Layout__c, ' +
      'FEC_LWC_Name__c, FEC_Type__c, FEC_Hidden__c';
    String rowSoql =
      'SELECT ' +
      fieldsSoql +
      ' FROM ' +
      masterDataSettingObj +
      ' WHERE ' +
      natureOfCaseFieldApi +
      ' = :natureOfCaseId ' +
      'AND FEC_Stage_Name__c = :stageId ' +
      'AND FEC_Sub_Section__c = \'' +
      String.escapeSingleQuotes(FEC_ConstantCommon.ORIGINAL_INFO) +
      '\' ' +
      'AND FEC_Type__c = \'LWC\' ' +
      'AND FEC_Field_Status__c = TRUE ' +
      'LIMIT 1';
    List<SObject> rows = Database.queryWithBinds(
      rowSoql,
      new Map<String, Object>{
        'natureOfCaseId' => natureOfCaseId,
        'stageId' => stageId
      },
      AccessLevel.USER_MODE
    );
    return rows.isEmpty() ? null : rows[0];
  }

  private static void insertMasterDataRowInDisplayOrder(
    List<SObject> masterDatalst,
    SObject rowToInsert
  ) {
    Integer insertAt = masterDatalst.size();
    for (Integer i = 0; i < masterDatalst.size(); i++) {
      if (compareMasterDataDisplayOrder(rowToInsert, masterDatalst[i]) < 0) {
        insertAt = i;
        break;
      }
    }
    masterDatalst.add(insertAt, rowToInsert);
  }

  private static Integer compareMasterDataDisplayOrder(SObject left, SObject right) {
    Integer sectionCmp = compareStringNullsLast(
      (String) left.get('FEC_Section__c'),
      (String) right.get('FEC_Section__c')
    );
    if (sectionCmp != 0) {
      return sectionCmp;
    }
    Integer orderCmp = compareDecimalNullsLast(
      (Decimal) left.get('FEC_Sub_Section_Order__c'),
      (Decimal) right.get('FEC_Sub_Section_Order__c')
    );
    if (orderCmp != 0) {
      return orderCmp;
    }
    Integer subSectionCmp = compareStringNullsLast(
      (String) left.get('FEC_Sub_Section__c'),
      (String) right.get('FEC_Sub_Section__c')
    );
    if (subSectionCmp != 0) {
      return subSectionCmp;
    }
    Integer objectCmp = compareStringNullsLast(
      (String) left.get('FEC_Field_Object_Name__c'),
      (String) right.get('FEC_Field_Object_Name__c')
    );
    if (objectCmp != 0) {
      return objectCmp;
    }
    return compareDecimalNullsLast(
      (Decimal) left.get('FEC_Field_Order_Display__c'),
      (Decimal) right.get('FEC_Field_Order_Display__c')
    );
  }

  private static Integer compareStringNullsLast(String left, String right) {
    if (left == right) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return left.compareTo(right);
  }

  private static Integer compareDecimalNullsLast(Decimal left, Decimal right) {
    if (left == right) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }
    return left < right ? -1 : (left > right ? 1 : 0);
  }
}
