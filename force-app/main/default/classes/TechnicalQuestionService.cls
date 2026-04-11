/**
 * TechnicalQuestionService
 * ────────────────────────
 * Génère dynamiquement 5 exercices d'entretien technique via Groq API (LLaMA 3.3 70B)
 * adaptés au poste spécifique. Les exercices sont stockés dans Technical_Question__c.
 *
 * Types d'exercices :
 *   - code        : Implémenter un algorithme / fonction
 *   - architecture : Question de conception / design pattern
 *   - debug       : Trouver et corriger un bug dans du code
 *
 * Usage :
 *   - Appelé depuis InternalDashboardController.generateTechnicalQuestions(jobPostingId)
 *   - Exécuté en Queueable (AllowsCallouts) pour ne pas bloquer le UI
 *   - La solution attendue reste côté serveur pour l'évaluation IA
 */
public without sharing class TechnicalQuestionService implements Queueable, Database.AllowsCallouts {

    private static final String GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
    private static final String GROQ_MODEL    = 'llama-3.3-70b-versatile';

    private Id jobPostingId;

    public TechnicalQuestionService(Id jobPostingId) {
        this.jobPostingId = jobPostingId;
    }

    // ═══════════════════════════════════════
    //  ENTRY POINT — Enqueue from controller
    // ═══════════════════════════════════════
    @AuraEnabled
    public static void generateQuestions(Id jobPostingId) {
        if (jobPostingId == null) {
            throw new AuraHandledException('ID de l\'offre manquant.');
        }

        // Delete old questions before regenerating
        List<Technical_Question__c> existing = [
            SELECT Id FROM Technical_Question__c
            WHERE Job_Posting__c = :jobPostingId
        ];
        if (!existing.isEmpty()) {
            delete existing;
        }

        System.enqueueJob(new TechnicalQuestionService(jobPostingId));
    }

    // ═══════════════════════════════════════
    //  QUEUEABLE EXECUTE — call Groq API
    // ═══════════════════════════════════════
    public void execute(QueueableContext context) {
        try {
            Opportunity job = [
                SELECT Id, Name, Description_Poste__c, Departement__c
                FROM Opportunity
                WHERE Id = :jobPostingId
                LIMIT 1
            ];

            String questionsJson = callGroqForProblems(job.Name, job.Description_Poste__c, job.Departement__c);
            parseAndInsertProblems(questionsJson, jobPostingId);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'TechnicalQuestionService error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    // ═══════════════════════════════════════
    //  GROQ API CALL
    // ═══════════════════════════════════════
    private String callGroqForProblems(String jobTitle, String jobDesc, String dept) {
        List<AI_Configuration__c> configs = [SELECT Groq_API_Key__c FROM AI_Configuration__c LIMIT 1];
        if (configs.isEmpty() || String.isBlank(configs[0].Groq_API_Key__c)) {
            throw new TechnicalQuestionException('Clé API Groq non configurée dans AI_Configuration__c');
        }
        String apiKey = configs[0].Groq_API_Key__c;

        String systemPrompt =
            'Tu es un expert senior en évaluation technique pour Talan Tunisie (ESN IT/consulting). ' +
            'Tu dois générer exactement 5 exercices d\'entretien technique pour évaluer un candidat en temps réel.\n\n' +
            'RÈGLES STRICTES :\n' +
            '- 3 types d\'exercices :\n' +
            '  • "code" (2 exercices) : Le candidat doit écrire du code complet (fonction, algorithme)\n' +
            '  • "architecture" (2 exercices) : Question de conception, design pattern, choix technologique\n' +
            '  • "debug" (1 exercice) : Code buggé fourni, le candidat doit identifier et corriger le(s) bug(s)\n\n' +
            '- Niveaux de difficulté : 1 easy, 3 medium, 1 hard\n' +
            '- Temps par exercice : easy=300s (5min), medium=600s (10min), hard=900s (15min)\n' +
            '- Les exercices doivent être en FRANÇAIS\n' +
            '- Chaque exercice doit être adapté au poste et au département\n' +
            '- Pour les exercices "debug", inclure le code buggé dans le champ "problem"\n\n' +
            'Réponds UNIQUEMENT en JSON valide, un tableau de 5 objets :\n' +
            '[{\n' +
            '  "type": "code",\n' +
            '  "diff": "medium",\n' +
            '  "time": 600,\n' +
            '  "problem": "Écrivez une fonction Java qui...",\n' +
            '  "expected": "public int solution(int[] arr) { ... }",\n' +
            '  "criteria": "Logique correcte|Complexité O(n)|Gestion des cas limites|Code propre"\n' +
            '}]\n\n' +
            'Pour "criteria" : 4 critères séparés par | sur lesquels l\'IA évaluera la réponse.\n' +
            'Pour "expected" : La solution de référence complète (le candidat ne la verra jamais).';

        String jobInfo = 'Titre du poste : ' + jobTitle;
        if (!String.isBlank(dept))    jobInfo += '\nDépartement : ' + dept;
        if (!String.isBlank(jobDesc)) jobInfo += '\nDescription : ' + jobDesc;

        String userPrompt =
            'Génère 5 exercices techniques adaptés à ce poste chez Talan Tunisie :\n\n' +
            jobInfo + '\n\n' +
            'Les exercices doivent évaluer les compétences réelles requises pour ce poste.\n' +
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
            throw new TechnicalQuestionException('Groq API erreur (' + res.getStatusCode() + '): ' + res.getBody().left(300));
        }

        Map<String, Object> resp    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object>        choices = (List<Object>) resp.get('choices');
        Map<String, Object> msg     = (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
        String content = ((String) msg.get('content')).trim();

        // Clean markdown wrapper
        if (content.startsWith('```json')) content = content.substring(7);
        else if (content.startsWith('```')) content = content.substring(3);
        if (content.endsWith('```')) content = content.substring(0, content.length() - 3);
        content = content.trim();

        Integer s = content.indexOf('[');
        Integer e = content.lastIndexOf(']');
        if (s != -1 && e > s) content = content.substring(s, e + 1);

        return content;
    }

    // ═══════════════════════════════════════
    //  PARSE & INSERT
    // ═══════════════════════════════════════
    private void parseAndInsertProblems(String questionsJson, Id jobId) {
        List<Object> rawQuestions = (List<Object>) JSON.deserializeUntyped(questionsJson);
        List<Technical_Question__c> toInsert = new List<Technical_Question__c>();

        for (Object rawQ : rawQuestions) {
            Map<String, Object> qMap = (Map<String, Object>) rawQ;

            Technical_Question__c tq = new Technical_Question__c();
            tq.Job_Posting__c         = jobId;
            tq.Problem_Text__c        = (String) qMap.get('problem');
            tq.Problem_Type__c        = (String) qMap.get('type');
            tq.Difficulty__c          = (String) qMap.get('diff');
            tq.Expected_Solution__c   = (String) qMap.get('expected');
            tq.Evaluation_Criteria__c = (String) qMap.get('criteria');
            tq.Time_Limit__c          = qMap.get('time') != null
                ? ((Decimal) qMap.get('time')).intValue()
                : 600;

            toInsert.add(tq);
        }

        if (!toInsert.isEmpty()) {
            insert toInsert;
            System.debug('TechnicalQuestionService: ' + toInsert.size() + ' exercices insérés pour Job ' + jobId);
        }
    }

    // ═══════════════════════════════════════
    //  STATUS POLLING
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> getGenerationStatus(Id jobPostingId) {
        Integer count = [SELECT COUNT() FROM Technical_Question__c WHERE Job_Posting__c = :jobPostingId];
        Map<String, Object> result = new Map<String, Object>();
        result.put('count', count);
        result.put('ready', count >= 4);
        return result;
    }

    public class TechnicalQuestionException extends Exception {}
}
