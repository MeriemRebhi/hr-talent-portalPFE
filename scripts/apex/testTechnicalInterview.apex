// ═══════════════════════════════════════
//  Test TechnicalQuestionService + TechnicalInterviewController
// ═══════════════════════════════════════

// 1) Find a Job Posting (Opportunity with RecordType = Job_Posting)
List<Opportunity> jobs = [
    SELECT Id, Name FROM Opportunity
    WHERE RecordType.DeveloperName = 'Job_Posting' AND IsClosed = false
    LIMIT 1
];

if (jobs.isEmpty()) {
    System.debug('❌ Aucune offre ouverte trouvée. Créez une offre depuis le dashboard.');
} else {
    Opportunity job = jobs[0];
    System.debug('✅ Job Posting trouvé : ' + job.Name + ' (Id: ' + job.Id + ')');

    // 2) Check if Technical Questions already exist
    Integer existingCount = [SELECT COUNT() FROM Technical_Question__c WHERE Job_Posting__c = :job.Id];
    System.debug('   Questions techniques existantes : ' + existingCount);

    if (existingCount < 4) {
        // 3) Launch generation (Queueable)
        System.debug('   Lancement de la génération IA...');
        TechnicalQuestionService.generateQuestions(job.Id);
        System.debug('   ⏳ Queueable enqueued. Vérifiez dans 10-20s avec getGenerationStatus.');
    } else {
        System.debug('   ✅ Questions déjà générées. Pas besoin de relancer.');
    }

    // 4) Find an Application (candidate) at Technique stage
    List<Opportunity> apps = [
        SELECT Id, Name, StageName, Gaming_Test_Score__c, Score_Matching__c,
               Technical_Interview_DateTime__c, Technical_Interview_Status__c
        FROM Opportunity
        WHERE RecordType.DeveloperName = 'Application'
        AND StageName = 'Technique'
        LIMIT 1
    ];

    if (!apps.isEmpty()) {
        Opportunity app = apps[0];
        System.debug('');
        System.debug('✅ Candidature Technique trouvée : ' + app.Name + ' (Id: ' + app.Id + ')');
        System.debug('   Stage: ' + app.StageName);
        System.debug('   Gaming Score: ' + app.Gaming_Test_Score__c);
        System.debug('   CV Score: ' + app.Score_Matching__c);
        System.debug('   Tech Status: ' + app.Technical_Interview_Status__c);

        // 5) Test getInterviewInfo
        Map<String, Object> info = TechnicalInterviewController.getInterviewInfo(app.Id);
        System.debug('');
        System.debug('── getInterviewInfo ──');
        System.debug('   candidateName: ' + info.get('candidateName'));
        System.debug('   jobTitle: ' + info.get('jobTitle'));
        System.debug('   jobPostingId: ' + info.get('jobPostingId'));
        System.debug('   hasProblems: ' + info.get('hasProblems'));
        System.debug('   alreadyCompleted: ' + info.get('alreadyCompleted'));

        // 6) If problems exist, get them
        Id jpId = (Id) info.get('jobPostingId');
        if (jpId != null && (Boolean) info.get('hasProblems')) {
            List<Map<String, Object>> problems = TechnicalInterviewController.getProblems(jpId);
            System.debug('');
            System.debug('── getProblems (' + problems.size() + ') ──');
            for (Map<String, Object> p : problems) {
                String problemText = ((String) p.get('problem'));
                String preview = problemText != null && problemText.length() > 80
                    ? problemText.substring(0, 80) + '...'
                    : problemText;
                System.debug('   [' + p.get('type') + '/' + p.get('difficulty') + '] ' + preview);
            }
        }
    } else {
        System.debug('');
        System.debug('ℹ️ Aucune candidature au stage Technique. Test partiel uniquement.');
    }
}

System.debug('');
System.debug('═══ TEST TERMINÉ ═══');
