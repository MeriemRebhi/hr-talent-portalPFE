/**
 * TechnicalInterviewController
 * ─────────────────────────────
 * Controller pour l'entretien technique assisté par IA.
 *
 * Flux :
 *   1. Recruteur planifie l'entretien (meet + exercices IA)
 *   2. Candidat ouvre le portail et résout les exercices en temps réel
 *   3. L'IA évalue chaque réponse via Groq (logique, qualité, complexité)
 *   4. Score composite calculé (50% technique + 25% gaming + 25% CV)
 *   5. Manager valide ou ajuste le score final
 */
public without sharing class TechnicalInterviewController {

    private static final String GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
    private static final String GROQ_MODEL    = 'llama-3.3-70b-versatile';
    private static final String SITE_URL      = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2';

    // ═══════════════════════════════════════
    //  GET INTERVIEW INFO — page d'accueil candidat
    // ═══════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getInterviewInfo(Id oppId) {
        Opportunity opp = [
            SELECT Id, Name, StageName, AccountId, Score_Matching__c
            FROM Opportunity WHERE Id = :oppId LIMIT 1
        ];

        // Get or initialize Technical_Interview__c record
        List<Technical_Interview__c> tiList = [
            SELECT Id, Interview_DateTime__c, Duration__c, Status__c,
                   Score__c, Meet_Link__c, Composite_Score__c
            FROM Technical_Interview__c
            WHERE Opportunity__c = :oppId LIMIT 1
        ];
        Technical_Interview__c ti = tiList.isEmpty() ? new Technical_Interview__c() : tiList[0];

        // Candidate name via Lead
        String candidateName = 'Candidat';
        List<Lead> leads = [
            SELECT FirstName, LastName FROM Lead
            WHERE ConvertedOpportunityId = :oppId AND IsConverted = true LIMIT 1
        ];
        if (!leads.isEmpty()) {
            candidateName = ((leads[0].FirstName != null ? leads[0].FirstName : '') + ' ' +
                            (leads[0].LastName != null ? leads[0].LastName : '')).trim();
        }

        // Job posting name
        String jobTitle = opp.Name;
        Id jobPostingId = null;
        if (!leads.isEmpty()) {
            Lead l = [SELECT Description FROM Lead WHERE Id = :leads[0].Id LIMIT 1];
            if (l.Description != null) {
                for (String line : l.Description.split('\n')) {
                    if (line.startsWith('JOB_ID:')) {
                        try {
                            jobPostingId = (Id) line.replace('JOB_ID:', '').trim();
                            List<Opportunity> jobs = [SELECT Name FROM Opportunity WHERE Id = :jobPostingId LIMIT 1];
                            if (!jobs.isEmpty()) jobTitle = jobs[0].Name;
                        } catch (Exception e) { /* ignore */ }
                        break;
                    }
                }
            }
        }

        // Check if dynamic questions exist
        Integer qCount = 0;
        if (jobPostingId != null) {
            qCount = [SELECT COUNT() FROM Technical_Question__c WHERE Job_Posting__c = :jobPostingId];
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('oppId', opp.Id);
        result.put('candidateName', candidateName);
        result.put('jobTitle', jobTitle);
        result.put('jobPostingId', jobPostingId);
        result.put('stageName', opp.StageName);
        result.put('alreadyCompleted', ti.Status__c == 'Completed');
        result.put('existingScore', ti.Score__c);
        result.put('scheduledDate', ti.Interview_DateTime__c);
        result.put('isScheduled', ti.Interview_DateTime__c != null);
        result.put('hasProblems', qCount >= 4);
        result.put('meetLink', ti.Meet_Link__c);
        result.put('duration', ti.Duration__c);
        result.put('gamingScore', null);
        result.put('matchingScore', opp.Score_Matching__c);
        return result;
    }

    // ═══════════════════════════════════════
    //  GET PROBLEMS — exercices pour le candidat
    //  (solution attendue JAMAIS envoyée au client)
    // ═══════════════════════════════════════
    @AuraEnabled
    public static List<Map<String, Object>> getProblems(Id jobPostingId) {
        List<Technical_Question__c> questions = [
            SELECT Id, Problem_Text__c, Problem_Type__c, Difficulty__c, Time_Limit__c
            FROM Technical_Question__c
            WHERE Job_Posting__c = :jobPostingId
            ORDER BY Difficulty__c ASC
            LIMIT 5
        ];

        List<Map<String, Object>> problems = new List<Map<String, Object>>();
        for (Technical_Question__c q : questions) {
            Map<String, Object> p = new Map<String, Object>();
            p.put('id', q.Id);
            p.put('problem', q.Problem_Text__c);
            p.put('type', q.Problem_Type__c);
            p.put('difficulty', q.Difficulty__c);
            p.put('timeLimit', q.Time_Limit__c);
            problems.add(p);
        }
        return problems;
    }

    // ═══════════════════════════════════════
    //  EVALUATE ANSWER — IA évalue la réponse du candidat
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> evaluateAnswer(Id questionId, String candidateAnswer, Decimal timeSpent) {
        Technical_Question__c q = [
            SELECT Id, Problem_Text__c, Problem_Type__c, Expected_Solution__c,
                   Evaluation_Criteria__c, Time_Limit__c
            FROM Technical_Question__c WHERE Id = :questionId LIMIT 1
        ];

        // Call Groq to evaluate the answer
        Map<String, Object> evaluation = callGroqForEvaluation(
            q.Problem_Text__c, q.Problem_Type__c, q.Expected_Solution__c,
            q.Evaluation_Criteria__c, candidateAnswer
        );

        Decimal score = (Decimal) evaluation.get('score');
        String feedback = (String) evaluation.get('feedback');

        // Speed bonus : +5 points si répondu en moins de 50% du temps
        Boolean speedBonus = false;
        if (timeSpent < q.Time_Limit__c * 0.5) {
            score = Math.min(100, score + 5);
            speedBonus = true;
        }

        // Persist answer + evaluation on the record
        q.Candidate_Answer__c = candidateAnswer.left(10000);
        q.AI_Score__c = score;
        q.AI_Feedback__c = feedback;
        update q;

        Map<String, Object> result = new Map<String, Object>();
        result.put('score', score);
        result.put('feedback', feedback);
        result.put('speedBonus', speedBonus);
        result.put('criteriaResults', evaluation.get('criteriaResults'));
        return result;
    }

    // ═══════════════════════════════════════
    //  GROQ EVALUATION CALL
    // ═══════════════════════════════════════
    private static Map<String, Object> callGroqForEvaluation(
        String problem, String problemType, String expectedSolution,
        String criteria, String candidateAnswer
    ) {
        List<AI_Configuration__c> configs = [SELECT Groq_API_Key__c FROM AI_Configuration__c LIMIT 1];
        if (configs.isEmpty() || String.isBlank(configs[0].Groq_API_Key__c)) {
            throw new AuraHandledException('Clé API Groq non configurée.');
        }
        String apiKey = configs[0].Groq_API_Key__c;

        String criteriaList = '';
        if (String.isNotBlank(criteria)) {
            Integer idx = 1;
            for (String c : criteria.split('\\|')) {
                criteriaList += idx + '. ' + c.trim() + '\n';
                idx++;
            }
        }

        String systemPrompt =
            'Tu es un évaluateur technique senior pour Talan Tunisie. ' +
            'Tu dois évaluer la réponse d\'un candidat à un exercice technique.\n\n' +
            'Évalue la réponse sur 100 points selon ces critères :\n' +
            criteriaList + '\n' +
            'Réponds UNIQUEMENT en JSON valide :\n' +
            '{\n' +
            '  "score": 75,\n' +
            '  "feedback": "Votre solution est correcte mais pourrait être optimisée...",\n' +
            '  "criteriaResults": [\n' +
            '    {"criterion": "Logique correcte", "score": 20, "max": 25, "comment": "..."},\n' +
            '    {"criterion": "Complexité", "score": 15, "max": 25, "comment": "..."}\n' +
            '  ]\n' +
            '}\n\n' +
            'Le score global doit refléter la qualité technique réelle.\n' +
            'Si la réponse est vide ou hors sujet, score = 0.\n' +
            'Le feedback doit être constructif, en français, 2-3 phrases.';

        String userPrompt =
            'EXERCICE (' + problemType + ') :\n' + problem + '\n\n' +
            'SOLUTION ATTENDUE :\n' + expectedSolution + '\n\n' +
            'RÉPONSE DU CANDIDAT :\n' + (String.isNotBlank(candidateAnswer) ? candidateAnswer : '(aucune réponse)') + '\n\n' +
            'Évalue cette réponse.';

        Map<String, Object> body = new Map<String, Object>{
            'model'       => GROQ_MODEL,
            'temperature' => 0.3,
            'max_tokens'  => 1500,
            'messages'    => new List<Map<String, String>>{
                new Map<String, String>{ 'role' => 'system', 'content' => systemPrompt },
                new Map<String, String>{ 'role' => 'user',   'content' => userPrompt   }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(GROQ_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setTimeout(30000);
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            // Fallback: return a default evaluation
            Map<String, Object> fallback = new Map<String, Object>();
            fallback.put('score', 0);
            fallback.put('feedback', 'Évaluation IA temporairement indisponible.');
            fallback.put('criteriaResults', new List<Object>());
            return fallback;
        }

        Map<String, Object> resp    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object>        choices = (List<Object>) resp.get('choices');
        Map<String, Object> msg     = (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
        String content = ((String) msg.get('content')).trim();

        // Clean markdown
        if (content.startsWith('```json')) content = content.substring(7);
        else if (content.startsWith('```')) content = content.substring(3);
        if (content.endsWith('```')) content = content.substring(0, content.length() - 3);
        content = content.trim();

        Integer s = content.indexOf('{');
        Integer e = content.lastIndexOf('}');
        if (s != -1 && e > s) content = content.substring(s, e + 1);

        return (Map<String, Object>) JSON.deserializeUntyped(content);
    }

    // ═══════════════════════════════════════
    //  SUBMIT RESULTS — calcul score composite
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> submitInterviewResults(
        Id oppId, Decimal technicalScore, Integer answeredCount,
        Integer totalProblems, Integer timeSpentSeconds
    ) {
        Opportunity opp = [
            SELECT Id, StageName, Score_Matching__c
            FROM Opportunity WHERE Id = :oppId LIMIT 1
        ];

        // Score composite : 50% technique + 25% gaming + 25% matching CV
        Decimal gamingScore = 0;
        Decimal matchScore  = opp.Score_Matching__c != null ? opp.Score_Matching__c : 0;
        Decimal composite   = (technicalScore * 0.50) + (gamingScore * 0.25) + (matchScore * 0.25);
        composite = composite.setScale(1, RoundingMode.HALF_UP);

        // Upsert Technical_Interview__c record
        List<Technical_Interview__c> tiList = [
            SELECT Id FROM Technical_Interview__c WHERE Opportunity__c = :oppId LIMIT 1
        ];
        Technical_Interview__c ti = tiList.isEmpty()
            ? new Technical_Interview__c(Opportunity__c = oppId)
            : tiList[0];
        ti.Score__c    = technicalScore;
        ti.Status__c   = 'Completed';
        ti.Composite_Score__c = composite;
        upsert ti;

        Map<String, Object> result = new Map<String, Object>();
        result.put('technicalScore', technicalScore);
        result.put('compositeScore', composite);
        result.put('gamingScore', gamingScore);
        result.put('matchingScore', matchScore);
        result.put('answeredCount', answeredCount);
        result.put('totalProblems', totalProblems);
        return result;
    }

    // ═══════════════════════════════════════
    //  MANAGER VALIDATION — valide ou ajuste le score
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> validateScore(Id oppId, Decimal managerScore, String decision) {
        Opportunity opp = [
            SELECT Id, StageName
            FROM Opportunity WHERE Id = :oppId LIMIT 1
        ];

        opp.Manager_Validated_Score__c = managerScore;

        String recommendation;
        Boolean passed;

        if (decision == 'accept') {
            opp.StageName = 'Architecture';
            passed = true;
            recommendation = 'Candidat validé pour l\'étape Architecture.';
        } else {
            opp.StageName = 'Closed Lost';
            passed = false;
            recommendation = 'Candidat non retenu après l\'entretien technique.';
        }

        update opp;

        // Send notification email to candidate
        sendValidationEmail(oppId, passed, managerScore, opp.StageName);

        Map<String, Object> result = new Map<String, Object>();
        result.put('passed', passed);
        result.put('newStage', opp.StageName);
        result.put('recommendation', recommendation);
        result.put('validatedScore', managerScore);
        return result;
    }

    // ═══════════════════════════════════════
    //  GET INTERVIEW DETAILS — pour le dashboard manager
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> getInterviewDetails(Id oppId) {
        Opportunity opp = [
            SELECT Id, Name, StageName, Score_Matching__c, Manager_Validated_Score__c
            FROM Opportunity WHERE Id = :oppId LIMIT 1
        ];

        // Get Technical_Interview__c data
        List<Technical_Interview__c> tiList = [
            SELECT Id, Score__c, Composite_Score__c, Status__c
            FROM Technical_Interview__c WHERE Opportunity__c = :oppId LIMIT 1
        ];
        Technical_Interview__c ti = tiList.isEmpty() ? new Technical_Interview__c() : tiList[0];

        // Candidate name
        String candidateName = '';
        List<Lead> leads = [
            SELECT FirstName, LastName FROM Lead
            WHERE ConvertedOpportunityId = :oppId AND IsConverted = true LIMIT 1
        ];
        if (!leads.isEmpty()) {
            candidateName = ((leads[0].FirstName != null ? leads[0].FirstName : '') + ' ' +
                            (leads[0].LastName != null ? leads[0].LastName : '')).trim();
        }

        // Get per-question results
        Id jobPostingId = null;
        if (!leads.isEmpty()) {
            Lead l = [SELECT Description FROM Lead WHERE Id = :leads[0].Id LIMIT 1];
            if (l.Description != null) {
                for (String line : l.Description.split('\n')) {
                    if (line.startsWith('JOB_ID:')) {
                        try { jobPostingId = (Id) line.replace('JOB_ID:', '').trim(); }
                        catch (Exception e) { /* ignore */ }
                        break;
                    }
                }
            }
        }

        List<Map<String, Object>> problemResults = new List<Map<String, Object>>();
        if (jobPostingId != null) {
            List<Technical_Question__c> questions = [
                SELECT Problem_Text__c, Problem_Type__c, Difficulty__c,
                       Candidate_Answer__c, AI_Score__c, AI_Feedback__c
                FROM Technical_Question__c
                WHERE Job_Posting__c = :jobPostingId AND AI_Score__c != null
                ORDER BY CreatedDate ASC
            ];
            for (Technical_Question__c q : questions) {
                Map<String, Object> pr = new Map<String, Object>();
                pr.put('problem', q.Problem_Text__c);
                pr.put('type', q.Problem_Type__c);
                pr.put('difficulty', q.Difficulty__c);
                pr.put('candidateAnswer', q.Candidate_Answer__c);
                pr.put('aiScore', q.AI_Score__c);
                pr.put('aiFeedback', q.AI_Feedback__c);
                problemResults.add(pr);
            }
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('candidateName', candidateName);
        result.put('technicalScore', ti.Score__c);
        result.put('compositeScore', ti.Composite_Score__c);
        result.put('gamingScore', null);
        result.put('matchingScore', opp.Score_Matching__c);
        result.put('status', ti.Status__c);
        result.put('managerScore', opp.Manager_Validated_Score__c);
        result.put('problemResults', problemResults);
        return result;
    }

    // ═══════════════════════════════════════
    //  EMAIL NOTIFICATION
    // ═══════════════════════════════════════
    private static void sendValidationEmail(Id oppId, Boolean passed, Decimal score, String newStage) {
        String candidatEmail = '';
        String prenom = '';

        List<Lead> leads = [
            SELECT FirstName, Email FROM Lead
            WHERE ConvertedOpportunityId = :oppId AND IsConverted = true LIMIT 1
        ];
        if (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) {
            candidatEmail = leads[0].Email;
            prenom = leads[0].FirstName != null ? leads[0].FirstName : '';
        }
        if (String.isBlank(candidatEmail)) {
            List<OpportunityContactRole> ocrs = [
                SELECT Contact.FirstName, Contact.Email
                FROM OpportunityContactRole
                WHERE OpportunityId = :oppId AND Contact.Email != null LIMIT 1
            ];
            if (!ocrs.isEmpty()) {
                candidatEmail = ocrs[0].Contact.Email;
                prenom = ocrs[0].Contact.FirstName != null ? ocrs[0].Contact.FirstName : '';
            }
        }

        if (String.isBlank(candidatEmail)) return;

        String statusColor = passed ? '#22c55e' : '#ef4444';
        String statusText = passed
            ? 'Félicitations ' + prenom + ' ! Votre entretien technique a été validé. Vous êtes avancé(e) à l\'étape ' + newStage + '.'
            : 'Après l\'évaluation de votre entretien technique, nous ne sommes pas en mesure de retenir votre candidature pour la suite du processus.';

        String html = '<div style="font-family:Inter,Arial,sans-serif;max-width:600px;margin:0 auto;">'
            + '<div style="background:linear-gradient(135deg,#3b82f6,#1d4ed8);padding:30px 40px;border-radius:16px 16px 0 0;">'
            + '<h1 style="color:#fff;margin:0;font-size:22px;">Résultat Entretien Technique</h1>'
            + '<p style="color:rgba(255,255,255,0.8);margin:8px 0 0;font-size:13px;">HR Talent Portal — Talan Tunisie</p>'
            + '</div>'
            + '<div style="background:#fff;padding:30px 40px;border:1px solid #e5e7eb;border-top:none;">'
            + '<div style="text-align:center;margin:20px 0;padding:20px;background:' + (passed ? '#f0fdf4' : '#fef2f2') + ';border:2px solid ' + statusColor + ';border-radius:12px;">'
            + '<div style="font-size:36px;font-weight:bold;color:' + statusColor + ';">' + score.intValue() + '/100</div>'
            + '<div style="font-size:14px;color:#475569;margin-top:8px;">Score composite entretien technique</div>'
            + '</div>'
            + '<p style="font-size:14px;color:#334155;line-height:1.7;">' + statusText + '</p>'
            + '<div style="text-align:center;margin:24px 0;">'
            + '<a href="' + SITE_URL + '/s/loginp" style="display:inline-block;padding:12px 32px;background:linear-gradient(135deg,#3b82f6,#1d4ed8);color:#fff;text-decoration:none;border-radius:8px;font-weight:bold;">Accéder au portail</a>'
            + '</div>'
            + '</div>'
            + '<div style="text-align:center;padding:16px;font-size:11px;color:#94a3b8;">TALAN Tunisie — HR Talent Portal</div>'
            + '</div>';

        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ candidatEmail });
            mail.setSubject('Talan Tunisie — Résultat de votre entretien technique');
            mail.setHtmlBody(html);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Technical interview validation email error: ' + e.getMessage());
        }
    }
}
