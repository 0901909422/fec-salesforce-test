/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Controller for ArchiveInteractionCaseRedirect VF page
                handles callout to get Interaction Case
Test Class:    ArchiveInteractionCaseController_Test
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/16     Thanh Van          Init
------------------------------------------------------------*/
public with sharing class ArchiveInteractionCaseController {

    @TestVisible private static List<AthenaCases__x> mockExternalRecords;
    public static Boolean isTestWithError = false;
    
    public String caseId { get; set; }
    public String errorMessage { get; set; }
    public Boolean hasError { get; set; }
    
    public ArchiveInteractionCaseController() {
        hasError = false;
        caseId = ApexPages.currentPage().getParameters().get('id');
    }
    
    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Fetch Interaction Case from archive and redirect
    Returns:       PageReference
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/16      Thanh Van           Init
    ------------------------------------------------------------*/
    public PageReference fetchAndRedirect() {
        try {
            if (isTestWithError) throw new NullPointerException();
            System.debug('caseId ' + caseId);

            if (String.isBlank(caseId)) {
                hasError = true;
                errorMessage = label.FEC_Toast_Error_Generic;
                return null;
            }
            
            // Get current Case
            List<Case> currentCases = [SELECT Id, ArchiveInteractionId__c, FEC_Interaction__c 
                                        FROM Case 
                                        WHERE Id = :caseId LIMIT 1];
            if (!currentCases.isEmpty()) {
                Case caseIns = currentCases[0];
                Id interactionCaseId;
                String archiveExternalInter = caseIns.ArchiveInteractionId__c;

                // Find Interaction Case
                List<Case> interractionCases = [SELECT Id FROM Case 
                                                WHERE ArchiveExternalId__c = :archiveExternalInter 
                                                LIMIT 1];
                if (!interractionCases.isEmpty()) {
                    interactionCaseId = interractionCases[0].Id;

                } else {
                    List<AthenaCases__x> archiveCases;
                    if (Test.isRunningTest() && mockExternalRecords != null) {
                        archiveCases = mockExternalRecords;
                    } else {
                        archiveCases = [SELECT Id, ExternalId, s3_path__c, 
                                        migration_source__c, case_id__c 
                                        FROM AthenaCases__x 
                                        WHERE case_id__c = :archiveExternalInter];

                        if (archiveCases.isEmpty()) {
                            hasError = true;
                            errorMessage = label.FEC_Toast_Error_Generic;
                            return null;
                        }
                        AthenaCases__x archiveCaseIns = archiveCases[0];
                        interactionCaseId = ArchiveCaseController.getCaseDetailAndCreateCaseTemp(archiveCaseIns);
                    }
                }

                if (interactionCaseId != null) {
                    // Id Current Case and interactionCaseId are the same Id
                    // It means it is the Interaction Case >> No need to update this field
                    if (caseIns.Id != interactionCaseId 
                        && String.isBlank(caseIns.FEC_Interaction__c)) {
                        // Update current Case with the Interaction reference
                        caseIns.FEC_Interaction__c = interactionCaseId;
                        update caseIns;
                    }

                    // Redirect to the Interaction Case
                    PageReference pageRef = new PageReference('/' + interactionCaseId);
                    pageRef.setRedirect(true);
                    return pageRef;
                } else {
                    hasError = true;
                    errorMessage = label.FEC_Toast_Error_Generic;
                    return null;
                }
            } else {
                hasError = true;
                errorMessage = label.FEC_Toast_Error_Generic;
                return null;
            }
        } catch (Exception ex) {
            hasError = true;
            errorMessage = 'Error: ' + ex.getMessage();
            System.debug('ArchiveInteractionCaseController error: ' + ex.getMessage() + '\n' + ex.getStackTraceString());
            return null;
        }
    }
}