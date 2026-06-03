/**
 * Unit tests for FEC_AdditionalFieldValueTriggerHandler
 * (duplicate FEC_Code__c per FEC_Additional_Field__c parent).
 */
@IsTest
private class FEC_AddiFieldValueTriggerHandler_Test {

    private static FEC_MDM_Additional_Field__c insertParent() {
        String code = 'AF-' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        FEC_MDM_Additional_Field__c parent = new FEC_MDM_Additional_Field__c(
            Name = code,
            FEC_Code__c = code
        );
        insert parent;
        return parent;
    }

    private static FEC_MDM_Additional_Field_List_Value__c buildListValue(Id parentId, String listCode) {
        return new FEC_MDM_Additional_Field_List_Value__c(
            FEC_Additional_Field__c = parentId,
            FEC_Code__c = listCode,
            FEC_Name_VN__c = 'Name-' + listCode
        );
    }

    @IsTest
    static void handleBeforeInsert_uniqueCodes_noErrors() {
        FEC_MDM_Additional_Field__c parent = insertParent();
        FEC_MDM_Additional_Field_List_Value__c first = buildListValue(parent.Id, 'CODE-A');
        FEC_MDM_Additional_Field_List_Value__c second = buildListValue(parent.Id, 'CODE-B');

        FEC_AdditionalFieldValueTriggerHandler.handleBeforeInsert(
            new List<FEC_MDM_Additional_Field_List_Value__c>{ first, second }
        );

        System.assertEquals(0, first.getErrors().size(), 'Unique code must not error.');
        System.assertEquals(0, second.getErrors().size(), 'Unique code must not error.');
    }

    @IsTest
    static void handleBeforeInsert_duplicateInSameBatch_addsError() {
        FEC_MDM_Additional_Field__c parent = insertParent();
        FEC_MDM_Additional_Field_List_Value__c first = buildListValue(parent.Id, 'DUP-TX');
        FEC_MDM_Additional_Field_List_Value__c second = buildListValue(parent.Id, 'DUP-TX');

        FEC_AdditionalFieldValueTriggerHandler.handleBeforeInsert(
            new List<FEC_MDM_Additional_Field_List_Value__c>{ first, second }
        );

        System.assertEquals(0, first.getErrors().size(), 'First row in batch should pass.');
        System.assertEquals(false, second.getErrors().isEmpty(),
            'Second duplicate in same transaction must addError on FEC_Code__c.');
    }

    @IsTest
    static void handleBeforeInsert_duplicateAgainstDatabase_addsError() {
        FEC_MDM_Additional_Field__c parent = insertParent();
        insert buildListValue(parent.Id, 'DB-DUP');

        FEC_MDM_Additional_Field_List_Value__c incoming = buildListValue(parent.Id, 'DB-DUP');
        FEC_AdditionalFieldValueTriggerHandler.handleBeforeInsert(
            new List<FEC_MDM_Additional_Field_List_Value__c>{ incoming }
        );

        System.assertEquals(false, incoming.getErrors().isEmpty(),
            'Code already on parent in DB must addError.');
    }

    @IsTest
    static void handleBeforeInsert_blankCodeOrNullParent_skipsValidation() {
        FEC_MDM_Additional_Field__c parent = insertParent();
        FEC_MDM_Additional_Field_List_Value__c noCode = new FEC_MDM_Additional_Field_List_Value__c(
            FEC_Additional_Field__c = parent.Id,
            FEC_Name_VN__c = 'No code'
        );
        FEC_MDM_Additional_Field_List_Value__c noParent = new FEC_MDM_Additional_Field_List_Value__c(
            FEC_Code__c = 'ORPHAN'
        );

        FEC_AdditionalFieldValueTriggerHandler.handleBeforeInsert(
            new List<FEC_MDM_Additional_Field_List_Value__c>{ noCode, noParent }
        );

        System.assertEquals(0, noCode.getErrors().size());
        System.assertEquals(0, noParent.getErrors().size());
    }

    @IsTest
    static void handleBeforeUpdate_unchangedCode_noErrors() {
        FEC_MDM_Additional_Field__c parent = insertParent();
        FEC_MDM_Additional_Field_List_Value__c existing = buildListValue(parent.Id, 'SAME-UP');
        insert existing;

        FEC_MDM_Additional_Field_List_Value__c oldRow = new FEC_MDM_Additional_Field_List_Value__c(
            Id = existing.Id,
            FEC_Code__c = existing.FEC_Code__c,
            FEC_Additional_Field__c = existing.FEC_Additional_Field__c
        );
        FEC_MDM_Additional_Field_List_Value__c updated = new FEC_MDM_Additional_Field_List_Value__c(
            Id = existing.Id,
            FEC_Code__c = existing.FEC_Code__c,
            FEC_Additional_Field__c = existing.FEC_Additional_Field__c,
            FEC_Name_VN__c = 'Renamed only'
        );

        FEC_AdditionalFieldValueTriggerHandler.handleBeforeUpdate(
            new List<FEC_MDM_Additional_Field_List_Value__c>{ updated },
            new Map<Id, FEC_MDM_Additional_Field_List_Value__c>{ existing.Id => oldRow }
        );

        System.assertEquals(0, updated.getErrors().size(),
            'No code/parent change should skip duplicate validation.');
    }

    @IsTest
    static void handleBeforeUpdate_codeChangedToDuplicate_addsError() {
        FEC_MDM_Additional_Field__c parent = insertParent();
        insert buildListValue(parent.Id, 'KEEPER');
        FEC_MDM_Additional_Field_List_Value__c row = buildListValue(parent.Id, 'OTHER');
        insert row;

        FEC_MDM_Additional_Field_List_Value__c oldRow = new FEC_MDM_Additional_Field_List_Value__c(
            Id = row.Id,
            FEC_Code__c = row.FEC_Code__c,
            FEC_Additional_Field__c = row.FEC_Additional_Field__c
        );
        FEC_MDM_Additional_Field_List_Value__c updated = new FEC_MDM_Additional_Field_List_Value__c(
            Id = row.Id,
            FEC_Code__c = 'KEEPER',
            FEC_Additional_Field__c = row.FEC_Additional_Field__c
        );

        FEC_AdditionalFieldValueTriggerHandler.handleBeforeUpdate(
            new List<FEC_MDM_Additional_Field_List_Value__c>{ updated },
            new Map<Id, FEC_MDM_Additional_Field_List_Value__c>{ row.Id => oldRow }
        );

        System.assertEquals(false, updated.getErrors().isEmpty(),
            'Changing code to existing value on same parent must addError.');
    }
}
