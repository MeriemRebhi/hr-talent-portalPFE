// Full runtime test: generate questions then test the flow
String oppId = '006fj00000BF3X7AAL';   // sebei - Technique
String jobPostingId = '006fj00000AISuXAAX'; // Data Analyst IA

// Step 1: Check current state
Map<String, Object> info = TechnicalInterviewController.getInterviewInfo(oppId);
System.debug('=== STEP 1: Interview Info ===');
System.debug('candidateName: ' + info.get('candidateName'));
System.debug('jobTitle: ' + info.get('jobTitle'));
System.debug('hasProblems: ' + info.get('hasProblems'));
System.debug('jobPostingId: ' + info.get('jobPostingId'));

// Step 2: Generate questions if needed
if (!(Boolean) info.get('hasProblems')) {
    System.debug('=== STEP 2: Generating Questions ===');
    TechnicalQuestionService.generateQuestions(jobPostingId);
    System.debug('Queueable job enqueued. Questions will be generated asynchronously.');
    System.debug('Check generation status after a few seconds with:');
    System.debug('TechnicalQuestionService.getGenerationStatus(\'' + jobPostingId + '\')');
} else {
    System.debug('=== STEP 2: Questions already exist ===');
    
    // Step 3: Load problems
    List<Map<String, Object>> problems = TechnicalInterviewController.getProblems(jobPostingId);
    System.debug('=== STEP 3: Loaded ' + problems.size() + ' problems ===');
    for (Map<String, Object> p : problems) {
        System.debug('Problem: ' + p.get('problemType') + ' | ' + p.get('difficulty'));
    }
}
