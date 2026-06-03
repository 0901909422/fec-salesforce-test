/**
 * Trigger Description: Case trigger delegate to Handler class
 * @created  : 2026/01/03 Toannd61
 * @modified : 2026/01/16
 */
trigger FEC_CaseTrigger on Case (before insert, before update, after insert, after update) {
    List<Case> listCase = new List<Case>();
    filterCase(listCase, (List<Case>) Trigger.new);
    if (!listCase.isEmpty()) FEC_CaseTriggerHandler.run();

    /*------------------------------------------------------------
    Author:        Thanh Van
    Company:       Amaris
    Description:   Filter Case
    History
    <Date>          <Authors Name>      <Brief Description of Change>
    2026/04/07      Thanh Van           Init
    ------------------------------------------------------------*/
    public static void filterCase(List<Case> listCase, List<Case> newCases){
        for (Case caseIns : newCases) {
            if (String.isBlank(caseIns.ArchiveExternalId__c)) {
                listCase.add(caseIns);
            }
        }
    }
}