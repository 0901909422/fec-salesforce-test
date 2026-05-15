/*------------------------------------------------------------
Author:        Thanh Van
Company:       Amaris
Description:   Test class of ArchiveCaseController
Test Class:    
History
<Date>         <Authors Name>     <Brief Description of Change>
2026/04/01     Thanh Van          Init
------------------------------------------------------------*/
@IsTest
global with sharing class ArchiveCaseController_Test {

    @isTest
    static void testGetOrCreateCaseWithExistedCase() {
        AthenaCases__x fakeRecord = new AthenaCases__x(ExternalId = 'EXAMPLE-999', 
                                                    case_id__c = 'EXAMPLE-999', 
                                                    s3_path__c = 'test', 
                                                    migration_source__c = 'test');
        ArchiveCaseController.mockExternalRecords = new List<AthenaCases__x>{ fakeRecord };
        Case localCase = new Case(ArchiveExternalId__c = 'EXAMPLE-999');
        insert localCase;
        
        Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(fakeRecord);
            ArchiveCaseController controller = new ArchiveCaseController(stdController);
            PageReference result = controller.fetchAndRedirect();
        Test.stopTest();
    }

    public class CaseDetailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String body = '{' +
                '  "FEC_District__c": null,' +
                '  "FEC_Country__c": null,' +
                '  "FEC_Case_Stage__c": null,' +
                '  "FEC_Actual_Nature_of_Case__c": null,' +
                '  "FEC_Business_Process__c": null,' +
                '  "ServiceContract": null,' +
                '  "Group": null,' +
                '  "SvcCatalogRequest": null,' +
                '  "SocialPost": null,' +
                '  "ResidentialLoanApplication": null,' +
                '  "PublicComplaint": null,' +
                '  "PersonLifeEvent": null,' +
                '  "InsurancePolicy": null,' +
                '  "EmailMessage": null,' +
                '  "BusinessMilestone": null,' +
                '  "Entitlement": null,' +
                '  "Product2": null,' +
                '  "Asset": null,' +
                '  "Account": null,' +
                '  "Contact": null,' +
                '  "FEC_Sub_Code__c": {' +
                '    "attributes": {' +
                '      "type": "FEC_Sub_Code__c",' +
                '      "url": "/services/data/v66.0/sobjects/FEC_Sub_Code__c/a0g850000010LNrAAM"' +
                '    },' +
                '    "Id": "a0g850000010LNrAAM",' +
                '    "OwnerId": "005850000058LHMAA2",' +
                '    "IsDeleted": false,' +
                '    "Name": "RC09.07-Cập nhật giới tính",' +
                '    "CreatedDate": "2026-02-11T07:24:59.000+0000",' +
                '    "CreatedById": "005850000058LHMAA2",' +
                '    "LastModifiedDate": "2026-02-24T07:31:06.000+0000",' +
                '    "LastModifiedById": "005850000058LHMAA2",' +
                '    "SystemModstamp": "2026-02-24T07:31:06.000+0000",' +
                '    "FEC_Code__c": "RC09.07",' +
                '    "FEC_Do_Not_Bother__c": false' +
                '  },' +
                '  "FEC_Sub_Category__c": {' +
                '    "attributes": {' +
                '      "type": "FEC_Sub_Category__c",' +
                '      "url": "/services/data/v66.0/sobjects/FEC_Sub_Category__c/a0f85000001HD6hAAG"' +
                '    },' +
                '    "Id": "a0f85000001HD6hAAG",' +
                '    "OwnerId": "005850000058LHMAA2",' +
                '    "IsDeleted": false,' +
                '    "Name": "RC09-Cập nhật thông tin",' +
                '    "CreatedDate": "2026-02-11T07:23:50.000+0000",' +
                '    "CreatedById": "005850000058LHMAA2",' +
                '    "LastModifiedDate": "2026-02-24T07:30:12.000+0000",' +
                '    "LastModifiedById": "005850000058LHMAA2",' +
                '    "SystemModstamp": "2026-02-24T07:30:12.000+0000",' +
                '    "FEC_Code__c": "RC09",' +
                '    "FEC_Do_Not_Bother__c": false' +
                '  },' +
                '  "FEC_Product_Type__c": {' +
                '    "attributes": {' +
                '      "type": "FEC_Product_Type__c",' +
                '      "url": "/services/data/v66.0/sobjects/FEC_Product_Type__c/a0a8500000ByciRAAR"' +
                '    },' +
                '    "Id": "a0a8500000ByciRAAR",' +
                '    "OwnerId": "005850000058LHMAA2",' +
                '    "IsDeleted": false,' +
                '    "Name": "Card",' +
                '    "CreatedDate": "2026-02-11T07:20:53.000+0000",' +
                '    "CreatedById": "005850000058LHMAA2",' +
                '    "LastModifiedDate": "2026-03-02T07:59:59.000+0000",' +
                '    "LastModifiedById": "005850000058LHMAA2",' +
                '    "SystemModstamp": "2026-03-02T07:59:59.000+0000",' +
                '    "FEC_Code__c": "Card"' +
                '  },' +
                '  "FEC_Category__c": {' +
                '    "attributes": {' +
                '      "type": "FEC_Category__c",' +
                '      "url": "/services/data/v66.0/sobjects/FEC_Category__c/a0T85000004BTHYEA4"' +
                '    },' +
                '    "Id": "a0T85000004BTHYEA4",' +
                '    "OwnerId": "005850000058LHMAA2",' +
                '    "IsDeleted": false,' +
                '    "Name": "Request",' +
                '    "CreatedDate": "2026-02-11T07:22:04.000+0000",' +
                '    "CreatedById": "005850000058LHMAA2",' +
                '    "LastModifiedDate": "2026-02-24T07:29:34.000+0000",' +
                '    "LastModifiedById": "005850000058LHMAA2",' +
                '    "SystemModstamp": "2026-02-24T07:29:34.000+0000",' +
                '    "FEC_Code__c": "Request",' +
                '    "FEC_Do_Not_Bother__c": false' +
                '  },' +
                '  "User": {' +
                '    "attributes": {' +
                '      "type": "User",' +
                '      "url": "/services/data/v66.0/sobjects/User/005d50000049NeDAAU"' +
                '    },' +
                '    "Id": "005d50000049NeDAAU",' +
                '    "Username": "long.nguyen.50@fecredit.com.vn.fecsit",' +
                '    "LastName": "Nguyễn",' +
                '    "FirstName": "Long",' +
                '    "MiddleName": "Thành",' +
                '    "Name": "Long Nguyễn",' +
                '    "Address": null,' +
                '    "Email": "long.nguyen.50@fecredit.com.vn",' +
                '    "EmailPreferencesAutoBcc": true,' +
                '    "EmailPreferencesAutoBccStayInTouch": false,' +
                '    "EmailPreferencesStayInTouchReminder": true,' +
                '    "Alias": "LongNT",' +
                '    "CommunityNickname": "User17627455558156872938",' +
                '    "IsActive": true,' +
                '    "TimeZoneSidKey": "Asia/Ho_Chi_Minh",' +
                '    "UserRoleId": "00E8500000319xVEAQ",' +
                '    "LocaleSidKey": "en_SG",' +
                '    "ReceivesInfoEmails": true,' +
                '    "ReceivesAdminInfoEmails": true,' +
                '    "EmailEncodingKey": "UTF-8",' +
                '    "ProfileId": "00ed5000003xNbbAAE",' +
                '    "UserType": "Standard",' +
                '    "StartDay": "8",' +
                '    "EndDay": "18",' +
                '    "LanguageLocaleKey": "en_US",' +
                '    "LastLoginDate": "2026-05-06T07:29:15.000+0000",' +
                '    "LastPasswordChangeDate": "2026-03-03T07:20:26.000+0000",' +
                '    "CreatedDate": "2025-11-10T03:34:37.000+0000",' +
                '    "CreatedById": "005d50000047h4LAAQ",' +
                '    "LastModifiedDate": "2026-05-06T04:59:50.000+0000",' +
                '    "LastModifiedById": "005d50000049NeDAAU",' +
                '    "SystemModstamp": "2026-05-06T04:59:50.000+0000",' +
                '    "PasswordExpirationDate": "2026-06-01T07:20:26.000+0000",' +
                '    "NumberOfFailedLogins": 0,' +
                '    "UserPermissionsMarketingUser": false,' +
                '    "UserPermissionsOfflineUser": false,' +
                '    "UserPermissionsAvantgoUser": false,' +
                '    "UserPermissionsCallCenterAutoLogin": false,' +
                '    "UserPermissionsSFContentUser": false,' +
                '    "UserPermissionsKnowledgeUser": false,' +
                '    "UserPermissionsInteractionUser": true,' +
                '    "UserPermissionsSupportUser": true,' +
                '    "ForecastEnabled": false,' +
                '    "UserPreferencesActivityRemindersPopup": true,' +
                '    "UserPreferencesEventRemindersCheckboxDefault": true,' +
                '    "UserPreferencesTaskRemindersCheckboxDefault": true,' +
                '    "UserPreferencesReminderSoundOff": false,' +
                '    "UserPreferencesDisableAllFeedsEmail": false,' +
                '    "UserPreferencesDisableFollowersEmail": false,' +
                '    "UserPreferencesDisableProfilePostEmail": false,' +
                '    "UserPreferencesDisableChangeCommentEmail": false,' +
                '    "UserPreferencesDisableLaterCommentEmail": false,' +
                '    "UserPreferencesDisProfPostCommentEmail": false,' +
                '    "UserPreferencesApexPagesDeveloperMode": false,' +
                '    "UserPreferencesReceiveNoNotificationsAsApprover": false,' +
                '    "UserPreferencesReceiveNotificationsAsDelegatedApprover": false,' +
                '    "UserPreferencesHideCSNGetChatterMobileTask": false,' +
                '    "UserPreferencesDisableMentionsPostEmail": false,' +
                '    "UserPreferencesDisMentionsCommentEmail": false,' +
                '    "UserPreferencesHideCSNDesktopTask": false,' +
                '    "UserPreferencesHideChatterOnboardingSplash": false,' +
                '    "UserPreferencesHideSecondChatterOnboardingSplash": false,' +
                '    "UserPreferencesDisCommentAfterLikeEmail": false,' +
                '    "UserPreferencesDisableLikeEmail": true,' +
                '    "UserPreferencesSortFeedByComment": true,' +
                '    "UserPreferencesDisableMessageEmail": false,' +
                '    "UserPreferencesDisableBookmarkEmail": false,' +
                '    "UserPreferencesDisableSharePostEmail": false,' +
                '    "UserPreferencesEnableAutoSubForFeeds": false,' +
                '    "UserPreferencesDisableFileShareNotificationsForApi": false,' +
                '    "UserPreferencesShowTitleToExternalUsers": true,' +
                '    "UserPreferencesShowManagerToExternalUsers": false,' +
                '    "UserPreferencesShowEmailToExternalUsers": false,' +
                '    "UserPreferencesShowWorkPhoneToExternalUsers": false,' +
                '    "UserPreferencesShowMobilePhoneToExternalUsers": false,' +
                '    "UserPreferencesShowFaxToExternalUsers": false,' +
                '    "UserPreferencesShowStreetAddressToExternalUsers": false,' +
                '    "UserPreferencesShowCityToExternalUsers": false,' +
                '    "UserPreferencesShowStateToExternalUsers": false,' +
                '    "UserPreferencesShowPostalCodeToExternalUsers": false,' +
                '    "UserPreferencesShowCountryToExternalUsers": false,' +
                '    "UserPreferencesShowProfilePicToGuestUsers": false,' +
                '    "UserPreferencesShowTitleToGuestUsers": false,' +
                '    "UserPreferencesShowCityToGuestUsers": false,' +
                '    "UserPreferencesShowStateToGuestUsers": false,' +
                '    "UserPreferencesShowPostalCodeToGuestUsers": false,' +
                '    "UserPreferencesShowCountryToGuestUsers": false,' +
                '    "UserPreferencesShowForecastingChangeSignals": false,' +
                '    "UserPreferencesLiveAgentMiawSetupDeflection": false,' +
                '    "UserPreferencesHideS1BrowserUI": true,' +
                '    "UserPreferencesDisableEndorsementEmail": false,' +
                '    "UserPreferencesPathAssistantCollapsed": false,' +
                '    "UserPreferencesCacheDiagnostics": false,' +
                '    "UserPreferencesShowEmailToGuestUsers": false,' +
                '    "UserPreferencesShowManagerToGuestUsers": false,' +
                '    "UserPreferencesShowWorkPhoneToGuestUsers": false,' +
                '    "UserPreferencesShowMobilePhoneToGuestUsers": false,' +
                '    "UserPreferencesShowFaxToGuestUsers": false,' +
                '    "UserPreferencesShowStreetAddressToGuestUsers": false,' +
                '    "UserPreferencesLightningExperiencePreferred": true,' +
                '    "UserPreferencesPreviewLightning": false,' +
                '    "UserPreferencesHideEndUserOnboardingAssistantModal": false,' +
                '    "UserPreferencesHideLightningMigrationModal": false,' +
                '    "UserPreferencesHideSfxWelcomeMat": true,' +
                '    "UserPreferencesHideBiggerPhotoCallout": false,' +
                '    "UserPreferencesGlobalNavBarWTShown": false,' +
                '    "UserPreferencesGlobalNavGridMenuWTShown": false,' +
                '    "UserPreferencesCreateLEXAppsWTShown": false,' +
                '    "UserPreferencesFavoritesWTShown": false,' +
                '    "UserPreferencesRecordHomeSectionCollapseWTShown": false,' +
                '    "UserPreferencesRecordHomeReservedWTShown": false,' +
                '    "UserPreferencesFavoritesShowTopFavorites": false,' +
                '    "UserPreferencesExcludeMailAppAttachments": false,' +
                '    "UserPreferencesSuppressTaskSFXReminders": false,' +
                '    "UserPreferencesSuppressEventSFXReminders": false,' +
                '    "UserPreferencesPreviewCustomTheme": false,' +
                '    "UserPreferencesHasCelebrationBadge": false,' +
                '    "UserPreferencesUserDebugModePref": false,' +
                '    "UserPreferencesSRHOverrideActivities": false,' +
                '    "UserPreferencesNewLightningReportRunPageEnabled": false,' +
                '    "UserPreferencesReverseOpenActivitiesView": false,' +
                '    "UserPreferencesHasSentWarningEmail": false,' +
                '    "UserPreferencesHasSentWarningEmail238": false,' +
                '    "UserPreferencesHasSentWarningEmail240": false,' +
                '    "UserPreferencesNativeEmailClient": false,' +
                '    "UserPreferencesHideBrowseProductRedirectConfirmation": false,' +
                '    "UserPreferencesHideOnlineSalesAppTabVisibilityRequirementsModal": false,' +
                '    "UserPreferencesHideOnlineSalesAppWelcomeMat": true,' +
                '    "UserPreferencesShowForecastingRoundedAmounts": false,' +
                '    "FullPhotoUrl": "https://fecredit123--fecsit.sandbox.file.force.com/profilephoto/005/F",' +
                '    "SmallPhotoUrl": "https://fecredit123--fecsit.sandbox.file.force.com/profilephoto/005/T",' +
                '    "IsExtIndicatorVisible": false,' +
                '    "MediumPhotoUrl": "https://fecredit123--fecsit.sandbox.file.force.com/profilephoto/005/M",' +
                '    "DigestFrequency": "D",' +
                '    "DefaultGroupNotificationFrequency": "N",' +
                '    "LastViewedDate": "2026-05-06T02:11:36.000+0000",' +
                '    "LastReferencedDate": "2026-05-06T02:11:36.000+0000",' +
                '    "BannerPhotoUrl": "/profilephoto/005/B",' +
                '    "SmallBannerPhotoUrl": "/profilephoto/005/D",' +
                '    "MediumBannerPhotoUrl": "/profilephoto/005/E",' +
                '    "IsProfilePhotoActive": false,' +
                '    "FEC_Main_Queue__c": "FEC_DQ_CS_Support",' +
                '    "CompanyName": null,' +
                '    "OutOfOfficeMessage": "",' +
                '    "BadgeText": ""' +
                '  },' +
                '  "RecordType": {' +
                '    "attributes": {' +
                '      "type": "RecordType",' +
                '      "url": "/services/data/v66.0/sobjects/RecordType/01285000000CMMXAA4"' +
                '    },' +
                '    "Id": "01285000000CMMXAA4",' +
                '    "Name": "Customer Case",' +
                '    "DeveloperName": "Customer_Case",' +
                '    "BusinessProcessId": "01985000001LjkjAAC",' +
                '    "SobjectType": "Case",' +
                '    "IsActive": true,' +
                '    "CreatedById": "005d5000004AWabAAG",' +
                '    "CreatedDate": "2026-02-09T04:03:07.000+0000",' +
                '    "LastModifiedById": "005d5000004AWabAAG",' +
                '    "LastModifiedDate": "2026-05-06T03:14:24.000+0000",' +
                '    "SystemModstamp": "2026-05-06T03:14:24.000+0000"' +
                '  },' +
                '  "BusinessHours": {' +
                '    "attributes": {' +
                '      "type": "BusinessHours",' +
                '      "url": "/services/data/v66.0/sobjects/BusinessHours/01md5000000siQfAAI"' +
                '    },' +
                '    "Id": "01md5000000siQfAAI",' +
                '    "Name": "Default",' +
                '    "IsActive": true,' +
                '    "IsDefault": true,' +
                '    "SundayStartTime": "00:00:00.000Z",' +
                '    "SundayEndTime": "00:00:00.000Z",' +
                '    "MondayStartTime": "00:00:00.000Z",' +
                '    "MondayEndTime": "00:00:00.000Z",' +
                '    "TuesdayStartTime": "00:00:00.000Z",' +
                '    "TuesdayEndTime": "00:00:00.000Z",' +
                '    "WednesdayStartTime": "00:00:00.000Z",' +
                '    "WednesdayEndTime": "00:00:00.000Z",' +
                '    "ThursdayStartTime": "00:00:00.000Z",' +
                '    "ThursdayEndTime": "00:00:00.000Z",' +
                '    "FridayStartTime": "00:00:00.000Z",' +
                '    "FridayEndTime": "00:00:00.000Z",' +
                '    "SaturdayStartTime": "00:00:00.000Z",' +
                '    "SaturdayEndTime": "00:00:00.000Z",' +
                '    "TimeZoneSidKey": "America/Los_Angeles",' +
                '    "SystemModstamp": "2025-10-13T01:19:03.000+0000",' +
                '    "CreatedDate": "2025-10-13T01:19:03.000+0000",' +
                '    "CreatedById": "005d5000003ieODAAY",' +
                '    "LastModifiedDate": "2025-10-13T01:19:03.000+0000",' +
                '    "LastModifiedById": "005d5000003ieODAAY"' +
                '  },' +
                '  "FEC_Watcher__c": [' +
                '    {' +
                '      "attributes": {' +
                '        "type": "FEC_Watcher__c",' +
                '        "url": "/services/data/v66.0/sobjects/FEC_Watcher__c/a1685000001hy0PAAQ"' +
                '      },' +
                '      "Id": "a1685000001hy0PAAQ",' +
                '      "IsDeleted": false,' +
                '      "Name": "A-00000558",' +
                '      "CreatedDate": "2026-05-06T05:03:47.000+0000",' +
                '      "CreatedById": "005d50000049NeDAAU",' +
                '      "LastModifiedDate": "2026-05-06T05:03:47.000+0000",' +
                '      "LastModifiedById": "005d50000049NeDAAU",' +
                '      "SystemModstamp": "2026-05-06T05:03:47.000+0000",' +
                '      "FEC_Case__c": "5008500000HigGOAAZ",' +
                '      "FEC_Active__c": true,' +
                '      "FEC_Follow_up_Type__c": "Until Case is Resolved",' +
                '      "FEC_User_Role__c": "Customer Service Support Manager",' +
                '      "FEC_User__c": "long.nguyen.50@fecredit.com.vn",' +
                '      "FEC_Watcher_User__c": "005d50000049NeDAAU"' +
                '    }' +
                '  ],' +
                '  "FEC_Stage_History__c": null,' +
                '  "FEC_Sensitive_Data__c": null,' +
                '  "FEC_Routing_Action_History__c": null,' +
                '  "FEC_Relevant_Ticket__c": null,' +
                '  "FEC_RePayment_Schedule__c": null,' +
                '  "FEC_Process_Action__c": null,' +
                '  "FEC_Process_Action_History__c": null,' +
                '  "FEC_Pending_Disbursement__c": null,' +
                '  "FEC_Notification_History__c": null,' +
                '  "FEC_KYC_Result__c": null,' +
                '  "FEC_Integration_Case__c": null,' +
                '  "FEC_IPP__c": null,' +
                '  "FEC_Do_Not_Bother__c": null,' +
                '  "FEC_Customer_History__c": null,' +
                '  "FEC_ChatHistory__c": null,' +
                '  "FEC_Case_Remarks__c": [' +
                '    {' +
                '      "attributes": {' +
                '        "type": "FEC_Case_Remarks__c",' +
                '        "url": "/services/data/v66.0/sobjects/FEC_Case_Remarks__c/a0u85000003LYxqAAG"' +
                '      },' +
                '      "Id": "a0u85000003LYxqAAG",' +
                '      "IsDeleted": false,' +
                '      "Name": "CR-0052",' +
                '      "CreatedDate": "2026-05-06T05:06:23.000+0000",' +
                '      "CreatedById": "005d50000049NeDAAU",' +
                '      "LastModifiedDate": "2026-05-06T05:06:23.000+0000",' +
                '      "LastModifiedById": "005d50000049NeDAAU",' +
                '      "SystemModstamp": "2026-05-06T05:06:23.000+0000",' +
                '      "FEC_Case_Remarks__c": "sdefrgthj",' +
                '      "FEC_Case__c": "5008500000HigGOAAZ",' +
                '      "FEC_User_Role__c": "Customer Service Support Manager",' +
                '      "FEC_User__c": "long.nguyen.50",' +
                '      "FEC_Remark_Type__c": "Case"' +
                '    },' +
                '    {' +
                '      "attributes": {' +
                '        "type": "FEC_Case_Remarks__c",' +
                '        "url": "/services/data/v66.0/sobjects/FEC_Case_Remarks__c/a0u85000003LZVhAAO"' +
                '      },' +
                '      "Id": "a0u85000003LZVhAAO",' +
                '      "IsDeleted": false,' +
                '      "Name": "CR-0053",' +
                '      "CreatedDate": "2026-05-06T05:07:15.000+0000",' +
                '      "CreatedById": "005d50000049NeDAAU",' +
                '      "LastModifiedDate": "2026-05-06T05:07:15.000+0000",' +
                '      "LastModifiedById": "005d50000049NeDAAU",' +
                '      "SystemModstamp": "2026-05-06T05:07:15.000+0000",' +
                '      "FEC_Case_Remarks__c": "dfghj",' +
                '      "FEC_Case__c": "5008500000HigGOAAZ",' +
                '      "FEC_User_Role__c": "Customer Service Support Manager",' +
                '      "FEC_User__c": "long.nguyen.50",' +
                '      "FEC_Remark_Type__c": "Case"' +
                '    }' +
                '  ],' +
                '  "FEC_Case_Refund_Details__c": null,' +
                '  "FEC_Case_Flow_History__c": [' +
                '    {' +
                '      "attributes": {' +
                '        "type": "FEC_Case_Flow_History__c",' +
                '        "url": "/services/data/v66.0/sobjects/FEC_Case_Flow_History__c/a23850000068P93AAE"' +
                '      },' +
                '      "Id": "a23850000068P93AAE",' +
                '      "IsDeleted": false,' +
                '      "Name": "CFH-3",' +
                '      "CreatedDate": "2026-05-06T05:06:22.000+0000",' +
                '      "CreatedById": "005d50000049NeDAAU",' +
                '      "LastModifiedDate": "2026-05-06T05:06:22.000+0000",' +
                '      "LastModifiedById": "005d50000049NeDAAU",' +
                '      "SystemModstamp": "2026-05-06T05:06:22.000+0000",' +
                '      "FEC_Case__c": "5008500000HigGOAAZ",' +
                '      "FEC_Field_List__c": "[]",' +
                '      "FEC_Nature_of_Cases__c": "a0W85000000HGYIEA4"' +
                '    },' +
                '    {' +
                '      "attributes": {' +
                '        "type": "FEC_Case_Flow_History__c",' +
                '        "url": "/services/data/v66.0/sobjects/FEC_Case_Flow_History__c/a23850000068PAfAAM"' +
                '      },' +
                '      "Id": "a23850000068PAfAAM",' +
                '      "IsDeleted": false,' +
                '      "Name": "CFH-4",' +
                '      "CreatedDate": "2026-05-06T05:07:15.000+0000",' +
                '      "CreatedById": "005d50000049NeDAAU",' +
                '      "LastModifiedDate": "2026-05-06T05:07:15.000+0000",' +
                '      "LastModifiedById": "005d50000049NeDAAU",' +
                '      "SystemModstamp": "2026-05-06T05:07:15.000+0000",' +
                '      "FEC_Case__c": "5008500000HigGOAAZ",' +
                '      "FEC_Field_List__c": "[]",' +
                '      "FEC_Nature_of_Cases__c": "a0W85000000HGYIEA4"' +
                '    }' +
                '  ],' +
                '  "FEC_Card_Payment__c": null,' +
                '  "FEC_Card_Delivery__c": null,' +
                '  "FEC_Assignment__c": null,' +
                '  "FEC_Asset__c": null,' +
                '  "FEC_Application_History__c": null,' +
                '  "FEC_Address_Info__c": null,' +
                '  "FEC_Additional_Info__c": [' +
                '    {' +
                '      "attributes": {' +
                '        "type": "FEC_Additional_Info__c",' +
                '        "url": "/services/data/v66.0/sobjects/FEC_Additional_Info__c/a0Q8500000Hn9d4EAB"' +
                '      },' +
                '      "Id": "a0Q8500000Hn9d4EAB",' +
                '      "IsDeleted": false,' +
                '      "Name": "Additional Info - 221",' +
                '      "CreatedDate": "2026-05-06T05:03:48.000+0000",' +
                '      "CreatedById": "005d50000049NeDAAU",' +
                '      "LastModifiedDate": "2026-05-06T05:03:48.000+0000",' +
                '      "LastModifiedById": "005d50000049NeDAAU",' +
                '      "SystemModstamp": "2026-05-06T05:03:48.000+0000",' +
                '      "FEC_Case__c": "5008500000HigGOAAZ"' +
                '    }' +
                '  ],' +
                '  "Case": {' +
                '    "attributes": {' +
                '      "type": "Case",' +
                '      "url": "/services/data/v66.0/sobjects/Case/5008500000HigGOAAZ"' +
                '    },' +
                '    "Id": "5008500000HigGOAAZ",' +
                '    "IsDeleted": false,' +
                '    "CaseNumber": "00001639",' +
                '    "BusinessHoursId": "01md5000000siQfAAI",' +
                '    "RecordTypeId": "01285000000CMMXAA4",' +
                '    "Status": "Pending",' +
                '    "Origin": "Web",' +
                '    "Priority": "Medium",' +
                '    "IsClosed": false,' +
                '    "IsEscalated": false,' +
                '    "OwnerId": "005d50000049NeDAAU",' +
                '    "IsClosedOnCreate": false,' +
                '    "IsStopped": false,' +
                '    "CreatedDate": "2026-05-06T05:03:47.000+0000",' +
                '    "CreatedById": "005d50000049NeDAAU",' +
                '    "LastModifiedDate": "2026-05-06T06:29:45.000+0000",' +
                '    "LastModifiedById": "005d50000049NeDAAU",' +
                '    "SystemModstamp": "2026-05-06T06:29:45.000+0000",' +
                '    "FEC_Account_Number__c": "0001500010000005476",' +
                '    "FEC_Account_or_Contract__c": "RecordCaseI-308515",' +
                '    "FEC_CS_Support__c": false,' +
                '    "FEC_Category__c": "a0T85000004BTHYEA4",' +
                '    "FEC_Channel__c": "Outbound",' +
                '    "FEC_Customer_Type__c": "Existing",' +
                '    "FEC_Global_Search__c": "O-0028",' +
                '    "FEC_Follow_Up_User__c": "005d50000049NeDAAU|U",' +
                '    "FEC_ID_Search__c": "S-79587",' +
                '    "FEC_Interaction_View_Mode__c": "review",' +
                '    "FEC_Interaction__c": "5008500000HiXjLAAV",' +
                '    "FEC_Is_CS_Customer_Care__c": false,' +
                '    "FEC_Is_In_Create_new_mode__c": false,' +
                '    "FEC_Last_Updated_By__c": "long.nguyen.50",' +
                '    "FEC_Last_Updated_On__c": "2026-05-06T06:29:45.000+0000",' +
                '    "FEC_Product_Type__c": "a0a8500000ByciRAAR",' +
                '    "FEC_Service_Case_Owner__c": "long.nguyen.50",' +
                '    "FEC_Skip_Search_Internal_Case__c": false,' +
                '    "FEC_SubCategory__c": "a0f85000001HD6hAAG",' +
                '    "FEC_SubCode__c": "a0g850000010LNrAAM",' +
                '    "FEC_Account_Contract_Number_Text__c": "0001500010000005476",' +
                '    "FEC_Case_Created_By__c": "long.nguyen.50",' +
                '    "FEC_Case_Created_On__c": "2026-05-06T05:03:47.000+0000",' +
                '    "FEC_Case_ID__c": "<a href=\\"/5008500000HigGO\\" target=\\"_self\\">S-79587</a>",' +
                '    "FEC_Has_Account_or_Contract__c": true,' +
                '    "FEC_Interaction_ID__c": "<a href=\\"/5008500000HiXjL\\" target=\\"_self\\">O-0028</a>",' +
                '    "FEC_Interaction_Status__c": "Open",' +
                '    "FEC_Is_My_Follow_Up__c": false,' +
                '    "FEC_Link_ID__c": "<a href=\\"/5008500000HigGO\\" target=\\"_self\\">S-79587</a>",' +
                '    "FEC_Updated_Info_Gender__c": "M",' +
                '    "FEC_First_Access__c": false,' +
                '    "FEC_Is_Owner__c": false,' +
                '    "FEC_Is_Submited__c": true,' +
                '    "FEC_Search_Products__c": "Card",' +
                '    "FEC_CIF_Number__c": "16605715",' +
                '    "FEC_Case_Participants__c": "005d50000049NeDAAU",' +
                '    "FEC_FCR__c": false,' +
                '    "FEC_Is_Reply_Interaction_email__c": false,' +
                '    "FEC_Is_Save_Closed__c": false,' +
                '    "FEC_On_Hold__c": false,' +
                '    "FEC_Original_Info_Gender__c": "M",' +
                '    "FEC_Original_Info_Phone_Type__c": "Primary Phone",' +
                '    "FEC_Show_Action__c": true,' +
                '    "FEC_Updated_Info_Phone_Type__c": "Primary Phone",' +
                '    "FEC_Case_Status__c": "Pending -",' +
                '    "FEC_Final_Status__c": "Pending -",' +
                '    "FEC_Is_Case_Participants__c": false,' +
                '    "FEC_Get_Next_Work__c": false,' +
                '    "FEC_Is_Created_From_Search__c": false,' +
                '    "FEC_Is_Manager_For_Cur_User__c": false,' +
                '    "FEC_Owner_Is_User__c": true,' +
                '    "FEC_Show_Unfollow__c": false,' +
                '    "FEC_Parent_ID__c": "<a href=\\"/5008500000HigGO\\" target=\\"_self\\"> </a>",' +
                '    "FEC_Is_MyCaseAPI_Interaction__c": false,' +
                '    "FEC_Is_Test_API__c": false,' +
                '    "FEC_Last_Updated_By_View__c": "long.nguyen.50",' +
                '    "FEC_Last_Updated_On_View__c": "2026-05-06T06:29:45.000+0000",' +
                '    "FEC_Assignment_Count__c": 0,' +
                '    "FEC_Is_Call_API_Success__c": false,' +
                '    "MilestoneStatus": ""' +
                '  }' +
                '}';
            
            res.setBody(body);
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testGetOrCreateCase_CreateNewCaseSuccess() {
        Test.setMock(HttpCalloutMock.class, new CaseDetailMock());
        AthenaCases__x fakeExternalRecord = new AthenaCases__x(ExternalId = 'EXAMPLE-999', 
                                                    case_id__c = 'EXAMPLE-999', 
                                                    s3_path__c = 'test', 
                                                    migration_source__c = 'test');
        ArchiveCaseController.mockExternalRecords = new List<AthenaCases__x>{ fakeExternalRecord };
        
        Test.startTest();
            ApexPages.StandardController stdController = new ApexPages.StandardController(fakeExternalRecord);
            ArchiveCaseController controller = new ArchiveCaseController(stdController);
            PageReference result = controller.fetchAndRedirect();
        Test.stopTest();
    }

    @isTest
    static void testQueryArchiveCases() {
        AthenaCases__x fakeRecord = new AthenaCases__x(ExternalId = 'EXAMPLE-999', 
                                                    case_id__c = 'EXAMPLE-999', 
                                                    s3_path__c = 'test', 
                                                    migration_source__c = 'test');
        Test.startTest();
            ArchiveCaseController.queryArchiveCases(null, 'EXAMPLE-999');
        Test.stopTest();
    }

    @isTest
    static void testResolveIdByCode() {
        Test.startTest();
            ArchiveCaseController.resolveIdByCode('FEC_Product_Type__c', 'FEC_Code__c', 'test');
        Test.stopTest();
    }

    @IsTest
    static void testExtractNestedCode_Success() {
        Map<String, Object> childMap = new Map<String, Object>{
            'ProductCode' => 'SKU-123'
        };
        Map<String, Object> parentMap = new Map<String, Object>{
            'ProductDetails' => childMap
        };

        Test.startTest();
            String result = ArchiveCaseController.extractNestedCode(parentMap, 'ProductDetails', 'ProductCode');
        Test.stopTest();
    }
}