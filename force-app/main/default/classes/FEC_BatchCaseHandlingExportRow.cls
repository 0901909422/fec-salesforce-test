public without sharing class FEC_BatchCaseHandlingExportRow {
    @AuraEnabled public Id caseId;
    @AuraEnabled public String customerType;
    @AuraEnabled public String customerName;
    @AuraEnabled public String accountContractNumber;
    @AuraEnabled public String appId;
    @AuraEnabled public String contractStatus; // Toannd 28/5/2026
    @AuraEnabled public String productCode; // Toannd 28/5/2026
    @AuraEnabled public String loanAmount; // Toannd 28/5/2026
    @AuraEnabled public String tenure; // Toannd 28/5/2026
    @AuraEnabled public String interactionId;
    @AuraEnabled public String interactionChannel;
    @AuraEnabled public String interactionSubChannel;
    @AuraEnabled public String interactionPhone;
    @AuraEnabled public String interactionEmail;
    @AuraEnabled public String ippRecordNo; // Toannd 28/5/2026
    @AuraEnabled public String ippPlan; // Toannd 28/5/2026
    @AuraEnabled public String ippOpenDate; // Toannd 28/5/2026
    @AuraEnabled public String ippFirstDueDate; // Toannd 28/5/2026
    @AuraEnabled public String ippMatureDate; // Toannd 28/5/2026
    @AuraEnabled public String ippBalance; // Toannd 28/5/2026
    @AuraEnabled public String ippCurrentBalance; // Toannd 28/5/2026
    @AuraEnabled public String ippInterestRate; // Toannd 28/5/2026
    @AuraEnabled public String ippTerm; // Toannd 28/5/2026
    @AuraEnabled public String ippInsurance; // Toannd 28/5/2026
    @AuraEnabled public String ippCurrentTerm; // Toannd 28/5/2026
    @AuraEnabled public String caseIdSearch;
    @AuraEnabled public String categoryCode;
    @AuraEnabled public String subCategoryCode;
    @AuraEnabled public String subCodeCode;
    @AuraEnabled public String categoryDisplay;
    @AuraEnabled public String subCategoryDisplay;
    @AuraEnabled public String subCodeDisplay;
    @AuraEnabled public String originalCategoryDisplay;
    @AuraEnabled public String originalSubCategoryDisplay;
    @AuraEnabled public String originalSubCodeDisplay;
    @AuraEnabled public String complaintType;
    @AuraEnabled public String complaintSource;
    @AuraEnabled public String productType;
    @AuraEnabled public String caseRemarks;
    @AuraEnabled public String caseRemarksEnteredBy;
    @AuraEnabled public String caseRemarksEnteredByRole;
    @AuraEnabled public String caseRemarksEnteredOn;
    @AuraEnabled public String assignmentId;
    @AuraEnabled public String assignmentOwner;
    @AuraEnabled public String assignmentRemarks;
    @AuraEnabled public String assignmentRemarksEnteredBy;
    @AuraEnabled public String assignmentRemarksEnteredByRole;
    @AuraEnabled public String assignmentRemarksEnteredOn;
    @AuraEnabled public String caseStatus;
    @AuraEnabled public Datetime caseCreatedOn;
    @AuraEnabled public Datetime lastUpdatedOn;
    @AuraEnabled public String caseCreatedOnLabel;
    @AuraEnabled public String lastUpdatedOnLabel;
    @AuraEnabled public Boolean hasAttachment;
    @AuraEnabled public String hasAttachmentLabel;
    @AuraEnabled public String caseReviewUrl;
    @AuraEnabled public String businessProcessCode;
    @AuraEnabled public String businessProcessName;
    @AuraEnabled public String blockLimitDateLabel;
    @AuraEnabled public String blockLimitAmount;
    @AuraEnabled public String ccCode;
    @AuraEnabled public String ccName;
    @AuraEnabled public String dsaCode;
    @AuraEnabled public String dsaName;
    @AuraEnabled public String tsaCode;
    @AuraEnabled public String tsaName;
    @AuraEnabled public String salesChannel;
    @AuraEnabled public String salesSubChannel;
    @AuraEnabled public String classificationByCs;
    @AuraEnabled public String evaluationByCs;
    @AuraEnabled public String finalProduct;
    @AuraEnabled public String paymentContractAssessment; // Toannd 28/5/2026
    @AuraEnabled public String evaluationBySales;
    @AuraEnabled public String disciplineResult;
    @AuraEnabled public String contactPoint;
    @AuraEnabled public String teamLeader;
    @AuraEnabled public String supervisor;
    @AuraEnabled public String pendingCsSupportLabel;
    @AuraEnabled public String incorrectContractNumber;
    @AuraEnabled public String paymentMethod;
    @AuraEnabled public String billDate;
    @AuraEnabled public String billAmount;
    @AuraEnabled public String paymentDate;
    @AuraEnabled public String excessAmount;
    @AuraEnabled public String selectedContractNumber;
    @AuraEnabled public String correctContractNumber;
    @AuraEnabled public String correctAccountContract;
    @AuraEnabled public String adjustedAmount;
}