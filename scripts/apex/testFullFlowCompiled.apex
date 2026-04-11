// Test via compiled controller methods only (avoids phantom field issues in anon Apex)
Id testOppId = '006fj00000BF6A1AAL'; // Eya Boudidah

// Step 1: getInterviewInfo (already tested - works)
Map<String, Object> info = TechnicalInterviewController.getInterviewInfo(testOppId);
Id jobPostingId = (Id) info.get('jobPostingId');
Boolean hasProblems = (Boolean) info.get('hasProblems');
System.debug('jobPostingId: ' + jobPostingId);
System.debug('hasProblems: ' + hasProblems);

if (!hasProblems) {
    // Generate questions via compiled TechnicalQuestionService
    System.debug('No questions yet - queueing TechnicalQuestionService...');
    System.enqueueJob(new TechnicalQuestionService(jobPostingId));
    System.debug('Run again in 30 seconds to continue test');
} else {
    // Step 2: getProblems
    List<Map<String, Object>> problems = TechnicalInterviewController.getProblems(jobPostingId);
    System.debug('Problems: ' + problems.size());
    for (Map<String, Object> p : problems) {
        String txt = (String) p.get('problem');
        System.debug('  [' + p.get('type') + '/' + p.get('difficulty') + '] ' + txt.substring(0, Math.min(80, txt.length())));
    }
    
    // Step 3: submitInterviewResults (with a test score)
    Map<String, Object> submitResult = TechnicalInterviewController.submitInterviewResults(
        testOppId, 72.5, 5, 5, 2700
    );
    System.debug('=== Submit Results ===');
    for (String k : submitResult.keySet()) {
        System.debug('  ' + k + ': ' + submitResult.get(k));
    }
    
    // Step 4: Verify Technical_Interview__c was updated
    List<Technical_Interview__c> tis = [
        SELECT Status__c, Score__c, Composite_Score__c
        FROM Technical_Interview__c WHERE Opportunity__c = :testOppId LIMIT 1
    ];
    if (!tis.isEmpty()) {
        System.debug('=== TI Record ===');
        System.debug('  Status: ' + tis[0].Status__c);
        System.debug('  Score: ' + tis[0].Score__c);
        System.debug('  Composite: ' + tis[0].Composite_Score__c);
    }
    
    System.debug('FULL FLOW TEST COMPLETE!');
}
