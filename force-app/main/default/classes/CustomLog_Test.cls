/*------------------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Test class of CustomLog
History
<Date>         <Authors Name>     <Brief Description of Change>
2025/03/25     Thanh Van          Init
----------------------------------------------------------------------------*/
@IsTest
public with sharing class CustomLog_Test {

    @isTest
    public static void testLogOldNew() {
        Test.startTest();
            CustomLog.logOldNew('TargetObjectIdTest', 'classNameTest', 
                                'methodNameTest', 'actionNameTest', 
                                'oldValueTest', 'newValueTest');
        Test.stopTest();
    }

    @isTest
    public static void testLogInternalError() {
        Test.startTest();
            CustomLog.logInternalError('classNameTest', 'methodNameTest', 'errorMessTest');
        Test.stopTest();
    }

    @isTest
    public static void testLogWithError() {
        CustomLog.isTestWithError = true;

        Test.startTest();
            CustomLog.logInternalError('classNameTest', 'methodNameTest', 'errorMessTest');
        Test.stopTest();
    }
}