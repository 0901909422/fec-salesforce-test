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
            '  "FEC_Product_Type__c" : null,' +
            '  "FEC_Sub_Code__c" : null,' +
            '  "FEC_Sub_Category__c" : null,' +
            '  "FEC_District__c" : null,' +
            '  "FEC_Case_Stage__c" : null,' +
            '  "FEC_Country__c" : null,' +
            '  "FEC_Category__c" : null,' +
            '  "FEC_Business_Process__c" : null,' +
            '  "FEC_Actual_Nature_of_Case__c" : null,' +
            '  "ServiceContract" : null,' +
            '  "SvcCatalogRequest" : null,' +
            '  "SocialPost" : null,' +
            '  "ResidentialLoanApplication" : null,' +
            '  "PublicComplaint" : null,' +
            '  "PersonLifeEvent" : null,' +
            '  "InsurancePolicy" : null,' +
            '  "EmailMessage" : null,' +
            '  "BusinessMilestone" : null,' +
            '  "Entitlement" : null,' +
            '  "Product2" : null,' +
            '  "Asset" : null,' +
            '  "Account" : null,' +
            '  "Contact" : null,' +
            '  "User" : [ {' +
            '    "attributes" : {' +
            '      "type" : "User",' +
            '      "url" : "/services/data/v66.0/sobjects/User/00586000002D4HZAA0"' +
            '    },' +
            '    "Id" : "00586000002D4HZAA0",' +
            '    "Username" : "trangdtt3@fpt.com.fecuat",' +
            '    "LastName" : "Trang DTT3",' +
            '    "Name" : "Trang DTT3",' +
            '    "Address" : null,' +
            '    "Email" : "trangdtt3@fpt.com",' +
            '    "EmailPreferencesAutoBcc" : true,' +
            '    "EmailPreferencesAutoBccStayInTouch" : false,' +
            '    "EmailPreferencesStayInTouchReminder" : true,' +
            '    "Alias" : "trangdtt",' +
            '    "CommunityNickname" : "trangdtt3",' +
            '    "IsActive" : true,' +
            '    "TimeZoneSidKey" : "Asia/Ho_Chi_Minh",' +
            '    "UserRoleId" : "00E86000000T4i5EAC",' +
            '    "LocaleSidKey" : "en_GB",' +
            '    "ReceivesInfoEmails" : true,' +
            '    "ReceivesAdminInfoEmails" : true,' +
            '    "EmailEncodingKey" : "UTF-8",' +
            '    "ProfileId" : "00ed5000003xNbbAAE",' +
            '    "UserType" : "Standard",' +
            '    "StartDay" : "6",' +
            '    "EndDay" : "23",' +
            '    "LanguageLocaleKey" : "en_US",' +
            '    "LastLoginDate" : "2026-05-19T07:05:43.000+0000",' +
            '    "LastPasswordChangeDate" : "2026-04-30T06:40:25.000+0000",' +
            '    "CreatedDate" : "2026-03-03T11:05:22.000+0000",' +
            '    "CreatedById" : "00586000002AW3yAAG",' +
            '    "LastModifiedDate" : "2026-05-19T08:33:01.000+0000",' +
            '    "LastModifiedById" : "00586000002D4HZAA0",' +
            '    "SystemModstamp" : "2026-05-19T08:33:01.000+0000",' +
            '    "PasswordExpirationDate" : "2026-07-29T06:40:25.000+0000",' +
            '    "NumberOfFailedLogins" : 0,' +
            '    "UserPermissionsMarketingUser" : false,' +
            '    "UserPermissionsOfflineUser" : false,' +
            '    "UserPermissionsAvantgoUser" : false,' +
            '    "UserPermissionsCallCenterAutoLogin" : false,' +
            '    "UserPermissionsSFContentUser" : false,' +
            '    "UserPermissionsKnowledgeUser" : false,' +
            '    "UserPermissionsInteractionUser" : true,' +
            '    "UserPermissionsSupportUser" : true,' +
            '    "ForecastEnabled" : false,' +
            '    "UserPreferencesActivityRemindersPopup" : true,' +
            '    "UserPreferencesEventRemindersCheckboxDefault" : true,' +
            '    "UserPreferencesTaskRemindersCheckboxDefault" : true,' +
            '    "UserPreferencesReminderSoundOff" : false,' +
            '    "UserPreferencesDisableAllFeedsEmail" : false,' +
            '    "UserPreferencesDisableFollowersEmail" : false,' +
            '    "UserPreferencesDisableProfilePostEmail" : false,' +
            '    "UserPreferencesDisableChangeCommentEmail" : false,' +
            '    "UserPreferencesDisableLaterCommentEmail" : false,' +
            '    "UserPreferencesDisProfPostCommentEmail" : false,' +
            '    "UserPreferencesApexPagesDeveloperMode" : false,' +
            '    "UserPreferencesReceiveNoNotificationsAsApprover" : false,' +
            '    "UserPreferencesReceiveNotificationsAsDelegatedApprover" : false,' +
            '    "UserPreferencesHideCSNGetChatterMobileTask" : false,' +
            '    "UserPreferencesDisableMentionsPostEmail" : false,' +
            '    "UserPreferencesDisMentionsCommentEmail" : false,' +
            '    "UserPreferencesHideCSNDesktopTask" : false,' +
            '    "UserPreferencesHideChatterOnboardingSplash" : false,' +
            '    "UserPreferencesHideSecondChatterOnboardingSplash" : false,' +
            '    "UserPreferencesDisCommentAfterLikeEmail" : false,' +
            '    "UserPreferencesDisableLikeEmail" : true,' +
            '    "UserPreferencesSortFeedByComment" : true,' +
            '    "UserPreferencesDisableMessageEmail" : false,' +
            '    "UserPreferencesDisableBookmarkEmail" : false,' +
            '    "UserPreferencesDisableSharePostEmail" : false,' +
            '    "UserPreferencesEnableAutoSubForFeeds" : false,' +
            '    "UserPreferencesDisableFileShareNotificationsForApi" : false,' +
            '    "UserPreferencesShowTitleToExternalUsers" : true,' +
            '    "UserPreferencesShowManagerToExternalUsers" : false,' +
            '    "UserPreferencesShowEmailToExternalUsers" : false,' +
            '    "UserPreferencesShowWorkPhoneToExternalUsers" : false,' +
            '    "UserPreferencesShowMobilePhoneToExternalUsers" : false,' +
            '    "UserPreferencesShowFaxToExternalUsers" : false,' +
            '    "UserPreferencesShowStreetAddressToExternalUsers" : false,' +
            '    "UserPreferencesShowCityToExternalUsers" : false,' +
            '    "UserPreferencesShowStateToExternalUsers" : false,' +
            '    "UserPreferencesShowPostalCodeToExternalUsers" : false,' +
            '    "UserPreferencesShowCountryToExternalUsers" : false,' +
            '    "UserPreferencesShowProfilePicToGuestUsers" : false,' +
            '    "UserPreferencesShowTitleToGuestUsers" : false,' +
            '    "UserPreferencesShowCityToGuestUsers" : false,' +
            '    "UserPreferencesShowStateToGuestUsers" : false,' +
            '    "UserPreferencesShowPostalCodeToGuestUsers" : false,' +
            '    "UserPreferencesShowCountryToGuestUsers" : false,' +
            '    "UserPreferencesShowForecastingChangeSignals" : false,' +
            '    "UserPreferencesLiveAgentMiawSetupDeflection" : false,' +
            '    "UserPreferencesHideS1BrowserUI" : true,' +
            '    "UserPreferencesDisableEndorsementEmail" : false,' +
            '    "UserPreferencesPathAssistantCollapsed" : false,' +
            '    "UserPreferencesCacheDiagnostics" : false,' +
            '    "UserPreferencesShowEmailToGuestUsers" : false,' +
            '    "UserPreferencesShowManagerToGuestUsers" : false,' +
            '    "UserPreferencesShowWorkPhoneToGuestUsers" : false,' +
            '    "UserPreferencesShowMobilePhoneToGuestUsers" : false,' +
            '    "UserPreferencesShowFaxToGuestUsers" : false,' +
            '    "UserPreferencesShowStreetAddressToGuestUsers" : false,' +
            '    "UserPreferencesLightningExperiencePreferred" : true,' +
            '    "UserPreferencesPreviewLightning" : false,' +
            '    "UserPreferencesHideEndUserOnboardingAssistantModal" : false,' +
            '    "UserPreferencesHideLightningMigrationModal" : false,' +
            '    "UserPreferencesHideSfxWelcomeMat" : true,' +
            '    "UserPreferencesHideBiggerPhotoCallout" : false,' +
            '    "UserPreferencesGlobalNavBarWTShown" : false,' +
            '    "UserPreferencesGlobalNavGridMenuWTShown" : false,' +
            '    "UserPreferencesCreateLEXAppsWTShown" : false,' +
            '    "UserPreferencesFavoritesWTShown" : false,' +
            '    "UserPreferencesRecordHomeSectionCollapseWTShown" : false,' +
            '    "UserPreferencesRecordHomeReservedWTShown" : false,' +
            '    "UserPreferencesFavoritesShowTopFavorites" : false,' +
            '    "UserPreferencesExcludeMailAppAttachments" : false,' +
            '    "UserPreferencesSuppressTaskSFXReminders" : false,' +
            '    "UserPreferencesSuppressEventSFXReminders" : false,' +
            '    "UserPreferencesPreviewCustomTheme" : false,' +
            '    "UserPreferencesHasCelebrationBadge" : false,' +
            '    "UserPreferencesUserDebugModePref" : true,' +
            '    "UserPreferencesSRHOverrideActivities" : false,' +
            '    "UserPreferencesNewLightningReportRunPageEnabled" : false,' +
            '    "UserPreferencesReverseOpenActivitiesView" : false,' +
            '    "UserPreferencesHasSentWarningEmail" : false,' +
            '    "UserPreferencesHasSentWarningEmail238" : false,' +
            '    "UserPreferencesHasSentWarningEmail240" : false,' +
            '    "UserPreferencesNativeEmailClient" : false,' +
            '    "UserPreferencesHideBrowseProductRedirectConfirmation" : false,' +
            '    "UserPreferencesHideOnlineSalesAppTabVisibilityRequirementsModal" : false,' +
            '    "UserPreferencesHideOnlineSalesAppWelcomeMat" : false,' +
            '    "UserPreferencesShowForecastingRoundedAmounts" : false,' +
            '    "FullPhotoUrl" : "https://fecredit123--fecuat.sandbox.file.force.com/profilephoto/005/F",' +
            '    "SmallPhotoUrl" : "https://fecredit123--fecuat.sandbox.file.force.com/profilephoto/005/T",' +
            '    "IsExtIndicatorVisible" : false,' +
            '    "MediumPhotoUrl" : "https://fecredit123--fecuat.sandbox.file.force.com/profilephoto/005/M",' +
            '    "DigestFrequency" : "D",' +
            '    "DefaultGroupNotificationFrequency" : "N",' +
            '    "BannerPhotoUrl" : "/profilephoto/005/B",' +
            '    "SmallBannerPhotoUrl" : "/profilephoto/005/D",' +
            '    "MediumBannerPhotoUrl" : "/profilephoto/005/E",' +
            '    "IsProfilePhotoActive" : false,' +
            '    "FEC_Main_Queue__c" : "FEC_DQ_CS_Support",' +
            '    "FEC_User_Division_Group__c" : "CS Back Office",' +
            '    "FEC_User_Group__c" : "SP",' +
            '    "CompanyName" : null,' +
            '    "OutOfOfficeMessage" : "",' +
            '    "BadgeText" : ""' +
            '  }, {' +
            '    "attributes" : {' +
            '      "type" : "User",' +
            '      "url" : "/services/data/v66.0/sobjects/User/00586000002CXNYAA4"' +
            '    },' +
            '    "Id" : "00586000002CXNYAA4",' +
            '    "Username" : "it.nam.vo.3@fecredit.com.vn.fecuat",' +
            '    "LastName" : "IT.nam.vo.3",' +
            '    "Name" : "IT.nam.vo.3",' +
            '    "Address" : null,' +
            '    "Email" : "nam.vo.3@fecredit.com.vn",' +
            '    "EmailPreferencesAutoBcc" : true,' +
            '    "EmailPreferencesAutoBccStayInTouch" : false,' +
            '    "EmailPreferencesStayInTouchReminder" : true,' +
            '    "Alias" : "UAT20",' +
            '    "CommunityNickname" : "User17720053891066418492",' +
            '    "IsActive" : true,' +
            '    "TimeZoneSidKey" : "Asia/Ho_Chi_Minh",' +
            '    "UserRoleId" : "00E86000000T4ieEAC",' +
            '    "LocaleSidKey" : "en_GB",' +
            '    "ReceivesInfoEmails" : false,' +
            '    "ReceivesAdminInfoEmails" : false,' +
            '    "EmailEncodingKey" : "UTF-8",' +
            '    "ProfileId" : "00ed5000003xNbbAAE",' +
            '    "UserType" : "Standard",' +
            '    "StartDay" : "6",' +
            '    "EndDay" : "23",' +
            '    "LanguageLocaleKey" : "en_US",' +
            '    "LastLoginDate" : "2026-05-19T04:37:19.000+0000",' +
            '    "LastPasswordChangeDate" : "2026-02-25T09:39:24.000+0000",' +
            '    "CreatedDate" : "2026-02-25T07:43:10.000+0000",' +
            '    "CreatedById" : "00586000002AW3yAAG",' +
            '    "LastModifiedDate" : "2026-05-19T09:29:31.000+0000",' +
            '    "LastModifiedById" : "00586000002CXNYAA4",' +
            '    "SystemModstamp" : "2026-05-19T09:29:31.000+0000",' +
            '    "PasswordExpirationDate" : "2026-05-26T09:39:24.000+0000",' +
            '    "NumberOfFailedLogins" : 0,' +
            '    "UserPermissionsMarketingUser" : false,' +
            '    "UserPermissionsOfflineUser" : false,' +
            '    "UserPermissionsAvantgoUser" : false,' +
            '    "UserPermissionsCallCenterAutoLogin" : false,' +
            '    "UserPermissionsSFContentUser" : false,' +
            '    "UserPermissionsKnowledgeUser" : false,' +
            '    "UserPermissionsInteractionUser" : true,' +
            '    "UserPermissionsSupportUser" : true,' +
            '    "ForecastEnabled" : false,' +
            '    "UserPreferencesActivityRemindersPopup" : true,' +
            '    "UserPreferencesEventRemindersCheckboxDefault" : true,' +
            '    "UserPreferencesTaskRemindersCheckboxDefault" : true,' +
            '    "UserPreferencesReminderSoundOff" : false,' +
            '    "UserPreferencesDisableAllFeedsEmail" : false,' +
            '    "UserPreferencesDisableFollowersEmail" : false,' +
            '    "UserPreferencesDisableProfilePostEmail" : false,' +
            '    "UserPreferencesDisableChangeCommentEmail" : false,' +
            '    "UserPreferencesDisableLaterCommentEmail" : false,' +
            '    "UserPreferencesDisProfPostCommentEmail" : false,' +
            '    "UserPreferencesApexPagesDeveloperMode" : false,' +
            '    "UserPreferencesReceiveNoNotificationsAsApprover" : false,' +
            '    "UserPreferencesReceiveNotificationsAsDelegatedApprover" : false,' +
            '    "UserPreferencesHideCSNGetChatterMobileTask" : false,' +
            '    "UserPreferencesDisableMentionsPostEmail" : false,' +
            '    "UserPreferencesDisMentionsCommentEmail" : false,' +
            '    "UserPreferencesHideCSNDesktopTask" : false,' +
            '    "UserPreferencesHideChatterOnboardingSplash" : false,' +
            '    "UserPreferencesHideSecondChatterOnboardingSplash" : false,' +
            '    "UserPreferencesDisCommentAfterLikeEmail" : false,' +
            '    "UserPreferencesDisableLikeEmail" : true,' +
            '    "UserPreferencesSortFeedByComment" : true,' +
            '    "UserPreferencesDisableMessageEmail" : false,' +
            '    "UserPreferencesDisableBookmarkEmail" : false,' +
            '    "UserPreferencesDisableSharePostEmail" : false,' +
            '    "UserPreferencesEnableAutoSubForFeeds" : false,' +
            '    "UserPreferencesDisableFileShareNotificationsForApi" : false,' +
            '    "UserPreferencesShowTitleToExternalUsers" : true,' +
            '    "UserPreferencesShowManagerToExternalUsers" : false,' +
            '    "UserPreferencesShowEmailToExternalUsers" : false,' +
            '    "UserPreferencesShowWorkPhoneToExternalUsers" : false,' +
            '    "UserPreferencesShowMobilePhoneToExternalUsers" : false,' +
            '    "UserPreferencesShowFaxToExternalUsers" : false,' +
            '    "UserPreferencesShowStreetAddressToExternalUsers" : false,' +
            '    "UserPreferencesShowCityToExternalUsers" : false,' +
            '    "UserPreferencesShowStateToExternalUsers" : false,' +
            '    "UserPreferencesShowPostalCodeToExternalUsers" : false,' +
            '    "UserPreferencesShowCountryToExternalUsers" : false,' +
            '    "UserPreferencesShowProfilePicToGuestUsers" : false,' +
            '    "UserPreferencesShowTitleToGuestUsers" : false,' +
            '    "UserPreferencesShowCityToGuestUsers" : false,' +
            '    "UserPreferencesShowStateToGuestUsers" : false,' +
            '    "UserPreferencesShowPostalCodeToGuestUsers" : false,' +
            '    "UserPreferencesShowCountryToGuestUsers" : false,' +
            '    "UserPreferencesShowForecastingChangeSignals" : false,' +
            '    "UserPreferencesLiveAgentMiawSetupDeflection" : false,' +
            '    "UserPreferencesHideS1BrowserUI" : false,' +
            '    "UserPreferencesDisableEndorsementEmail" : false,' +
            '    "UserPreferencesPathAssistantCollapsed" : false,' +
            '    "UserPreferencesCacheDiagnostics" : false,' +
            '    "UserPreferencesShowEmailToGuestUsers" : false,' +
            '    "UserPreferencesShowManagerToGuestUsers" : false,' +
            '    "UserPreferencesShowWorkPhoneToGuestUsers" : false,' +
            '    "UserPreferencesShowMobilePhoneToGuestUsers" : false,' +
            '    "UserPreferencesShowFaxToGuestUsers" : false,' +
            '    "UserPreferencesShowStreetAddressToGuestUsers" : false,' +
            '    "UserPreferencesLightningExperiencePreferred" : true,' +
            '    "UserPreferencesPreviewLightning" : false,' +
            '    "UserPreferencesHideEndUserOnboardingAssistantModal" : false,' +
            '    "UserPreferencesHideLightningMigrationModal" : false,' +
            '    "UserPreferencesHideSfxWelcomeMat" : true,' +
            '    "UserPreferencesHideBiggerPhotoCallout" : false,' +
            '    "UserPreferencesGlobalNavBarWTShown" : false,' +
            '    "UserPreferencesGlobalNavGridMenuWTShown" : false,' +
            '    "UserPreferencesCreateLEXAppsWTShown" : false,' +
            '    "UserPreferencesFavoritesWTShown" : false,' +
            '    "UserPreferencesRecordHomeSectionCollapseWTShown" : false,' +
            '    "UserPreferencesRecordHomeReservedWTShown" : false,' +
            '    "UserPreferencesFavoritesShowTopFavorites" : false,' +
            '    "UserPreferencesExcludeMailAppAttachments" : false,' +
            '    "UserPreferencesSuppressTaskSFXReminders" : false,' +
            '    "UserPreferencesSuppressEventSFXReminders" : false,' +
            '    "UserPreferencesPreviewCustomTheme" : false,' +
            '    "UserPreferencesHasCelebrationBadge" : false,' +
            '    "UserPreferencesUserDebugModePref" : false,' +
            '    "UserPreferencesSRHOverrideActivities" : false,' +
            '    "UserPreferencesNewLightningReportRunPageEnabled" : false,' +
            '    "UserPreferencesReverseOpenActivitiesView" : false,' +
            '    "UserPreferencesHasSentWarningEmail" : false,' +
            '    "UserPreferencesHasSentWarningEmail238" : false,' +
            '    "UserPreferencesHasSentWarningEmail240" : false,' +
            '    "UserPreferencesNativeEmailClient" : false,' +
            '    "UserPreferencesHideBrowseProductRedirectConfirmation" : false,' +
            '    "UserPreferencesHideOnlineSalesAppTabVisibilityRequirementsModal" : false,' +
            '    "UserPreferencesHideOnlineSalesAppWelcomeMat" : false,' +
            '    "UserPreferencesShowForecastingRoundedAmounts" : false,' +
            '    "FullPhotoUrl" : "https://fecredit123--fecuat.sandbox.file.force.com/profilephoto/005/F",' +
            '    "SmallPhotoUrl" : "https://fecredit123--fecuat.sandbox.file.force.com/profilephoto/005/T",' +
            '    "IsExtIndicatorVisible" : false,' +
            '    "MediumPhotoUrl" : "https://fecredit123--fecuat.sandbox.file.force.com/profilephoto/005/M",' +
            '    "DigestFrequency" : "D",' +
            '    "DefaultGroupNotificationFrequency" : "N",' +
            '    "LastViewedDate" : "2026-05-19T09:29:31.000+0000",' +
            '    "LastReferencedDate" : "2026-05-19T09:29:31.000+0000",' +
            '    "BannerPhotoUrl" : "/profilephoto/005/B",' +
            '    "SmallBannerPhotoUrl" : "/profilephoto/005/D",' +
            '    "MediumBannerPhotoUrl" : "/profilephoto/005/E",' +
            '    "IsProfilePhotoActive" : false,' +
            '    "FEC_Main_Queue__c" : "FEC_DQ_IT_Operations_Support",' +
            '    "FEC_User_Division_Group__c" : "CS Frontline",' +
            '    "FEC_User_Group__c" : "OB",' +
            '    "CompanyName" : null,' +
            '    "OutOfOfficeMessage" : "",' +
            '    "BadgeText" : ""' +
            '  } ],' +
            '  "Group" : {' +
            '    "attributes" : {' +
            '      "type" : "Group",' +
            '      "url" : "/services/data/v66.0/sobjects/Group/00G86000000y9PMEAY"' +
            '    },' +
            '    "Id" : "00G86000000y9PMEAY",' +
            '    "Name" : "IB01",' +
            '    "DeveloperName" : "FEC_IB01",' +
            '    "Type" : "Queue",' +
            '    "OwnerId" : "005d5000004AWabAAG",' +
            '    "DoesSendEmailToMembers" : false,' +
            '    "DoesIncludeBosses" : true,' +
            '    "CreatedDate" : "2026-03-03T08:18:08.000+0000",' +
            '    "CreatedById" : "005d5000004AWabAAG",' +
            '    "LastModifiedDate" : "2026-03-07T09:35:21.000+0000",' +
            '    "LastModifiedById" : "00586000002AW3yAAG",' +
            '    "SystemModstamp" : "2026-03-07T09:35:21.000+0000"' +
            '  },' +
            '  "RecordType" : {' +
            '    "attributes" : {' +
            '      "type" : "RecordType",' +
            '      "url" : "/services/data/v66.0/sobjects/RecordType/012860000008vZ0AAI"' +
            '    },' +
            '    "Id" : "012860000008vZ0AAI",' +
            '    "Name" : "Interaction",' +
            '    "DeveloperName" : "Interaction",' +
            '    "BusinessProcessId" : "01986000000hgyUAAQ",' +
            '    "SobjectType" : "Case",' +
            '    "IsActive" : true,' +
            '    "CreatedById" : "005d5000004AWabAAG",' +
            '    "CreatedDate" : "2026-03-03T08:18:49.000+0000",' +
            '    "LastModifiedById" : "005d5000004AWabAAG",' +
            '    "LastModifiedDate" : "2026-05-18T11:25:56.000+0000",' +
            '    "SystemModstamp" : "2026-05-18T11:25:56.000+0000"' +
            '  },' +
            '  "BusinessHours" : {' +
            '    "attributes" : {' +
            '      "type" : "BusinessHours",' +
            '      "url" : "/services/data/v66.0/sobjects/BusinessHours/01md5000000siQfAAI"' +
            '    },' +
            '    "Id" : "01md5000000siQfAAI",' +
            '    "Name" : "Default",' +
            '    "IsActive" : true,' +
            '    "IsDefault" : false,' +
            '    "SundayStartTime" : "00:00:00.000Z",' +
            '    "SundayEndTime" : "00:00:00.000Z",' +
            '    "MondayStartTime" : "00:00:00.000Z",' +
            '    "MondayEndTime" : "00:00:00.000Z",' +
            '    "TuesdayStartTime" : "00:00:00.000Z",' +
            '    "TuesdayEndTime" : "00:00:00.000Z",' +
            '    "WednesdayStartTime" : "00:00:00.000Z",' +
            '    "WednesdayEndTime" : "00:00:00.000Z",' +
            '    "ThursdayStartTime" : "00:00:00.000Z",' +
            '    "ThursdayEndTime" : "00:00:00.000Z",' +
            '    "FridayStartTime" : "00:00:00.000Z",' +
            '    "FridayEndTime" : "00:00:00.000Z",' +
            '    "SaturdayStartTime" : "00:00:00.000Z",' +
            '    "SaturdayEndTime" : "00:00:00.000Z",' +
            '    "TimeZoneSidKey" : "America/Los_Angeles",' +
            '    "SystemModstamp" : "2026-05-18T08:56:17.000+0000",' +
            '    "CreatedDate" : "2025-10-13T01:19:03.000+0000",' +
            '    "CreatedById" : "005d5000003ieODAAY",' +
            '    "LastModifiedDate" : "2025-10-13T01:19:03.000+0000",' +
            '    "LastModifiedById" : "005d5000003ieODAAY"' +
            '  },' +
            '  "FEC_Watcher__c" : [ {' +
            '    "attributes" : {' +
            '      "type" : "FEC_Watcher__c",' +
            '      "url" : "/services/data/v66.0/sobjects/FEC_Watcher__c/a0n860000007jTRAAY"' +
            '    },' +
            '    "Id" : "a0n860000007jTRAAY",' +
            '    "IsDeleted" : false,' +
            '    "Name" : "A-00000203",' +
            '    "CreatedDate" : "2026-03-04T07:40:55.000+0000",' +
            '    "CreatedById" : "00586000002D4HZAA0",' +
            '    "LastModifiedDate" : "2026-03-04T07:40:55.000+0000",' +
            '    "LastModifiedById" : "00586000002D4HZAA0",' +
            '    "SystemModstamp" : "2026-03-04T07:40:55.000+0000",' +
            '    "FEC_Case__c" : "5008600000EfbrZAAR",' +
            '    "FEC_Active__c" : true,' +
            '    "FEC_Follow_up_Type__c" : "Until Case is Resolved",' +
            '    "FEC_User__c" : "trangdtt3@fpt.com",' +
            '    "FEC_Watcher_User__c" : "00586000002D4HZAA0"' +
            '  } ],' +
            '  "FEC_Stage_History__c" : null,' +
            '  "FEC_Sensitive_Data__c" : null,' +
            '  "FEC_Routing_Action_History__c" : null,' +
            '  "FEC_Relevant_Ticket__c" : null,' +
            '  "FEC_RePayment_Schedule__c" : null,' +
            '  "FEC_Process_Action__c" : null,' +
            '  "FEC_Process_Action_History__c" : null,' +
            '  "FEC_Pending_Disbursement__c" : null,' +
            '  "FEC_Notification_History__c" : null,' +
            '  "FEC_KYC_Result__c" : null,' +
            '  "FEC_Integration_Case__c" : null,' +
            '  "FEC_Incorrect_Payment_Info__c" : null,' +
            '  "FEC_IPP__c" : null,' +
            '  "FEC_Do_Not_Bother__c" : null,' +
            '  "FEC_Customer_History__c" : [ {' +
            '    "attributes" : {' +
            '      "type" : "FEC_Customer_History__c",' +
            '      "url" : "/services/data/v66.0/sobjects/FEC_Customer_History__c/a0I86000000R61JEAS"' +
            '    },' +
            '    "Id" : "a0I86000000R61JEAS",' +
            '    "IsDeleted" : false,' +
            '    "Name" : "0001500040006525520",' +
            '    "CreatedDate" : "2026-03-04T07:41:26.000+0000",' +
            '    "CreatedById" : "00586000002D4HZAA0",' +
            '    "LastModifiedDate" : "2026-03-26T03:23:19.000+0000",' +
            '    "LastModifiedById" : "00586000002D4HZAA0",' +
            '    "SystemModstamp" : "2026-03-26T03:23:19.000+0000",' +
            '    "FEC_API_Cache_Secondary_Demo__c" : "{\\"zaloFollower\\":null,\\"websiteAccount\\":null,\\"references\\":[],\\"mobileAppAccount\\":null,\\"helpTexts\\":{\\"FEC_Zalo_Follower__c\\":\\"theo dÃµi FEC zalo\\",\\"FEC_National_ID_Passport_ID__c\\":\\"CCCD/CMND cá»§a khÃ¡ch hÃ ng\\",\\"FEC_Mobile_App_Account__c\\":\\"TÃ i khoáº£n trÃªn á»©ng dá»¥ng FEC\\",\\"FEC_Email__c\\":\\"Mail cá»§a khÃ¡ch hÃ ng\\",\\"FEC_Daily_Retail_Limit__c\\":\\"háº¡n má»©c theo ngÃ y\\",\\"FEC_Account_Status__c\\":\\"Status KH\\",\\"FEC_Account_Number__c\\":\\"Sá»‘ TK khÃ¡ch hÃ ng\\",\\"FEC_API_Cache__c\\":\\"Cache API response to avoid multiple callouts\\"},\\"email\\":null,\\"contactList\\":[]}",' +
            '    "FEC_API_Cache__c" : "{\\"primaryPhone\\":\\"\\",\\"placeOfIssue\\":\\"AN GIANG\\",\\"nationalIDPassportID\\":\\"D083439600\\",\\"middleName\\":null,\\"maritalStatus\\":null,\\"lastName\\":null,\\"helpTexts\\":{\\"FEC_Zalo_Follower__c\\":\\"theo dÃµi FEC zalo\\",\\"FEC_National_ID_Passport_ID__c\\":\\"CCCD/CMND cá»§a khÃ¡ch hÃ ng\\",\\"FEC_Mobile_App_Account__c\\":\\"TÃ i khoáº£n trÃªn á»©ng dá»¥ng FEC\\",\\"FEC_Marital_Status__c\\":\\"tÃ¬nh tráº¡ng hÃ´n nhÃ¢n\\",\\"FEC_First_Name__c\\":\\"Há» khÃ¡ch hÃ ng\\",\\"FEC_Email__c\\":\\"Mail cá»§a khÃ¡ch hÃ ng\\",\\"FEC_Date_of_Issue__c\\":\\"a PhÆ°Æ¡ng test help text\\",\\"FEC_Daily_Retail_Limit__c\\":\\"háº¡n má»©c theo ngÃ y\\",\\"FEC_Customer_Name__c\\":\\"TÃªn Ä‘áº§y Ä‘á»§ khÃ¡ch hÃ ng\\",\\"FEC_Account_Status__c\\":\\"Status KH\\",\\"FEC_Account_Number__c\\":\\"Sá»‘ TK khÃ¡ch hÃ ng\\",\\"FEC_API_Cache__c\\":\\"Cache API response to avoid multiple callouts\\"},\\"gender\\":null,\\"fullName\\":null,\\"firstName\\":null,\\"dateOfIssue\\":\\"2005-06-02\\",\\"cifNumber\\":null,\\"birthDate\\":null,\\"addresses\\":[{\\"mailingAddress\\":\\"Yes\\",\\"addressType\\":\\"Current Address\\",\\"address\\":\\"PHÃ’NG Sá» 8, TRá»Œ QUÃN CÃ‚Y ÄIá»€U, Tá»” 5, TÃ‚N Má»¸, 805, 77, VIETNAM, \\"},{\\"mailingAddress\\":\\"Yes\\",\\"addressType\\":\\"Office Address\\",\\"address\\":\\", , , , , , VIETNAM, \\"}]}",' +
            '    "FEC_Customer_Type__c" : "Existing",' +
            '    "FEC_Date_of_Issue__c" : "2005-06-02",' +
            '    "FEC_National_ID_Passport_ID__c" : "D083439600",' +
            '    "FEC_Place_of_Issue__c" : "AN GIANG",' +
            '    "FEC_Total_Accrued_Interest__c" : 0,' +
            '    "FEC_Total_Close_Fee_Amount__c" : 0,' +
            '    "FEC_Total_Current_Balance__c" : 0,' +
            '    "FEC_Total_Deferred_Interest__c" : 0,' +
            '    "FEC_Total_IPP_Accrued_Interest__c" : 0,' +
            '    "FEC_Total_IPP_Balance__c" : 0,' +
            '    "FEC_Total_IPP_Current_Balance__c" : 0,' +
            '    "FEC_Total_Payment_Amount__c" : 0.00,' +
            '    "FEC_Total_Per_Diem__c" : 0,' +
            '    "FEC_Total_Plan_Payment_Amount__c" : 0,' +
            '    "FEC_Product_Association__c" : "Not defined",' +
            '    "FEC_Date_of_Birth__c" : "19750305",' +
            '    "FEC_Address_Info__c": [' +
            '      {' +
            '        "FEC_Mailing_Address__c": "abc@test.com",' +
            '        "FEC_Address_Type__c": "addrTypeTest"' +
            '      },' +
            '      {' +
            '        "FEC_Mailing_Address__c": "mana@test.com",' +
            '        "FEC_Address_Type__c": "addrTypeTest22222"' +
            '      }' +
            '    ]' +
            '  } ],' +
            '  "FEC_Contract_List_for_Remove_Phone__c" : null,' +
            '  "FEC_ChatHistory__c" : null,' +
            '  "FEC_Case_Remarks__c" : null,' +
            '  "FEC_Case_Refund_Details__c" : null,' +
            '  "FEC_Case_Flow_History__c" : null,' +
            '  "FEC_Card_Payment__c" : null,' +
            '  "FEC_Card_Delivery__c" : null,' +
            '  "FEC_Assignment__c" : null,' +
            '  "FEC_Asset__c" : null,' +
            '  "FEC_Application_History__c" : null,' +
            '  "FEC_Address_Info__c" : null,' +
            '  "FEC_Additional_Info__c" : null,' +
            '  "Case" : {' +
            '    "attributes" : {' +
            '      "type" : "Case",' +
            '      "url" : "/services/data/v66.0/sobjects/Case/5008600000EfbrZAAR"' +
            '    },' +
            '    "Id" : "5008600000EfbrZAAR",' +
            '    "IsDeleted" : false,' +
            '    "CaseNumber" : "00001208",' +
            '    "BusinessHoursId" : "01md5000000siQfAAI",' +
            '    "RecordTypeId" : "012860000008vZ0AAI",' +
            '    "Status" : "Open",' +
            '    "Priority" : "Medium",' +
            '    "IsClosed" : false,' +
            '    "IsEscalated" : false,' +
            '    "OwnerId" : "00G86000000y9PMEAY",' +
            '    "IsClosedOnCreate" : false,' +
            '    "IsStopped" : false,' +
            '    "CreatedDate" : "2026-03-04T07:40:54.000+0000",' +
            '    "CreatedById" : "00586000002D4HZAA0",' +
            '    "LastModifiedDate" : "2026-05-19T08:42:37.000+0000",' +
            '    "LastModifiedById" : "00586000002CXNYAA4",' +
            '    "SystemModstamp" : "2026-05-19T08:42:37.000+0000",' +
            '    "FEC_Account_or_Contract__c" : "a0I86000000R61JEAS",' +
            '    "FEC_CS_Support__c" : false,' +
            '    "FEC_Channel__c" : "Inbound",' +
            '    "FEC_Customer_Type__c" : "Existing",' +
            '    "FEC_FCR__c" : false,' +
            '    "FEC_First_Access__c" : false,' +
            '    "FEC_Follow_Up_User__c" : "00586000002D4HZAA0|R",' +
            '    "FEC_ID_Search__c" : "I-0080",' +
            '    "FEC_Interaction_Subchannel__c" : "Inbound Call",' +
            '    "FEC_Interaction_View_Mode__c" : "review",' +
            '    "FEC_Is_CS_Customer_Care__c" : false,' +
            '    "FEC_Is_In_Create_new_mode__c" : false,' +
            '    "FEC_Is_Owner__c" : false,' +
            '    "FEC_Is_Reply_Interaction_email__c" : false,' +
            '    "FEC_Is_Save_Closed__c" : false,' +
            '    "FEC_Is_Submited__c" : false,' +
            '    "FEC_KYC_Method__c" : "Question and Answer Q&A",' +
            '    "FEC_Last_Updated_By__c" : "nam.vo.3",' +
            '    "FEC_Last_Updated_On__c" : "2026-05-19T08:42:37.000+0000",' +
            '    "FEC_On_Hold__c" : false,' +
            '    "FEC_Original_Info_Phone_Type__c" : "Primary Phone",' +
            '    "FEC_Phone_Number__c" : "0915607799",' +
            '    "FEC_Search_Products__c" : "Card",' +
            '    "FEC_Skip_Search_Internal_Case__c" : false,' +
            '    "FEC_Updated_Info_Phone_Type__c" : "Primary Phone",' +
            '    "FEC_Account_Contract_Number_Text__c" : "0001500040006525520",' +
            '    "FEC_Created_On__c" : "2026-03-04T07:40:54.000+0000",' +
            '    "FEC_Created_by__c" : "trangdtt3",' +
            '    "FEC_Final_Status__c" : "Open",' +
            '    "FEC_Has_Account_or_Contract__c" : true,' +
            '    "FEC_Interaction_ID__c" : "<a href=\\"/5008600000EfbrZ\\" target=\\"_self\\">I-0080</a>",' +
            '    "FEC_Interaction_Masked_Phone__c" : "0915***799",' +
            '    "FEC_Interaction_Owner__c" : "IB01",' +
            '    "FEC_Interaction_Status__c" : "Open",' +
            '    "FEC_Is_Case_Participants__c" : false,' +
            '    "FEC_Is_My_Follow_Up__c" : false,' +
            '    "FEC_Link_ID__c" : "<a href=\\"/5008600000EfbrZ\\" target=\\"_self\\">I-0080</a>",' +
            '    "FEC_Show_Action__c" : false,' +
            '    "FEC_Get_Next_Work__c" : false,' +
            '    "FEC_Is_Created_From_Search__c" : false,' +
            '    "FEC_Is_Manager_For_Cur_User__c" : false,' +
            '    "FEC_Owner_Is_User__c" : false,' +
            '    "FEC_Show_Unfollow__c" : false,' +
            '    "FEC_Is_MyCaseAPI_Interaction__c" : false,' +
            '    "FEC_Parent_ID__c" : "<a href=\\"/5008600000EfbrZ\\" target=\\"_self\\"> </a>",' +
            '    "FEC_Is_Test_API__c" : false,' +
            '    "FEC_Last_Updated_By_View__c" : "nam.vo.3",' +
            '    "FEC_Last_Updated_On_View__c" : "2026-05-19T08:42:36.000+0000",' +
            '    "FEC_Is_Call_API_Success__c" : false,' +
            '    "FEC_Assignment_Count__c" : 0,' +
            '    "FEC_Can_Execute_Assignment__c" : false,' +
            '    "FEC_Can_Execute__c" : false,' +
            '    "FEC_Is_PIN_Reset_Success__c" : false,' +
            '    "FEC_Is_Owner_Or_Assigned__c" : false,' +
            '    "FEC_Owner_In_Assignment_Users__c" : false,' +
            '    "MilestoneStatus" : ""' +
            '  },' +
            '  "FEC_Case_Attachments": [{' +
            '    "s3Path": "case-files/S-79587/7df289ce95651df0_Screenshot_2026-05-06_at_11.06.33.png",' +
            '    "filename": "contract.pdf",' +
            '    "contentType": "application/pdf",' +
            '    "uploadedAt": "2026-03-01T08:00:00Z"' +
            '  }]' +
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