public without sharing class FEC_KYCController {
  public static final String BLOCK_CODE_1_Y = 'Y';
  public static final String PLASTIC_ID_DC2 = 'DC2';
  public static final String PLASTIC_ID_DP3 = 'DP3';
  public static final String CASE_INTERACTION = 'Interaction';
  // public static final String CASE_CUSTOMER = 'DP3';

  @AuraEnabled
  public static String getInterationId(String recordId) {
    try {
      List<Case> caselst = [
        SELECT Id, RecordTypeId, RecordType.DeveloperName, FEC_Interaction__c
        FROM Case
        WHERE Id = :recordId
      ];

      if (caselst.isEmpty())
        return null;

      Case selected = caselst.get(0);

      if (CASE_INTERACTION.equals(selected.RecordType.DeveloperName)) {
        return selected.Id;
      }

      return selected.FEC_Interaction__c;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static KYCDTO getKYC(String recordId) {
    try {
      KYCDTO result = new KYCDTO();

      List<Case> caselst = FEC_CaseService.getById(
        new Set<Id>{ (Id) recordId }
      );

      if (caselst.isEmpty())
        return result;

      Case c = caselst.get(0);
      result.kycType = c.FEC_KYC_Method__c;

      if (
        PLASTIC_ID_DC2.equals(c.FEC_Account_or_Contract__r.FEC_Plastic_ID__c)
      ) {
        if (
          !BLOCK_CODE_1_Y.equals(
            c.FEC_Account_or_Contract__r.FEC_Block_Code_1__c
          )
        )
          return result;
      }

      if (
        PLASTIC_ID_DP3.equals(c.FEC_Account_or_Contract__r.FEC_Plastic_ID__c)
      ) {
        List<FEC_Card_Delivery__c> cardDeliverylst = [
          SELECT
            Id,
            FEC_Customer_History__c,
            FEC_Card_Number__c,
            FEC_Delivery_Status__c,
            FEC_Delivery_Date__c
          FROM FEC_Card_Delivery__c
          WHERE
            FEC_Customer_History__c = :c.FEC_Account_or_Contract__c
            AND FEC_Card_Number__c = :c.FEC_Account_or_Contract__r.FEC_Card_Number__c
        ];

        if (cardDeliverylst.isEmpty())
          return result;

        if (
          cardDeliverylst.get(0).FEC_Delivery_Status__c != null ||
          cardDeliverylst.get(0).FEC_Delivery_Date__c != null
        )
          return result;
      }

      // 2. Cast and Check for Null (The "Cache Miss" pattern)
      Set<String> productTypelst = new Set<String>();

      if (String.isNotBlank(c.FEC_Search_Products__c)) {
        List<String> searchProdTypelst = c.FEC_Search_Products__c.split(';');
        productTypelst.addAll(searchProdTypelst);
      }

      if (productTypelst.isEmpty())
        return result;

      String plasticId = c.FEC_Account_or_Contract__r.FEC_Plastic_ID__c;

      List<FEC_KYC__c> kyclst = FEC_KYCService.getByMethodAndProdTypeAndPlastic(
        new Set<String>{ c.FEC_KYC_Method__c },
        productTypelst,
        new Set<String>{ plasticId }
      );

      if (kyclst.isEmpty())
        return result;

      List<FEC_KYC__c> selectedKYClst = new List<FEC_KYC__c>();

      for (FEC_KYC__c item : kyclst) {
        selectedKYClst.add(item);
      }

      List<FEC_KYC_Result__c> kycResultlst = FEC_KYCResultService.getByCase(
        new Set<Id>{ (Id) recordId }
      );

      Map<Id, FEC_KYC_Result__c> kycResultMap = new Map<Id, FEC_KYC_Result__c>();

      for (FEC_KYC_Result__c item : kycResultlst) {
        kycResultMap.put(item.FEC_KYC__c, item);
      }

      List<String> formulalst = new List<String>();

      for (FEC_KYC__c item : selectedKYClst) {
        formulalst.add(item.FEC_KYC_Suggested_Answer__c);
      }

      Set<String> fieldlst = FEC_CommonUltils.extractFieldPaths(formulalst);

      List<Case> caselst2 = FEC_CaseService.getById(
        new Set<Id>{ c.Id },
        fieldlst
      );

      c = caselst2.get(0);

      QuestionDTO temp;

      Map<String, List<QuestionDTO>> typeMap = new Map<String, List<QuestionDTO>>();
      Boolean isConfirmed;
      for (FEC_KYC__c item : selectedKYClst) {
        temp = new QuestionDTO();

        temp.id = item.Id;
        temp.name = item.Name;
        temp.suggestedAnswer = FEC_CommonUltils.resolveTemplate(
          item.FEC_KYC_Suggested_Answer__c,
          c
        );
        temp.isMasked = item.FEC_Masking__c;
        temp.fieldName = getToken(item.FEC_KYC_Suggested_Answer__c);

        isConfirmed = kycResultMap.containsKey(item.Id);

        if (isConfirmed) {
          temp.stage = kycResultMap.get(item.Id).FEC_Status__c
            ? 'true'
            : 'false';
          temp.isEditable = kycResultMap.get(item.Id).FEC_Editable__c;

          // temp.resultId = kycResultMap.get(item.Id).Id;
        }

        if (!typeMap.containsKey(item.FEC_Product_Type__r.Name)) {
          typeMap.put(item.FEC_Product_Type__r.Name, new List<QuestionDTO>());
        }

        typeMap.get(item.FEC_Product_Type__r.Name).add(temp);
      }

      result.typelst = new List<TypeDTO>();
      TypeDTO typeTemp;

      for (String key : typeMap.keySet()) {
        typeTemp = new TypeDTO();
        typeTemp.type = key;
        typeTemp.questions = typeMap.get(key);
        result.typelst.add(typeTemp);
      }

      return result;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static void submitKYC(
    String recordId,
    // String resultId,
    String kycId,
    Boolean checked,
    String answer
  ) {
    try {
      List<FEC_KYC__c> kyclst = [
        SELECT
          Id,
          FEC_KYC_Method__c,
          FEC_Product_Type__c,
          FEC_Product_Type__r.Name,
          FEC_KYC_Suggested_Answer__c,
          Name
        FROM FEC_KYC__c
        WHERE Id = :kycId
      ];

      if (kyclst.isEmpty())
        return;

      FEC_KYC_Result__c result = new FEC_KYC_Result__c(
        // Id = resultId,
        Name = kyclst.get(0).Name,
        FEC_Case_Interaction__c = recordId,
        FEC_KYC__c = kycId,
        FEC_Status__c = checked,
        FEC_KYC_Answer__c = answer,
        FEC_KYC_Product__c = kyclst.get(0).FEC_Product_Type__r.Name
      );

      upsert result;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  @AuraEnabled
  public static List<KYCResultDTO> getKYCResult(String caseId) {
    List<KYCResultDTO> result = new List<KYCResultDTO>();

    try {
      List<FEC_KYC_Result__c> resultlst = [
        SELECT
          FEC_Case_Interaction__c,
          FEC_Editable__c,
          FEC_KYC_Answer__c,
          FEC_KYC_Product__c,
          FEC_KYC_Result__c,
          FEC_KYC__c,
          Name,
          Id,
          CreatedDate
        FROM FEC_KYC_Result__c
        WHERE FEC_Case_Interaction__c = :caseId
        ORDER BY CreatedDate DESC
      ];

      KYCResultDTO resultTemp;

      for (FEC_KYC_Result__c item : resultlst) {
        resultTemp = new KYCResultDTO();

        resultTemp.productType = item.FEC_KYC_Product__c;
        resultTemp.question = item.Name;
        resultTemp.answer = item.FEC_KYC_Answer__c;
        resultTemp.result = item.FEC_KYC_Result__c;
        resultTemp.performedOn = item.CreatedDate?.format();

        result.add(resultTemp);
      }

      return result;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }

  private static String getToken(String input) {
    if (String.isBlank(input)) {
      return null;
    }

    Pattern p = Pattern.compile('\\{\\{(.*?)\\}\\}');
    Matcher m = p.matcher(input);

    return m.find() ? m.group(1) : null;
  }

  public class KYCDTO {
    @AuraEnabled
    public String kycType;

    @AuraEnabled
    public List<TypeDTO> typelst;

    public KYCDTO() {
      this.typelst = new List<TypeDTO>();
    }
  }

  public class TypeDTO {
    @AuraEnabled
    public String type;

    @AuraEnabled
    public List<QuestionDTO> questions;

    public TypeDTO() {
      this.questions = new List<QuestionDTO>();
    }
  }

  public class QuestionDTO {
    @AuraEnabled
    public String id;

    // @AuraEnabled
    // public String resultId;

    @AuraEnabled
    public String name;
    @AuraEnabled
    public String stage;
    @AuraEnabled
    public Boolean isEditable;
    @AuraEnabled
    public Boolean isMasked;
    @AuraEnabled
    public String suggestedAnswer;
    @AuraEnabled
    public String fieldName;

    public QuestionDTO() {
      this.isEditable = true;
    }
  }

  public class KYCResultDTO {
    @AuraEnabled
    public String productType;
    @AuraEnabled
    public String question;
    @AuraEnabled
    public String answer;
    @AuraEnabled
    public String result;
    @AuraEnabled
    public String performedOn;
  }
}