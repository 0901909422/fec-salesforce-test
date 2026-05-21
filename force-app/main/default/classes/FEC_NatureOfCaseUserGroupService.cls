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
   * Các FEC_User_Group__c của user CS Frontline / CS Back Office (trừ CX).
   * Dùng gộp vào phía FEC_Nature_of_Case__c.FEC_User_Group__c khi lọc NOC (xem buildNatureOfCaseUserGroupFilterClause).
   *
   * Sample:
   *   currentUserGroup = 'Team A'
   *   Kết quả: ['Team A', 'Team B', 'Team C'] (distinct từ User CS FL/BO, không có CX)
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
   * additionalRolelst gộp vào phía NOC: khớp nếu NOC INCLUDES user hoặc INCLUDES bất kỳ nhóm trong additional.
   * User thuộc additionalRolelst (pool CS FL/BO) nhưng không có trên NOC → không lọc FEC_User_Group__c.
   *
   * --- Case 1: User thuộc pool CS FL/BO ---
   * Input:
   *   rolelst = ['Team A']
   *   additionalRolelst = ['Team A', 'Team B', 'Team C']
   * Output: '' (không thêm điều kiện FEC_User_Group__c)
   *
   * Sample query:
   *   SELECT Id FROM FEC_Nature_of_Case__c
   *   WHERE FEC_Product_Type__c = :productType
   *     AND FEC_Category__c = :category
   *     ... -- không có AND FEC_User_Group__c
   *
   * Kết quả (NOC.FEC_User_Group__c):
   *   NOC-1: 'Team X' only     -> Lấy (user Team A không trên NOC vẫn được)
   *   NOC-2: 'Team A'          -> Lấy
   *   NOC-3: 'Team B'          -> Lấy
   *
   * --- Case 2: User không thuộc pool (vd CX) ---
   * Input:
   *   rolelst = ['CX Support']
   *   additionalRolelst = ['Team A', 'Team B']
   * Output:
   *   AND (FEC_User_Group__c INCLUDES ('CX Support')
   *        OR FEC_User_Group__c INCLUDES ('Team A')
   *        OR FEC_User_Group__c INCLUDES ('Team B'))
   *
   * Sample query:
   *   SELECT Id FROM FEC_Nature_of_Case__c
   *   WHERE ...
   *     AND (FEC_User_Group__c INCLUDES ('CX Support')
   *          OR FEC_User_Group__c INCLUDES ('Team A')
   *          OR FEC_User_Group__c INCLUDES ('Team B'))
   *
   * Kết quả (coi NOC.FEC_User_Group__c đã gộp thêm Team A, Team B):
   *   NOC-1: 'CX Support'      -> Lấy (INCLUDES user)
   *   NOC-2: 'Team A'          -> Lấy (INCLUDES nhóm trong additional)
   *   NOC-3: 'Team B;Team C'   -> Lấy (INCLUDES Team B)
   *   NOC-4: 'Team X' only     -> Không lấy
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
    List<String> orParts = new List<String>{
      'FEC_User_Group__c INCLUDES (\'' +
      String.escapeSingleQuotes(userGroup) +
      '\')'
    };
    for (String g : additional) {
      orParts.add(
        'FEC_User_Group__c INCLUDES (\'' + String.escapeSingleQuotes(g) + '\')'
      );
    }
    return orParts.size() == 1
      ? 'AND ' + orParts[0]
      : 'AND (' + String.join(orParts, ' OR ') + ')';
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
