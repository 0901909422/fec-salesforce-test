@isTest(seeAllData=true)
private class FEC_BusinessHoursTatUtilTest {
    private static Id getBusinessHoursId() {
        List<BusinessHours> rows = [
            SELECT Id
            FROM BusinessHours
            WHERE IsActive = TRUE
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].Id;
    }

    @isTest
    static void shouldTreatSaturdayAndSundayAsWeekend() {
        System.assertEquals(true, FEC_BusinessHoursTatUtil.isWeekendDate(Date.newInstance(2026, 5, 23)));
        System.assertEquals(true, FEC_BusinessHoursTatUtil.isWeekendDate(Date.newInstance(2026, 5, 24)));
        System.assertEquals(false, FEC_BusinessHoursTatUtil.isWeekendDate(Date.newInstance(2026, 5, 25)));
        System.assertEquals(false, FEC_BusinessHoursTatUtil.isWeekendDate(Date.newInstance(2026, 5, 22)));
    }

    @isTest
    static void shouldReturnZeroMsForRangeOnSaturdayOnly() {
        Id bhId = getBusinessHoursId();
        if (bhId == null) {
            return;
        }

        Datetime startDt = Datetime.newInstanceGmt(2026, 5, 23, 3, 0, 0);
        Datetime endDt = Datetime.newInstanceGmt(2026, 5, 23, 7, 0, 0);

        Long diffMs = FEC_BusinessHoursTatUtil.diffMsExcludingWeekends(bhId, startDt, endDt);
        System.assertEquals(0L, diffMs, 'Thứ Bảy không được tính vào TAT.');
    }

    @isTest
    static void shouldMatchBusinessHoursDiffOnWeekday() {
        Id bhId = getBusinessHoursId();
        if (bhId == null) {
            return;
        }

        Datetime startDt = Datetime.newInstanceGmt(2026, 5, 25, 2, 0, 0);
        Datetime endDt = Datetime.newInstanceGmt(2026, 5, 25, 3, 0, 0);

        Long expected = BusinessHours.diff(bhId, startDt, endDt);
        Long actual = FEC_BusinessHoursTatUtil.diffMsExcludingWeekends(bhId, startDt, endDt);

        System.assertEquals(expected, actual, 'Ngày thường phải khớp BusinessHours.diff.');
    }

    @isTest
    static void shouldReturnNullWhenBusinessHoursIdMissing() {
        Datetime startDt = Datetime.newInstanceGmt(2026, 5, 25, 2, 0, 0);
        Datetime endDt = Datetime.newInstanceGmt(2026, 5, 25, 3, 0, 0);
        System.assertEquals(
            null,
            FEC_BusinessHoursTatUtil.diffMsExcludingWeekends(null, startDt, endDt)
        );
    }
}
