public without sharing class GamingTestController {

    // ═══════════════════════════════════════
    //  GET TEST INFO — chargé par le composant (v2)
    // ═══════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getTestInfo(Id oppId) {
        Opportunity opp = [
            SELECT Id, Name, StageName,
                   Gaming_Test_DateTime__c, Gaming_Test_Score__c, Gaming_Test_Status__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        // Résoudre le Job Title et Job Posting ID via Lead.Description → JOB_ID
        String jobTitle = '';
        Id jobPostingId = null;
        List<Lead> leads = [
            SELECT Description FROM Lead
            WHERE ConvertedOpportunityId = :oppId AND IsConverted = true
            LIMIT 1
        ];
        if (!leads.isEmpty() && !String.isBlank(leads[0].Description)) {
            for (String line : leads[0].Description.split('\n')) {
                if (line.startsWith('JOB_ID:')) {
                    String jId = line.replace('JOB_ID:', '').trim();
                    try {
                        jobPostingId = (Id) jId;
                        List<Opportunity> jobs = [SELECT Name FROM Opportunity WHERE Id = :jobPostingId LIMIT 1];
                        if (!jobs.isEmpty()) jobTitle = jobs[0].Name;
                    } catch (Exception e) { /* ignore */ }
                    break;
                }
            }
        }
        if (String.isBlank(jobTitle)) jobTitle = opp.Name;

        // Check if dynamic questions exist for this job posting
        Boolean hasDynamicQuestions = false;
        if (jobPostingId != null) {
            Integer qCount = [SELECT COUNT() FROM Gaming_Question__c WHERE Job_Posting__c = :jobPostingId];
            hasDynamicQuestions = qCount >= 10;
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('oppId',            opp.Id);
        result.put('candidateName',    opp.Name);
        result.put('jobTitle',         jobTitle);
        result.put('jobPostingId',     jobPostingId);
        result.put('stageName',        opp.StageName);
        result.put('alreadyCompleted', opp.Gaming_Test_Status__c == 'Completed');
        result.put('existingScore',    opp.Gaming_Test_Score__c);
        result.put('scheduledDate',    opp.Gaming_Test_DateTime__c);
        result.put('isScheduled',      opp.Gaming_Test_DateTime__c != null);
        result.put('hasDynamicQuestions', hasDynamicQuestions);
        return result;
    }

    // ═══════════════════════════════════════
    //  GET QUESTIONS — sert 10 questions aléatoires SANS les réponses
    // ═══════════════════════════════════════
    @AuraEnabled
    public static List<Map<String, Object>> getTestQuestions(Id jobPostingId) {
        if (jobPostingId == null) {
            throw new AuraHandledException('ID de l\'offre manquant.');
        }

        // Fetch all questions for this job posting, random order
        List<Gaming_Question__c> allQuestions = [
            SELECT Id, Question_Text__c, Option_A__c, Option_B__c, Option_C__c, Option_D__c,
                   Option_E__c, Question_Type__c, Difficulty__c, Time_Limit__c
            FROM Gaming_Question__c
            WHERE Job_Posting__c = :jobPostingId
        ];

        // Shuffle using random sort
        List<Gaming_Question__c> shuffled = new List<Gaming_Question__c>();
        List<Integer> indices = new List<Integer>();
        for (Integer i = 0; i < allQuestions.size(); i++) indices.add(i);

        while (!indices.isEmpty() && shuffled.size() < 10) {
            Integer randIdx = Math.mod(Math.abs(Crypto.getRandomInteger()), indices.size());
            shuffled.add(allQuestions[indices.remove(randIdx)]);
        }

        // Map to response — NO correct answer sent to client!
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Gaming_Question__c q : shuffled) {
            Map<String, Object> qMap = new Map<String, Object>();
            qMap.put('id',       q.Id);
            qMap.put('question', q.Question_Text__c);
            qMap.put('type',     q.Question_Type__c);
            qMap.put('diff',     q.Difficulty__c);
            qMap.put('time',     q.Time_Limit__c);

            // Build options list
            List<String> opts = new List<String>();
            if (!String.isBlank(q.Option_A__c)) opts.add(q.Option_A__c);
            if (!String.isBlank(q.Option_B__c)) opts.add(q.Option_B__c);
            if (!String.isBlank(q.Option_C__c)) opts.add(q.Option_C__c);
            if (!String.isBlank(q.Option_D__c)) opts.add(q.Option_D__c);
            if (!String.isBlank(q.Option_E__c)) opts.add(q.Option_E__c);
            qMap.put('opts', opts);

            result.add(qMap);
        }

        return result;
    }

    // ═══════════════════════════════════════
    //  VALIDATE ANSWER — vérifie côté serveur
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> validateAnswer(Id questionId, String selectedAnswer, Decimal timeSpent) {
        Gaming_Question__c q = [
            SELECT Id, Correct_Answer__c, Question_Type__c, Time_Limit__c
            FROM Gaming_Question__c
            WHERE Id = :questionId
            LIMIT 1
        ];

        Boolean isCorrect;
        if (q.Question_Type__c == 'order') {
            // For order questions, selectedAnswer is the items joined by |
            isCorrect = q.Correct_Answer__c == selectedAnswer;
        } else {
            // For MCQ/Puzzle, selectedAnswer is A, B, C, or D
            isCorrect = q.Correct_Answer__c == selectedAnswer;
        }

        Integer points = 0;
        Boolean speedBonus = false;
        if (isCorrect) {
            points = 10;
            if (timeSpent < q.Time_Limit__c * 0.5) {
                points += 2;
                speedBonus = true;
            }
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('correct',    isCorrect);
        result.put('points',     points);
        result.put('speedBonus', speedBonus);
        // Return the correct answer so LWC can show green/red feedback
        result.put('correctAnswer', q.Correct_Answer__c);
        return result;
    }

    // ═══════════════════════════════════════
    //  SUBMIT — sauvegarde score + auto-avance
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> submitTestResults(
        Id oppId, Decimal score, Integer correctCount,
        Integer totalQuestions, Integer timeSpentSeconds
    ) {
        Opportunity opp = [SELECT Id, StageName FROM Opportunity WHERE Id = :oppId LIMIT 1];

        opp.Gaming_Test_Score__c  = score;
        opp.Gaming_Test_Status__c = 'Completed';

        String recommendation;
        Boolean passed;

        if (score >= 80) {
            recommendation = 'Excellent ! Vous êtes avancé au stage Technique.';
            opp.StageName = 'Technique';
            passed = true;
        } else if (score >= 60) {
            recommendation = 'Bon résultat ! Vous passez au stage Technique.';
            opp.StageName = 'Technique';
            passed = true;
        } else if (score >= 40) {
            recommendation = 'Résultat moyen. Votre dossier sera évalué par le recruteur.';
            passed = false;
        } else {
            recommendation = 'Score insuffisant. Candidature non retenue pour cette étape.';
            opp.StageName = 'Closed Lost';
            passed = false;
        }

        update opp;

        // Send ATS report email with PDF (async to avoid callout-after-DML)
        try {
            GamingTestReportController.sendReportAsync(oppId, score, correctCount, totalQuestions, timeSpentSeconds, passed);
        } catch (Exception e) {
            System.debug('ATS Report send error: ' + e.getMessage());
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('score',          score);
        result.put('passed',         passed);
        result.put('recommendation', recommendation);
        result.put('newStage',       opp.StageName);
        return result;
    }
}
