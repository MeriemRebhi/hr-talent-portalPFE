/**
 * GamingQuestionService
 * ─────────────────────
 * Génère dynamiquement 25 questions de test gaming via Groq API (LLaMA 3.3 70B)
 * adaptées au poste spécifique. Les questions sont stockées dans Gaming_Question__c.
 *
 * Usage :
 *   - Appelé depuis InternalDashboardController.generateGamingQuestions(jobPostingId)
 *   - Exécuté en Queueable (AllowsCallouts) pour ne pas bloquer le UI
 *   - Les réponses correctes restent côté serveur (jamais envoyées au client LWC)
 */
public without sharing class GamingQuestionService implements Queueable, Database.AllowsCallouts {

    private static final String GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
    private static final String GROQ_MODEL    = 'llama-3.3-70b-versatile';

    private Id jobPostingId;

    public GamingQuestionService(Id jobPostingId) {
        this.jobPostingId = jobPostingId;
    }

    // ═══════════════════════════════════════
    //  ENTRY POINT — Enqueue from controller
    // ═══════════════════════════════════════
    @AuraEnabled
    public static void generateQuestions(Id jobPostingId) {
        // Validate input
        if (jobPostingId == null) {
            throw new AuraHandledException('ID de l\'offre manquant.');
        }

        // Check if questions already exist — delete old ones before regenerating
        List<Gaming_Question__c> existing = [
            SELECT Id FROM Gaming_Question__c
            WHERE Job_Posting__c = :jobPostingId
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }

        // Enqueue the Queueable job
        System.enqueueJob(new GamingQuestionService(jobPostingId));
    }

    // ═══════════════════════════════════════
    //  QUEUEABLE EXECUTE — call Groq API
    // ═══════════════════════════════════════
    public void execute(QueueableContext context) {
        try {
            // 1. Load job posting details
            Opportunity job = [
                SELECT Id, Name, Description_Poste__c, Departement__c
                FROM Opportunity
                WHERE Id = :jobPostingId
                LIMIT 1
            ];

            String jobTitle = job.Name;
            String jobDesc  = job.Description_Poste__c;
            String dept     = job.Departement__c;

            // 2. Call Groq API
            String questionsJson = callGroqForQuestions(jobTitle, jobDesc, dept);

            // 3. Parse JSON and insert records
            parseAndInsertQuestions(questionsJson, jobPostingId);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'GamingQuestionService error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    // ═══════════════════════════════════════
    //  GROQ API CALL
    // ═══════════════════════════════════════
    private String callGroqForQuestions(String jobTitle, String jobDesc, String dept) {
        List<AI_Configuration__c> configs = [SELECT Groq_API_Key__c FROM AI_Configuration__c LIMIT 1];
        if (configs.isEmpty() || String.isBlank(configs[0].Groq_API_Key__c)) {
            throw new GamingQuestionException('Clé API Groq non configurée dans AI_Configuration__c');
        }
        String apiKey = configs[0].Groq_API_Key__c;

        String systemPrompt =
            'Tu es un expert en évaluation technique pour Talan Tunisie (ESN IT/consulting). ' +
            'Tu dois générer exactement 25 questions de quiz technique pour évaluer un candidat.\n\n' +
            'RÈGLES STRICTES :\n' +
            '- 3 types de questions : "mcq" (QCM classique), "puzzle" (logique/calcul), "order" (remettre dans l\'ordre)\n' +
            '- 3 niveaux : "easy" (8 questions), "medium" (10 questions), "hard" (7 questions)\n' +
            '- Répartition types : ~15 mcq, ~5 puzzle, ~5 order\n' +
            '- Chaque MCQ/Puzzle a 4 options (A,B,C,D) avec 1 seule bonne réponse\n' +
            '- Chaque Order a 4 ou 5 étapes dans le BON ordre\n' +
            '- Les questions doivent être en FRANÇAIS\n' +
            '- Temps par question : easy=30, medium=25, hard=20 (order=35 toujours)\n\n' +
            'Réponds UNIQUEMENT en JSON valide, un tableau de 25 objets :\n' +
            '[{"type":"mcq","diff":"easy","time":30,"q":"Question?","opts":["A","B","C","D"],"correct":"A"},\n' +
            ' {"type":"order","diff":"medium","time":35,"q":"Remettez dans l\'ordre :","opts":["Étape1","Étape2","Étape3","Étape4"],"correct":"Étape1|Étape2|Étape3|Étape4"}]\n\n' +
            'Pour MCQ/Puzzle : "correct" = la lettre de la bonne réponse (A, B, C ou D)\n' +
            'Pour Order : "correct" = les étapes dans le bon ordre séparées par |\n' +
            'Pour Order : "opts" contient les étapes dans le BON ordre (le LWC les mélangera)';

        String jobInfo = 'Titre du poste : ' + jobTitle;
        if (!String.isBlank(dept))    jobInfo += '\nDépartement : ' + dept;
        if (!String.isBlank(jobDesc)) jobInfo += '\nDescription : ' + jobDesc;

        String userPrompt =
            'Génère 25 questions techniques adaptées à ce poste chez Talan Tunisie :\n\n' +
            jobInfo + '\n\n' +
            'Les questions doivent évaluer les compétences spécifiques requises pour ce poste.\n' +
            'Réponds UNIQUEMENT avec le tableau JSON, sans texte avant ou après.';

        Map<String, Object> body = new Map<String, Object>{
            'model'       => GROQ_MODEL,
            'temperature' => 0.7,
            'max_tokens'  => 4000,
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
        req.setTimeout(60000);
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new GamingQuestionException('Groq API erreur (' + res.getStatusCode() + '): ' + res.getBody().left(300));
        }

        // Extract content from response
        Map<String, Object> resp    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object>        choices = (List<Object>) resp.get('choices');
        Map<String, Object> msg     = (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
        String content = ((String) msg.get('content')).trim();

        // Clean markdown wrapper if present
        if (content.startsWith('```json')) content = content.substring(7);
        else if (content.startsWith('```')) content = content.substring(3);
        if (content.endsWith('```')) content = content.substring(0, content.length() - 3);
        content = content.trim();

        // Extract JSON array
        Integer s = content.indexOf('[');
        Integer e = content.lastIndexOf(']');
        if (s != -1 && e > s) content = content.substring(s, e + 1);

        return content;
    }

    // ═══════════════════════════════════════
    //  PARSE & INSERT
    // ═══════════════════════════════════════
    private void parseAndInsertQuestions(String questionsJson, Id jobId) {
        List<Object> rawQuestions = (List<Object>) JSON.deserializeUntyped(questionsJson);
        List<Gaming_Question__c> toInsert = new List<Gaming_Question__c>();

        for (Object rawQ : rawQuestions) {
            Map<String, Object> qMap = (Map<String, Object>) rawQ;

            String qType  = (String) qMap.get('type');
            String diff   = (String) qMap.get('diff');
            String qText  = (String) qMap.get('q');
            String correct = (String) qMap.get('correct');
            Integer timeLim = qMap.get('time') != null ? ((Decimal) qMap.get('time')).intValue() : 25;

            List<Object> optsRaw = (List<Object>) qMap.get('opts');

            Gaming_Question__c gq = new Gaming_Question__c();
            gq.Job_Posting__c     = jobId;
            gq.Question_Text__c   = qText;
            gq.Question_Type__c   = qType;
            gq.Difficulty__c      = diff;
            gq.Correct_Answer__c  = correct;
            gq.Time_Limit__c      = timeLim;

            // Assign options A–E
            if (optsRaw != null && optsRaw.size() > 0) gq.Option_A__c = String.valueOf(optsRaw[0]);
            if (optsRaw != null && optsRaw.size() > 1) gq.Option_B__c = String.valueOf(optsRaw[1]);
            if (optsRaw != null && optsRaw.size() > 2) gq.Option_C__c = String.valueOf(optsRaw[2]);
            if (optsRaw != null && optsRaw.size() > 3) gq.Option_D__c = String.valueOf(optsRaw[3]);
            if (optsRaw != null && optsRaw.size() > 4) gq.Option_E__c = String.valueOf(optsRaw[4]);

            toInsert.add(gq);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
            System.debug('GamingQuestionService: ' + toInsert.size() + ' questions insérées pour Job ' + jobId);
        }
    }

    // ═══════════════════════════════════════
    //  CHECK STATUS — used by dashboard polling
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> getGenerationStatus(Id jobPostingId) {
        Integer count = [SELECT COUNT() FROM Gaming_Question__c WHERE Job_Posting__c = :jobPostingId];
        Map<String, Object> result = new Map<String, Object>();
        result.put('count', count);
        result.put('ready', count >= 20);
        return result;
    }

    // ═══════════════════════════════════════
    //  CUSTOM EXCEPTION
    // ═══════════════════════════════════════
    public class GamingQuestionException extends Exception {}
}
