public without sharing class FEC_SessionUtil {
    public static Boolean forceClearSessions(Id userId) {
        try {
            List<AuthSession> sessions = [
                SELECT Id, UsersId, SessionType, LoginType
                FROM AuthSession
                WHERE UsersId = :userId
                AND SessionType IN ('UI')
            ];
            if (!sessions.isEmpty()) {
                delete sessions;
            }
            return true;
        } catch (Exception e) {
            System.debug('Clear session failed for userId=' + userId + ': ' + e.getMessage());
            return false;
        }
    }
}
