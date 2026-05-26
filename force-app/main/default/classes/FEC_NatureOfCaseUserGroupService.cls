/**
 * User group dùng filter FEC_User_Group__c INCLUDES trên Nature of Case / Case Stage.
 */
public without sharing class FEC_NatureOfCaseUserGroupService {
  public static final String FRONT_LINE = 'CS Frontline';
  public static final String BACK_OFFICE = 'CS Back Office';
  private static final String USER_GROUP_CX = 'CX';
  private static final Set<String> CS_DIVISION_GROUPS = new Set<String>{
    FRONT_LINE,
    BACK_OFFICE
  };

  /**
   * Các FEC_User_Group__c từ user CS Frontline / CS Back Office (trừ CX).
   * Dùng làm additionalRolelst: rolelst[0] ∈ list này → bypass lọc FEC_User_Group__c trên NOC.
   *
   * Sample:
   *   Kết quả: ['Team A', 'Team B', 'Team C'] (distinct User CS FL/BO, không có CX)
   */
  public static List<String> buildRoleListForIncludes(String currentUserGroup) {
    Set<String> groups = new Set<String>();
    for (AggregateResult ar : [
      SELECT FEC_User_Group__c
      FROM User
      WHERE
        IsActive = TRUE
        AND FEC_User_Group__c != NULL
        AND FEC_User_Group__c != :USER_GROUP_CX
        AND FEC_User_Division_Group__c IN :CS_DIVISION_GROUPS
      GROUP BY FEC_User_Group__c
    ]) {
      String grp = (String) ar.get('FEC_User_Group__c');
      if (String.isNotBlank(grp)) {
        groups.add(grp);
      }
    }
    return new List<String>(groups);
  }

  /**
   * Điều kiện WHERE cho FEC_Nature_of_Case__c.FEC_User_Group__c.
   * Lấy NOC khi một trong hai điều kiện đúng:
   *   A) rolelst[0] thuộc additionalRolelst (pool CS FL/BO)
   *   B) FEC_Nature_of_Case__c.FEC_User_Group__c INCLUDES rolelst[0]
   *
   * --- A: User CS, nhóm user trong additionalRolelst ---
   * Output: '' (không thêm điều kiện FEC_User_Group__c)
   *
   * --- B: User không thuộc pool ---
   * Output: AND FEC_User_Group__c INCLUDES ('<nhóm user>')
   */
  public static String buildNatureOfCaseUserGroupFilterClause(
    List<String> rolelst,
    List<String> additionalRolelst
  ) {
    if (rolelst == null || rolelst.isEmpty()) {
      return '';
    }
    String userGroup = rolelst[0];
    if (String.isBlank(userGroup)) {
      return '';
    }
    Set<String> additional = new Set<String>();
    if (additionalRolelst != null) {
      for (String g : additionalRolelst) {
        if (String.isNotBlank(g)) {
          additional.add(g);
        }
      }
    }
    if (additional.contains(userGroup)) {
      return '';
    }
    return 'AND FEC_User_Group__c INCLUDES (\'' +
      String.escapeSingleQuotes(userGroup) +
      '\')';
  }

  /**
   * AND FEC_User_Group__c INCLUDES (user đăng nhập) — Case Stage / Stage Screen; rỗng nếu không có nhóm.
   *
   * Sample:
   *   rolelst = ['Team A']
   *   Output: AND FEC_User_Group__c INCLUDES ('Team A')
   *
   * Sample query (FEC_Stage_Screen__c):
   *   SELECT Id FROM FEC_Stage_Screen__c
   *   WHERE FEC_Case_Stage__c = '...'
   *     AND FEC_User_Group__c INCLUDES ('Team A')
   *
   * Kết quả:
   *   Screen-1: FEC_User_Group__c = 'Team A'     -> Lấy
   *   Screen-2: FEC_User_Group__c = 'Team A;Team B' -> Lấy
   *   Screen-3: FEC_User_Group__c = 'Team B'     -> Không lấy
   */
  public static String buildUserGroupIncludesWhereClause(List<String> rolelst) {
    if (rolelst == null || rolelst.isEmpty()) {
      return '';
    }
    String userGroup = rolelst[0];
    if (String.isBlank(userGroup)) {
      return '';
    }
    return 'AND FEC_User_Group__c INCLUDES (\'' +
      String.escapeSingleQuotes(userGroup) +
      '\')';
  }
}
