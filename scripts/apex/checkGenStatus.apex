// Check generation status and loaded problems
String jobPostingId = '006fj00000AISuXAAX';

// Check status
Map<String, Object> status = TechnicalQuestionService.getGenerationStatus(jobPostingId);
System.debug('=== Generation Status ===');
System.debug('status: ' + status.get('status'));
System.debug('count: ' + status.get('count'));

// Load problems regardless of status
List<Map<String, Object>> problems = TechnicalInterviewController.getProblems(jobPostingId);
System.debug('=== Loaded ' + problems.size() + ' problems ===');
for (Integer i = 0; i < problems.size(); i++) {
    Map<String, Object> p = problems[i];
    System.debug('Problem ' + (i+1) + ': type=' + p.get('problemType') + ' | diff=' + p.get('difficulty') + ' | timeLimit=' + p.get('timeLimit'));
    String text = (String) p.get('problemText');
    if (text != null && text.length() > 100) text = text.substring(0, 100) + '...';
    System.debug('  Text: ' + text);
}
