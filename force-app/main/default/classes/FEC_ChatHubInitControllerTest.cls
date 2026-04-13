/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an org are executed whenever Apex code is deployed
 * to a production org to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production org. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the org size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@IsTest
private class FEC_ChatHubInitControllerTest {

    /**
     * Tạo một user giả lập để phục vụ cho việc test
     */
    private static User createTestUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueName = 'chathub.testuser.' + DateTime.now().getTime() + '@fec.com';
        
        User u = new User(
            Alias = 'standt',
            Email = uniqueName,
            EmailEncodingKey = 'UTF-8',
            LastName = 'Testing',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'Asia/Ho_Chi_Minh',
            UserName = uniqueName
        );
        insert u;
        return u;
    }

    /**
     * Gán Custom Permission cho User thông qua Permission Set
     * Việc gán này cần chạy trong context của user hiện tại để tránh lỗi Mixed DML
     */
    private static void assignCustomPermission(Id userId, String customPermissionName) {
        // Tạo Permission Set mới
        PermissionSet ps = new PermissionSet(
            Name = 'TestPermSet_ChatHub_' + DateTime.now().getTime(),
            Label = 'Test Perm Set ChatHub'
        );
        insert ps;

        // Lấy Id của Custom Permission
        CustomPermission customPerm = [SELECT Id FROM CustomPermission WHERE DeveloperName = :customPermissionName LIMIT 1];

        // Đưa Custom Permission vào Permission Set
        SetupEntityAccess sea = new SetupEntityAccess(
            ParentId = ps.Id,
            SetupEntityId = customPerm.Id
        );
        insert sea;

        // Gán Permission Set cho User
        PermissionSetAssignment psa = new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = ps.Id
        );
        insert psa;
    }

    @IsTest
    static void testGetChatHubInfo_WithoutPermission() {
        // 1. Chuẩn bị dữ liệu: User KHÔNG có Custom Permission
        User testUser = createTestUser();

        // 2. Thực thi
        System.runAs(testUser) {
            Test.startTest();
            String result = FEC_ChatHubInitController.getChatHubInfo();
            Test.stopTest();

            // 3. Kiểm tra kết quả
            // Vì user không có quyền nên code phải chặn lại ở hàm checkSystemAndUserAccess và trả về 'false'
            System.assertEquals('false', result, 'Hàm phải trả về chuỗi false khi user không có quyền FEC_ChatHubAccess');
        }
    }

    @IsTest
    static void testGetChatHubInfo_WithPermission() {
        // 1. Chuẩn bị dữ liệu: User CÓ Custom Permission
        User testUser = createTestUser();

        // Tránh lỗi Mixed DML bằng cách chạy DML setup ở context của user hệ thống
        System.runAs(new User(Id = UserInfo.getUserId())) {
            assignCustomPermission(testUser.Id, 'FEC_ChatHubAccess');
        }

        // 2. Thực thi
        System.runAs(testUser) {
            Test.startTest();
            String result = FEC_ChatHubInitController.getChatHubInfo();
            Test.stopTest();

            // 3. Kiểm tra kết quả
            System.assertNotEquals(null, result, 'Kết quả trả về không được phép null');
            
            // Do Custom Metadata đọc từ Org thật, nếu metadata chưa được enable, nó sẽ ra 'false'.
            // Nếu đã enable và có cấu hình, nó sẽ trả về format: username|url|encryptedToken
            if (result != 'false') {
                System.assert(result.contains('|'), 'Khi thành công, chuỗi trả về phải chứa dấu phân cách |');
                
                // Kiểm tra xem username có được lấy đúng theo định dạng trước @ không
                String expectedUsername = testUser.Email.split('@')[0];
                System.assert(result.startsWith(expectedUsername), 'Chuỗi kết quả phải bắt đầu bằng username của user hiện tại');
            }
        }
    }
}