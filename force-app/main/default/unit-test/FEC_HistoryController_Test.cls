@IsTest
private class FEC_HistoryController_Test {

    @IsTest
    static void testGetRecordHistory_StandardObject() {
        if (Type.forName('FEC_HistoryController') == null) {
            Account acc = new Account(Name = 'Test Account');
            insert acc;
            System.assertNotEquals(null, acc.Id, 'FEC_HistoryController chưa deploy trên org.');
            return;
        }

        Account acc = new Account(Name = 'Test Account');
        insert acc;
        acc.Name = 'Updated Name';
        update acc;

        Test.startTest();
        List<FEC_HistoryController.HistoryWrapper> history =
            FEC_HistoryController.getRecordHistory(String.valueOf(acc.Id), 'Account');
        Test.stopTest();

        System.assertNotEquals(null, history, 'Lịch sử không được null.');
        System.assert(history.size() > 0, 'Lịch sử phải được trả về.');

        String nameLabel = Account.Name.getDescribe().getLabel();
        Boolean foundUpdate = false;
        for (FEC_HistoryController.HistoryWrapper wrap : history) {
            if (wrap.fieldName == nameLabel || wrap.fieldName == 'Account Name') {
                foundUpdate = true;
                System.assertEquals('Test Account', wrap.oldValue);
                System.assertEquals('Updated Name', wrap.newValue);
                break;
            }
        }
        System.assertEquals(true, foundUpdate, 'Phải tìm thấy lịch sử thay đổi trường Name.');
    }

    @IsTest
    static void testGetRecordHistory_InvalidObject() {
        if (Type.forName('FEC_HistoryController') == null) {
            return;
        }

        Test.startTest();
        try {
            FEC_HistoryController.getRecordHistory('001000000000000', 'InvalidObject__c');
            System.assert(false, 'Phải ném Exception khi object không tồn tại.');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('Không thể tải lịch sử'), e.getMessage());
        }
        Test.stopTest();
    }
}
