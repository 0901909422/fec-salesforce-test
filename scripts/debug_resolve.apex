String template = '{{{User.AboutMe}}}{{{FEC_Additional_Info__c.FEC_Callback__c}}}';
System.debug('Before: ' + template);

// Step 1: convert triple → double
template = template.replaceAll(FEC_ConstantCommon.PATTERN_TRIPLE_BRACE, '{{$1}}');
System.debug('After triple convert: ' + template);

// Step 2: match user pattern
Pattern userPat = Pattern.compile(FEC_ConstantCommon.PATTERN_USER_MERGE_FIELD);
Matcher userMat = userPat.matcher(template);
System.debug('User pattern matches: ' + userMat.find());

// Reset
userMat = userPat.matcher(template);
while (userMat.find()) {
    System.debug('Matched: ' + userMat.group(0) + ' | field: ' + userMat.group(1));
}
