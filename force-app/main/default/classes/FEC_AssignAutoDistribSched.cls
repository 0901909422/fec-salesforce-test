// Scheduled Apex: gọi FEC_CaseAssignmentAutoDistributeService.executeNow() mỗi 5 phút.
// Một job duy nhất tự schedule lần chạy kế tiếp (không cần 12 Cron như trước).
//
// Sau deploy, chạy một lần (Anonymous / Developer Console):
//   FEC_AssignAutoDistribSched.startFiveMinuteChain();
// (Có thể gọi scheduleEveryFiveMinutes() — giờ alias cùng hành vi trên.)
//
public without sharing class FEC_AssignAutoDistribSched implements Schedulable {
    /** Prefix tên job chain mới; dùng để LIKE khi abort bản ghi trùng / chain hỏng. */
    public static final String JOB_NAME_PREFIX = 'FEC_AssignAutoDistribSched';

    /**
     * Tên job cũ (12 job mỗi :00,:05,…) và :00/:30 — dùng khi bootstrap để dọn trước khi gắn chain mới.
     */
    public static final String LEGACY_NAME_PATTERN = 'FEC Case Assignment Auto Distribute%';

    public void execute(SchedulableContext context) {
        FEC_CaseAssignmentAutoDistributeService.executeNow();

        Id selfCronTriggerId = context != null ? context.getTriggerId() : null;

        String chainLike = JOB_NAME_PREFIX + ':%';
        for (CronTrigger cronJob : [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :chainLike
        ]) {
            if (selfCronTriggerId != null && cronJob.Id == selfCronTriggerId) {
                continue;
            }
            System.abortJob(cronJob.Id);
        }

        scheduleNextRun();
    }

    /**
     * Khởi chạy chuỗi 5 phút: hủy mọi job Case Assignment auto distribute (legacy + chain cũ), rồi đăng ký lần chạy kế tiếp sau 5 phút.
     */
    public static void startFiveMinuteChain() {
        String chainLike = JOB_NAME_PREFIX + ':%';
        List<CronTrigger> toAbort = [
            SELECT Id
            FROM CronTrigger
            WHERE CronJobDetail.Name LIKE :LEGACY_NAME_PATTERN OR CronJobDetail.Name LIKE :chainLike
        ];
        for (CronTrigger ct : toAbort) {
            System.abortJob(ct.Id);
        }
        scheduleNextRun();
    }

    /**
     * Lên lịch một lần chạy tại now+5 phút; tên job unique để không trùng quota tên.
     * Cron 7 tham số (kèm năm) — một thời điểm cụ thể theo timezone ngữ cảnh Apex.
     */
    public static void scheduleNextRun() {
        DateTime fiveMinutesLater = System.now().addMinutes(5);
        String uniqueName =
            JOB_NAME_PREFIX +
            ':' +
            String.valueOf(fiveMinutesLater.getTime());
        String cronExpression = String.format(
            '{0} {1} {2} {3} {4} ? {5}',
            new List<String>{
                String.valueOf(fiveMinutesLater.second()),
                String.valueOf(fiveMinutesLater.minute()),
                String.valueOf(fiveMinutesLater.hour()),
                String.valueOf(fiveMinutesLater.day()),
                String.valueOf(fiveMinutesLater.month()),
                String.valueOf(fiveMinutesLater.year())
            }
        );
        System.schedule(uniqueName, cronExpression, new FEC_AssignAutoDistribSched());
    }

    /**
     * @deprecated Dùng startFiveMinuteChain(). Giữ để script cũ không vỡ — không còn tạo 12 job.
     */
    public static List<String> scheduleEveryFiveMinutes() {
        startFiveMinuteChain();
        return new List<String>();
    }

    /**
     * @deprecated Dùng startFiveMinuteChain().
     */
    public static List<String> scheduleHalfHourlyJobs() {
        startFiveMinuteChain();
        return new List<String>();
    }
}
