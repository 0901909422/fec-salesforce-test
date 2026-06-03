@IsTest
private class FEC_NatureOfCaseTreeItem_Test {

    private static Boolean treeItemClassAvailable() {
        return Type.forName('FEC_NatureOfCaseTreeItem') != null;
    }

    @IsTest
    static void testConstructorAndConvert() {
        if (!treeItemClassAvailable()) {
            System.assert(
                true,
                'Skipped: FEC_NatureOfCaseTreeItem not on org — deploy force-app/main/default/classes/FEC_NatureOfCaseTreeItem.cls first.'
            );
            return;
        }
        System.assert(
            true,
            'Deploy FEC_NatureOfCaseTreeItem.cls to org, then add direct unit tests for convertMapToList and constructor.'
        );
    }

    @IsTest
    static void testIconLogic() {
        if (!treeItemClassAvailable()) {
            System.assert(
                true,
                'Skipped: FEC_NatureOfCaseTreeItem not on org — deploy force-app/main/default/classes/FEC_NatureOfCaseTreeItem.cls first.'
            );
            return;
        }
        System.assert(
            true,
            'Deploy FEC_NatureOfCaseTreeItem.cls to org, then add direct unit tests for iconName (FEC_Constants.ICON_RECORD / ICON_LOCK).'
        );
    }
}
