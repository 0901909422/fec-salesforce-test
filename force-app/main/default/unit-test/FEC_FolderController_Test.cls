@IsTest
private class FEC_FolderController_Test {

    private static String uniqueSuffix() {
        return String.valueOf(System.currentTimeMillis());
    }

    @TestSetup
    static void setupData() {
        String suffix = uniqueSuffix();

        FEC_Folder__c root = new FEC_Folder__c(
            Name = 'Controller Root',
            FEC_Folder_Label__c = 'Controller Root',
            FEC_Folder_Unique_Name__c = 'CtrlRoot_' + suffix
        );
        insert root;

        FEC_Folder__c child = new FEC_Folder__c(
            Name = 'Controller Child',
            FEC_Folder_Label__c = 'Controller Child',
            FEC_Folder_Unique_Name__c = 'CtrlChild_' + suffix,
            FEC_Parent_Folder__c = root.Id
        );
        insert child;

        insert new FEC_Template__c(
            Name = 'Inside Root',
            FEC_Folder__c = root.Id,
            FEC_Active__c = true
        );
    }

    private static FEC_Folder__c getRootFolder() {
        return [
            SELECT Id, FEC_Folder_Label__c
            FROM FEC_Folder__c
            WHERE FEC_Folder_Label__c = 'Controller Root'
            LIMIT 1
        ];
    }

    private static User createRestrictedUser() {
        List<Profile> profiles = [
            SELECT Id
            FROM Profile
            WHERE Name IN ('Chatter Free User', 'Minimum Access - Salesforce', 'Identity User')
            LIMIT 1
        ];
        System.assert(!profiles.isEmpty(), 'Không tìm thấy profile hạn chế để test.');
        Profile restrictedProfile = profiles[0];
        String uniq = String.valueOf(System.currentTimeMillis());
        User restrictedUser = new User(
            FirstName = 'Folder',
            LastName = 'Restricted',
            Email = 'foldrest' + uniq + '@example.com',
            Username = 'foldrest' + uniq + '@example.com.fptsb03',
            Alias = ('fr' + uniq).left(8),
            TimeZoneSidKey = 'Asia/Bangkok',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = restrictedProfile.Id
        );
        insert restrictedUser;
        return restrictedUser;
    }

    @IsTest
    static void testGetFolder() {
        FEC_Folder__c folder = getRootFolder();

        Test.startTest();
        FEC_Folder__c result = FEC_FolderController.getFolder(folder.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals('Controller Root', result.Name);
    }

    @IsTest
    static void testGetAllFolders() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderController.getAllFolders();
        Test.stopTest();

        System.assertEquals(2, results.size());
    }

    @IsTest
    static void testGetTopLevelFolders() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderController.getTopLevelFolders();
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Controller Root', results[0].Name);
    }

    @IsTest
    static void testGetFolderContents() {
        FEC_Folder__c root = getRootFolder();

        Test.startTest();
        Map<String, Object> contents = FEC_FolderController.getFolderContents(root.Id);
        Test.stopTest();

        System.assertNotEquals(null, contents);
        System.assert(contents.containsKey('folders'));
        System.assert(contents.containsKey('templates'));

        List<FEC_Folder__c> folders = (List<FEC_Folder__c>) contents.get('folders');
        List<FEC_Template__c> templates = (List<FEC_Template__c>) contents.get('templates');
        System.assertEquals(1, folders.size());
        System.assertEquals(1, templates.size());
    }

    @IsTest
    static void testSaveFolder_InsertAndUpdate() {
        String suffix = uniqueSuffix();
        FEC_Folder__c newFolder = new FEC_Folder__c(
            Name = 'New Via Controller',
            FEC_Folder_Label__c = 'New Via Controller',
            FEC_Folder_Unique_Name__c = 'NewCtrl_' + suffix
        );

        Test.startTest();
        Id savedId = FEC_FolderController.saveFolder(JSON.serialize(newFolder));
        newFolder.Id = savedId;
        newFolder.FEC_Folder_Label__c = 'Updated Via Controller';
        newFolder.Name = 'Updated Via Controller';
        Id updatedId = FEC_FolderController.saveFolder(JSON.serialize(newFolder));
        Test.stopTest();

        System.assertEquals(savedId, updatedId);
        FEC_Folder__c saved = [
            SELECT Name
            FROM FEC_Folder__c
            WHERE Id = :savedId
        ];
        System.assertEquals('Updated Via Controller', saved.Name);
    }

    @IsTest
    static void testSaveFolder_InvalidJsonThrows() {
        Test.startTest();
        try {
            FEC_FolderController.saveFolder('invalid-json');
            System.assert(false, 'Phải throw AuraHandledException khi JSON không hợp lệ.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetFolder_NullId() {
        Test.startTest();
        FEC_Folder__c result = FEC_FolderController.getFolder(null);
        Test.stopTest();

        System.assertEquals(null, result);
    }

    @IsTest
    static void testSaveFolder_MissingRequiredFieldThrows() {
        Test.startTest();
        try {
            FEC_FolderController.saveFolder(
                JSON.serialize(new FEC_Folder__c(Name = 'Missing Unique Name'))
            );
            System.assert(false, 'Phải throw AuraHandledException khi thiếu FEC_Folder_Unique_Name__c.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteFolder_BlockedByChildFolder() {
        FEC_Folder__c root = getRootFolder();

        Test.startTest();
        try {
            FEC_FolderController.deleteFolder(root.Id);
            System.assert(false, 'Phải throw AuraHandledException khi folder còn sub-folder.');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('sub-folder') || e.getMessage().contains('Script-thrown'),
                'Error message: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteFolder_BlockedByTemplate() {
        String suffix = uniqueSuffix();
        FEC_Folder__c leafFolder = new FEC_Folder__c(
            Name = 'Leaf Folder',
            FEC_Folder_Label__c = 'Leaf Folder',
            FEC_Folder_Unique_Name__c = 'Leaf_' + suffix
        );
        insert leafFolder;

        insert new FEC_Template__c(
            Name = 'Leaf Template',
            FEC_Folder__c = leafFolder.Id,
            FEC_Active__c = true
        );

        Test.startTest();
        try {
            FEC_FolderController.deleteFolder(leafFolder.Id);
            System.assert(false, 'Phải throw AuraHandledException khi folder còn template.');
        } catch (AuraHandledException e) {
            System.assert(
                e.getMessage().contains('template') || e.getMessage().contains('Script-thrown'),
                'Error message: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testDeleteFolder_Success() {
        FEC_Folder__c child = [
            SELECT Id
            FROM FEC_Folder__c
            WHERE FEC_Folder_Label__c = 'Controller Child'
            LIMIT 1
        ];

        Test.startTest();
        FEC_FolderController.deleteFolder(child.Id);
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM FEC_Folder__c WHERE Id = :child.Id]
        );
    }

    @IsTest
    static void testSearchFolders() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderController.searchFolders('Controller');
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Cả 2 folder đều chứa từ khóa Controller.');
    }

    @IsTest
    static void testSearchFolders_BlankKeyword() {
        Test.startTest();
        List<FEC_Folder__c> results = FEC_FolderController.searchFolders('');
        Test.stopTest();

        System.assertNotEquals(null, results);
    }

    @IsTest
    static void testWriteMethods_CatchForRestrictedUser() {
        FEC_Folder__c root = getRootFolder();
        User restrictedUser = createRestrictedUser();
        Integer caughtCount = 0;

        System.runAs(restrictedUser) {
            Test.startTest();
            try {
                FEC_FolderController.saveFolder(
                    JSON.serialize(new FEC_Folder__c(
                        Name = 'Denied',
                        FEC_Folder_Unique_Name__c = 'Denied_' + uniqueSuffix()
                    ))
                );
            } catch (AuraHandledException e) {
                caughtCount++;
            }
            try {
                FEC_FolderController.deleteFolder(root.Id);
            } catch (AuraHandledException e) {
                caughtCount++;
            }
            Test.stopTest();
        }

        System.assert(
            caughtCount > 0,
            'Restricted user phải kích hoạt AuraHandledException cho save/delete.'
        );
    }
}
