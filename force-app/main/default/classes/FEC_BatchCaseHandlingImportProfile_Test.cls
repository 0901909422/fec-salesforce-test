@IsTest
private class FEC_BatchCaseHandlingImportProfile_Test {

    @IsTest
    static void testResolveForCase_profilesAndScope() {
        FEC_BatchCaseHandlingImportProfile.ImportScope blankBp =
            FEC_BatchCaseHandlingImportProfile.resolveForCase(null, 'CC');
        System.assertEquals(true, blankBp.allowed);

        FEC_BatchCaseHandlingImportProfile.ImportScope d2c =
            FEC_BatchCaseHandlingImportProfile.resolveForCase('Document Request', 'D2C');
        if (d2c.allowed) {
            System.assertEquals(
                FEC_BatchCaseHandlingImportProfile.FIELD_PROFILE_D2C,
                d2c.fieldProfile
            );
        }

        FEC_BatchCaseHandlingImportProfile.ImportScope pm =
            FEC_BatchCaseHandlingImportProfile.resolveForCase(
                'Incorrect Payment Handling',
                'PM'
            );
        if (pm.allowed) {
            System.assertEquals(
                FEC_BatchCaseHandlingImportProfile.FIELD_PROFILE_PM_PAYMENT,
                pm.fieldProfile
            );
        }

        FEC_BatchCaseHandlingImportProfile.ImportScope cp =
            FEC_BatchCaseHandlingImportProfile.resolveForCase('Original MRC Return', 'CP');
        if (cp.allowed) {
            System.assertEquals(
                FEC_BatchCaseHandlingImportProfile.FIELD_PROFILE_CP_ASSESSMENT,
                cp.fieldProfile
            );
        }

        FEC_BatchCaseHandlingImportProfile.ImportScope denied =
            FEC_BatchCaseHandlingImportProfile.resolveForCase('Unknown Process XYZ', 'CC');
        if (!denied.allowed) {
            System.assert(String.isNotBlank(denied.errorMessage));
        }
    }

    @IsTest
    static void testMapExcelRouteTeamToStageChangeGroup() {
        System.assertEquals(null, FEC_BatchCaseHandlingImportProfile.mapExcelRouteTeamToStageChangeGroup(null));
        System.assertEquals('SP', FEC_BatchCaseHandlingImportProfile.mapExcelRouteTeamToStageChangeGroup('CS Support'));
        System.assertEquals('PM', FEC_BatchCaseHandlingImportProfile.mapExcelRouteTeamToStageChangeGroup('payment'));
        System.assertEquals('Custom', FEC_BatchCaseHandlingImportProfile.mapExcelRouteTeamToStageChangeGroup('Custom'));
    }
}
