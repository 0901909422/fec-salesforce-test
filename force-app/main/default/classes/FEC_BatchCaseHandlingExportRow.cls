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
    // 15/06/2026 14:30 linhdev - Phone Update export: Original/Updated Info Phone Number (PhoneUpdateTemp1/Temp2)
    @AuraEnabled public String originalInfoPhoneNumber;
    @AuraEnabled public String updatedInfoPhoneNumber;
    // 15/06/2026 linhdev - Address Update export: Original/Updated Info từ FEC_Address_Info__c (AddressUpdateTemp1_CSSupport)
    // Updated: FEC_Address_Info__c gắn Case, FEC_Parent_Address__c khác null. Original: record parent theo Parent ID.
    @AuraEnabled public String originalInfoAddressType;
    @AuraEnabled public String originalInfoAddress;
    @AuraEnabled public String originalInfoMailingAddress;
    @AuraEnabled public String updatedInfoAddressType;
    @AuraEnabled public String updatedInfoAddress;
    @AuraEnabled public String updatedInfoMailingAddress;
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
    // Toannd 11/06/2026 - Case Remarks gom (extended filter) cho GSR/COF Temp2/Temp8_CA/OtherCS
    @AuraEnabled public String caseRemarksExtended;
    @AuraEnabled public String caseRemarksEnteredByExtended;
    @AuraEnabled public String caseRemarksEnteredByRoleExtended;
    @AuraEnabled public String caseRemarksEnteredOnExtended;
    // Toannd 11/06/2026 - export đủ Case Remarks theo từng remark (GSRTemp2_OtherCS)
    @AuraEnabled public String caseRemarks1;
    @AuraEnabled public String caseRemarksEnteredBy1;
    @AuraEnabled public String caseRemarksEnteredByRole1;
    @AuraEnabled public String caseRemarksEnteredOn1;
    @AuraEnabled public String caseRemarks2;
    @AuraEnabled public String caseRemarksEnteredBy2;
    @AuraEnabled public String caseRemarksEnteredByRole2;
    @AuraEnabled public String caseRemarksEnteredOn2;
    @AuraEnabled public String caseRemarks3;
    @AuraEnabled public String caseRemarksEnteredBy3;
    @AuraEnabled public String caseRemarksEnteredByRole3;
    @AuraEnabled public String caseRemarksEnteredOn3;
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
    // 16/06/2026 toannd - Contract Closure export (ContractClosureTemp2_CSSupport Level Case info)
    @AuraEnabled public String deliveryOption;
    @AuraEnabled public String recipientName;
    @AuraEnabled public String recipientPhoneNumber;
    @AuraEnabled public String closureAddress;
    @AuraEnabled public String temporaryAddress;
    @AuraEnabled public String closureEmail;
    @AuraEnabled public String temporaryEmail;
    // 24/06/2026 linhdev - Refund Request (Loan) export (RefundLoanTemp1_PM Level Case info)
    @AuraEnabled public String refundAmount;
    @AuraEnabled public String receiptDate;
    @AuraEnabled public String receiptAmount;
    @AuraEnabled public String transactionNo;
    @AuraEnabled public String paymentChannel;
    @AuraEnabled public String receiptDate2;
    @AuraEnabled public String receiptAmount2;
    @AuraEnabled public String transactionNo2;
    @AuraEnabled public String paymentChannel2;
    @AuraEnabled public String beneficiaryName;
    @AuraEnabled public String beneficiaryAccount;
    @AuraEnabled public String bankName;
    @AuraEnabled public String bankBranch;
    @AuraEnabled public String provinceCity;
    @AuraEnabled public String verifyInformation;
    @AuraEnabled public String callback;
    @AuraEnabled public String relatedCaseId;
    @AuraEnabled public String customerProvidedInfo;
    // 24/06/2026 linhdev - Card Unblock/Phone Update D2C/Card Replacement export (account/card block)
    @AuraEnabled public String accountStatus;
    @AuraEnabled public String plasticId;
    @AuraEnabled public String creditLimit;
    @AuraEnabled public String blockCode1;
    @AuraEnabled public String blockCode2;
    @AuraEnabled public String blockCode;
    @AuraEnabled public String daysPastDue;
    // 24/06/2026 linhdev - Card Replacement export (CardReplacementTemp1/Temp2)
    @AuraEnabled public String cardReplacementReason;
    @AuraEnabled public String newBlockCodeCardReplace;
    // 24/06/2026 linhdev - Point Redemption export (PointsRedemptionTemp1_CSSupport)
    @AuraEnabled public String availablePoints;
    @AuraEnabled public String redeemedPoints;
    // 24/06/2026 linhdev - Original MRC Return export (MRCReturnTemp1/Temp2)
    @AuraEnabled public String mrcZone;
    @AuraEnabled public String mrcArea;
    @AuraEnabled public String plateNumber;
    @AuraEnabled public String mrcStatus;
    @AuraEnabled public String mrcStatusId;
    @AuraEnabled public String mrcId;
    @AuraEnabled public String mrcRemark;
    @AuraEnabled public String mrcModifiedDate;
    @AuraEnabled public String mrcDeliveryDate;
    @AuraEnabled public String mrcReceivedDate;
    @AuraEnabled public String mrcReceiver;
    @AuraEnabled public String customerConfirmation;
}