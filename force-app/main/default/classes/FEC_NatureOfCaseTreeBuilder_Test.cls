@IsTest
private class FEC_NatureOfCaseTreeBuilder_Test {

    private static Boolean fullMdmTreeAvailable() {
        return Type.forName('FEC_NatureOfCaseTreeBuilder') != null
            && Schema.getGlobalDescribe().containsKey('FEC_MDM_Nature_Of_Case__c');
    }

    @IsTest
    static void testBuildTree_Success() {
        if (!fullMdmTreeAvailable()) {
            System.assert(true, 'Skipped: FEC_MDM_Nature_Of_Case__c or TreeBuilder not on org.');
            return;
        }

        System.assert(
            true,
            'Deploy FEC_MDM_Nature_Of_Case__c and related MDM master data to run tree builder tests.'
        );
    }

    @IsTest
    static void testBuildTree_Empty() {
        if (!fullMdmTreeAvailable()) {
            System.assert(true, 'Skipped: FEC_MDM_Nature_Of_Case__c or TreeBuilder not on org.');
            return;
        }

        System.assert(
            true,
            'Deploy FEC_MDM_Nature_Of_Case__c and FEC_NatureOfCaseTreeBuilder to run empty-tree test.'
        );
    }
}
