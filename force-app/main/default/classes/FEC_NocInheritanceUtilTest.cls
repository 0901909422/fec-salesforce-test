@IsTest
private class FEC_NocInheritanceUtilTest {

    @IsTest
    static void testAncestorWhenParentHasMoreNulls() {
        String suffix = String.valueOf(System.currentTimeMillis()).right(6);
        FEC_Product_Type__c pt = new FEC_Product_Type__c(
            Name = 'PT Util',
            FEC_Code__c = 'PTU' + suffix,
            FEC_Active__c = true
        );
        insert pt;
        FEC_Category__c cat = new FEC_Category__c(
            Name = 'Cat Util',
            FEC_Code__c = 'CATU' + suffix,
            FEC_Active__c = true
        );
        insert cat;
        FEC_Sub_Category__c subCat = new FEC_Sub_Category__c(
            Name = 'SC Util',
            FEC_Code__c = 'SCU' + suffix,
            FEC_Active__c = true
        );
        insert subCat;
        FEC_Sub_Code__c subCode = new FEC_Sub_Code__c(
            Name = 'SCODE Util',
            FEC_Code__c = 'SCOU' + suffix,
            FEC_Active__c = true
        );
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
        insert parent;
        insert child;

        System.assert(FEC_NocInheritanceUtil.isAncestorOf(parent, child));
        System.assert(FEC_NocInheritanceUtil.specificityScore(parent)
            < FEC_NocInheritanceUtil.specificityScore(child));
    }
}
