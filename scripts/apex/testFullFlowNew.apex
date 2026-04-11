// Full flow test: generate questions → evaluate → submit results
Id testOppId = '006fj00000BF6A1AAL'; // Eya Boudidah
Id jobPostingId = '006fj00000AIUY9AAP'; // Développeur Backend Java

// Check existing questions
Integer qCount = [SELECT COUNT() FROM Technical_Question__c WHERE Job_Posting__c = :jobPostingId];
System.debug('Existing questions for job: ' + qCount);

if (qCount == 0) {
    // Need to generate questions first
    System.debug('No questions yet - triggering generation...');
    System.enqueueJob(new TechnicalQuestionService(jobPostingId));
    System.debug('Generation queued - run this script again in 30 seconds');
} else {
    System.debug(qCount + ' questions found - testing evaluate flow');
    
    // Get problems
    List<Map<String, Object>> problems = TechnicalInterviewController.getProblems(jobPostingId);
    System.debug('getProblems returned: ' + problems.size() + ' problems');
    for (Map<String, Object> p : problems) {
        System.debug('  Q: ' + ((String)p.get('problem')).substring(0, Math.min(80, ((String)p.get('problem')).length())) + '...');
        System.debug('    Type: ' + p.get('type') + ' | Difficulty: ' + p.get('difficulty'));
    }
    
    // Test submitInterviewResults
    Map<String, Object> submitResult = TechnicalInterviewController.submitInterviewResults(
        testOppId, 75.0, 5, 5, 3600
    );
    System.debug('=== Submit Results ===');
    for (String key : submitResult.keySet()) {
        System.debug('  ' + key + ': ' + submitResult.get(key));
    }
    
    // Verify the Technical_Interview__c record was updated
    Technical_Interview__c ti = [
        SELECT Status__c, Score__c, Composite_Score__c
        FROM Technical_Interview__c WHERE Opportunity__c = :testOppId LIMIT 1
    ];
    System.debug('=== Technical_Interview__c after submit ===');
    System.debug('  Status: ' + ti.Status__c);
    System.debug('  Score: ' + ti.Score__c);
    System.debug('  Composite: ' + ti.Composite_Score__c);
}
