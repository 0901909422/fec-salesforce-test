public without sharing class FEC_BusinessHoursTatUtil {
    private static final String TAT_TIMEZONE = FEC_ConstantCommon.USER_TIMEZONE_VIETNAM;
    private static final Integer VN_UTC_OFFSET_HOURS = 7;

    public static Long diffMsExcludingWeekends(
        Id businessHoursId,
        Datetime startDt,
        Datetime endDt
    ) {
        if (businessHoursId == null || startDt == null || endDt == null) {
            return null;
        }
        if (endDt <= startDt) {
            return 0L;
        }

        Date startDate = toLocalDate(startDt);
        Date endDate = toLocalDate(endDt);
        Long totalMs = 0L;

        for (Date d = startDate; d <= endDate; d = d.addDays(1)) {
            if (isWeekendDate(d)) {
                continue;
            }

            Datetime dayStart = localDayStart(d);
            Datetime dayEndExclusive = dayStart.addDays(1);
            Datetime segStart = startDt > dayStart ? startDt : dayStart;
            Datetime segEnd = endDt < dayEndExclusive ? endDt : dayEndExclusive;

            if (segEnd <= segStart) {
                continue;
            }

            Long dayDiffMs = BusinessHours.diff(businessHoursId, segStart, segEnd);
            if (dayDiffMs != null && dayDiffMs > 0) {
                totalMs += dayDiffMs;
            }
        }

        return totalMs;
    }

    @TestVisible
    private static Boolean isWeekendDate(Date localDate) {
        Datetime noonLocal = localDayStart(localDate).addHours(12);
        Integer isoDayOfWeek = Integer.valueOf(noonLocal.format('u', TAT_TIMEZONE));
        return isoDayOfWeek >= 6;
    }

    private static Date toLocalDate(Datetime dt) {
        return Date.valueOf(dt.format(FEC_ConstantCommon.DATE_FORMAT, TAT_TIMEZONE));
    }

    private static Datetime localDayStart(Date localDate) {
        return Datetime.newInstanceGmt(
            localDate.year(),
            localDate.month(),
            localDate.day()
        ).addHours(-VN_UTC_OFFSET_HOURS);
    }
}