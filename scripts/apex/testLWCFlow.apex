// Simulate exact LWC flow for oppId=006fj00000BF3X7AAL
String oppId = '006fj00000BF3X7AAL';

// Step 1: getInterviewInfo (like LWC _loadInterview)
Map<String, Object> info = TechnicalInterviewController.getInterviewInfo(oppId);
System.debug('=== getInterviewInfo ===');
System.debug('candidateName: ' + info.get('candidateName'));
System.debug('jobTitle: ' + info.get('jobTitle'));
System.debug('jobPostingId: ' + info.get('jobPostingId'));
System.debug('hasProblems: ' + info.get('hasProblems'));
System.debug('alreadyCompleted: ' + info.get('alreadyCompleted'));

// Step 2: getProblems (like LWC)
Id jobPostingId = (Id) info.get('jobPostingId');
List<Map<String, Object>> problems = TechnicalInterviewController.getProblems(jobPostingId);
System.debug('=== getProblems (' + problems.size() + ') ===');
for (Integer i = 0; i < problems.size(); i++) {
    Map<String, Object> p = problems[i];
    System.debug('Problem ' + (i+1) + ':');
    System.debug('  id=' + p.get('id'));
    System.debug('  problem=' + ((String)p.get('problem')).left(80));
    System.debug('  type=' + p.get('type'));
    System.debug('  difficulty=' + p.get('difficulty'));
    System.debug('  timeLimit=' + p.get('timeLimit'));
}

// Step 3: Test evaluateAnswer with first question
if (!problems.isEmpty()) {
    Id questionId = (Id) problems[0].get('id');
    String testAnswer = 'def count_duplicates(lst):\n    from collections import Counter\n    counts = Counter(lst)\n    return {k: v for k, v in counts.items() if v > 1}';
    System.debug('=== Calling evaluateAnswer for Q1 ===');
    
    try {
        Map<String, Object> evalResult = TechnicalInterviewController.evaluateAnswer(questionId, testAnswer, 120);
        System.debug('Score: ' + evalResult.get('score'));
        System.debug('Feedback: ' + ((String)evalResult.get('feedback')).left(200));
        System.debug('CriteriaResults: ' + evalResult.get('criteriaResults'));
    } catch (Exception e) {
        System.debug('Evaluate error: ' + e.getMessage());
    }
}
