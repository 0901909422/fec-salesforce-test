@IsTest
private class FEC_NocInheritanceUtilTest {

    @IsTest
    static void testAncestorWhenParentHasMoreNulls() {
        FEC_Product_Type__c pt = new FEC_Product_Type__c(Name = 'PT Util');
        insert pt;
        FEC_Category__c cat = new FEC_Category__c(Name = 'Cat Util');
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(Name = 'SC Util');
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(Name = 'SCODE Util');
        insert subCode;

        FEC_Nature_of_Case__c parent = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Active__c = true
        );
        FEC_Nature_of_Case__c child = new FEC_Nature_of_Case__c(
            FEC_Product_Type__c = pt.Id,
            FEC_Category__c = cat.Id,
            FEC_Sub_Category__c = subCat.Id,
            FEC_Sub_Code__c = subCode.Id,
            FEC_Active__c = true
        );

        System.assert(FEC_NocInheritanceUtil.isAncestorOf(parent, child));
        System.assert(FEC_NocInheritanceUtil.specificityScore(parent)
            < FEC_NocInheritanceUtil.specificityScore(child));
    }
}
