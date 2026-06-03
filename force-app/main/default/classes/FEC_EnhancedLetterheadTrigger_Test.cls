@IsTest
private class FEC_EnhancedLetterheadTrigger_Test {

    private static FEC_Enhanced_Letterhead__c insertLetterhead(String nameValue) {
        FEC_Enhanced_Letterhead__c row = new FEC_Enhanced_Letterhead__c(
            Name = nameValue,
            FEC_Header__c = 'Header',
            FEC_Footer__c = 'Footer'
        );
        insert row;
        return row;
    }

    private static FEC_Template__c insertTemplate(
        Id letterheadId,
        Boolean isActive,
        String nameValue
    ) {
        FEC_Template__c template = new FEC_Template__c(
            Name = nameValue,
            FEC_Enhanced_Letterhead__c = letterheadId,
            FEC_Active__c = isActive
        );
        insert template;
        return template;
    }

    @IsTest
    static void testBeforeInsertAndUpdate() {
        FEC_Enhanced_Letterhead__c row = insertLetterhead('Trigger Insert UT');

        Test.startTest();
        row.FEC_Header__c = 'Updated Header';
        update row;
        Test.stopTest();

        FEC_Enhanced_Letterhead__c refreshed = [
            SELECT FEC_Header__c
            FROM FEC_Enhanced_Letterhead__c
            WHERE Id = :row.Id
            LIMIT 1
        ];
        System.assertEquals('Updated Header', refreshed.FEC_Header__c, 'before update should persist changes.');
    }

    @IsTest
    static void testBeforeDelete_blockedWhenActiveTemplate() {
        FEC_Enhanced_Letterhead__c row = insertLetterhead('Trigger Block Delete');
        insertTemplate(row.Id, true, 'Active Template');

        Boolean blocked = false;
        Test.startTest();
        try {
            delete row;
        } catch (DmlException ex) {
            blocked = ex.getMessage().contains(System.Label.FEC_Cannot_Delete_Enhanced_Letterhead);
        }
        Test.stopTest();

        System.assertEquals(
            true,
            blocked,
            'Trigger should block delete when an active template is linked.'
        );
    }

    @IsTest
    static void testBeforeDelete_allowedWhenNoActiveTemplate() {
        FEC_Enhanced_Letterhead__c row = insertLetterhead('Trigger Allow Delete');
        insertTemplate(row.Id, false, 'Inactive Template');

        Test.startTest();
        delete row;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Enhanced_Letterhead__c WHERE Id = :row.Id],
            'Trigger should allow delete when no active template is linked.'
        );
    }
}
