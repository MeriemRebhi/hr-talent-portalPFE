/**
 * ArchitectureAudioProcessor
 * ──────────────────────────
 * Queueable (AllowsCallouts) — Traite l'audio d'un entretien architecture :
 *
 *   Étape 1 : Récupère le fichier audio depuis ContentVersion
 *   Étape 2 : Envoie à Groq Whisper API → transcription texte
 *   Étape 3 : Envoie la transcription à Groq LLaMA → score + feedback
 *   Étape 4 : Met à jour Architecture_Interview__c avec les résultats
 *
 * Limites :
 *   - Groq Whisper accepte max 25 MB par requête
 *   - Un Queueable ne peut faire qu'un seul callout chain
 *     → on chaîne Whisper puis LLaMA dans le même execute()
 */
public without sharing class ArchitectureAudioProcessor implements Queueable, Database.AllowsCallouts {

    private static final String GROQ_WHISPER_ENDPOINT = 'https://api.groq.com/openai/v1/audio/transcriptions';
    private static final String GROQ_CHAT_ENDPOINT    = 'https://api.groq.com/openai/v1/chat/completions';
    private static final String WHISPER_MODEL         = 'whisper-large-v3-turbo';
    private static final String LLAMA_MODEL           = 'llama-3.3-70b-versatile';

    private Id oppId;
    private Id interviewId;
    private Id contentVersionId;

    public ArchitectureAudioProcessor(Id oppId, Id interviewId, Id contentVersionId) {
        this.oppId = oppId;
        this.interviewId = interviewId;
        this.contentVersionId = contentVersionId;
    }

    public void execute(QueueableContext context) {
        try {
            // Get API key
            List<AI_Configuration__c> configs = [SELECT Groq_API_Key__c FROM AI_Configuration__c LIMIT 1];
            if (configs.isEmpty() || String.isBlank(configs[0].Groq_API_Key__c)) {
                updateStatus('Error', 'Clé API Groq non configurée.', null, null);
                return;
            }
            String apiKey = configs[0].Groq_API_Key__c;

            // Get audio file
            ContentVersion cv = [
                SELECT VersionData, Title, FileExtension, ContentSize
                FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1
            ];

            if (cv.ContentSize > 25 * 1024 * 1024) {
                updateStatus('Error', 'Fichier audio trop volumineux (> 25 MB). Veuillez réduire la durée.', null, null);
                return;
            }

            // Get job title for context
            String jobTitle = '';
            Opportunity opp = [SELECT Name FROM Opportunity WHERE Id = :oppId LIMIT 1];
            jobTitle = opp.Name;

            // ─── STEP 1 : Whisper Transcription ───
            String transcription = callWhisper(apiKey, cv.VersionData, cv.Title);

            if (String.isBlank(transcription)) {
                updateStatus('Error', 'La transcription Whisper n\'a retourné aucun texte.', null, null);
                return;
            }

            // ─── STEP 2 : LLaMA Analysis ───
            Map<String, Object> analysis = callLlamaAnalysis(apiKey, transcription, jobTitle);

            Decimal score = (Decimal) analysis.get('score');
            String feedback = (String) analysis.get('feedback');

            // ─── STEP 3 : Update record ───
            updateStatus('Completed', feedback, score, transcription);

            // ─── STEP 4 : Notify manager ───
            notifyManager(score);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ArchitectureAudioProcessor error: ' + e.getMessage() + '\n' + e.getStackTraceString());
            updateStatus('Error', 'Erreur de traitement : ' + e.getMessage().left(500), null, null);
        }
    }

    // ═══════════════════════════════════════
    //  WHISPER API — Speech-to-Text
    // ═══════════════════════════════════════
    private String callWhisper(String apiKey, Blob audioData, String fileName) {
        // Build multipart/form-data request
        String boundary = '----FormBoundary' + String.valueOf(DateTime.now().getTime());

        String header =
            '--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="file"; filename="' + fileName + '"\r\n' +
            'Content-Type: audio/webm\r\n\r\n';

        String modelPart =
            '\r\n--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="model"\r\n\r\n' +
            WHISPER_MODEL;

        String langPart =
            '\r\n--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="language"\r\n\r\n' +
            'fr';

        String footer = '\r\n--' + boundary + '--';

        // Combine text and binary parts
        String headerEncoded = EncodingUtil.base64Encode(Blob.valueOf(header));
        String audioEncoded  = EncodingUtil.base64Encode(audioData);
        String tailEncoded   = EncodingUtil.base64Encode(Blob.valueOf(modelPart + langPart + footer));

        // Merge base64 strings and decode as single blob
        Blob requestBody = EncodingUtil.base64Decode(headerEncoded + audioEncoded + tailEncoded);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(GROQ_WHISPER_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setTimeout(120000);
        req.setBodyAsBlob(requestBody);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new ArchAudioException('Whisper API erreur (' + res.getStatusCode() + '): ' + res.getBody().left(500));
        }

        Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) resp.get('text');
    }

    // ═══════════════════════════════════════
    //  LLAMA API — Analyse de la transcription
    // ═══════════════════════════════════════
    private Map<String, Object> callLlamaAnalysis(String apiKey, String transcription, String jobTitle) {
        String systemPrompt =
            'Tu es un évaluateur senior en architecture logicielle pour Talan Tunisie (ESN IT/consulting).\n' +
            'Tu reçois la transcription d\'un entretien d\'architecture entre un recruteur et un candidat.\n\n' +
            'Évalue le candidat sur 100 points selon ces critères :\n' +
            '1. Maîtrise des concepts d\'architecture (microservices, monolithe, event-driven, etc.) — /25\n' +
            '2. Capacité de raisonnement et argumentation technique — /25\n' +
            '3. Connaissance des design patterns et bonnes pratiques — /25\n' +
            '4. Communication et clarté des explications — /25\n\n' +
            'Réponds UNIQUEMENT en JSON valide :\n' +
            '{\n' +
            '  "score": 72,\n' +
            '  "feedback": "Analyse globale en français, 3-5 phrases constructives...",\n' +
            '  "criteriaResults": [\n' +
            '    {"criterion": "Architecture", "score": 20, "max": 25, "comment": "..."},\n' +
            '    {"criterion": "Raisonnement", "score": 18, "max": 25, "comment": "..."},\n' +
            '    {"criterion": "Design Patterns", "score": 17, "max": 25, "comment": "..."},\n' +
            '    {"criterion": "Communication", "score": 17, "max": 25, "comment": "..."}\n' +
            '  ],\n' +
            '  "keyTopics": ["microservices", "CQRS", "..."],\n' +
            '  "recommendation": "Recommandé pour RH Fit" ou "À revoir" ou "Non recommandé"\n' +
            '}\n\n' +
            'Si la transcription est vide ou incompréhensible, score = 0.\n' +
            'Le feedback doit être en français, constructif et professionnel.';

        String userPrompt =
            'Poste : ' + jobTitle + '\n\n' +
            'TRANSCRIPTION DE L\'ENTRETIEN ARCHITECTURE :\n\n' +
            transcription.left(28000) + '\n\n' +
            'Évalue ce candidat.';

        Map<String, Object> body = new Map<String, Object>{
            'model'       => LLAMA_MODEL,
            'temperature' => 0.3,
            'max_tokens'  => 2000,
            'messages'    => new List<Map<String, String>>{
                new Map<String, String>{ 'role' => 'system', 'content' => systemPrompt },
                new Map<String, String>{ 'role' => 'user',   'content' => userPrompt   }
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(GROQ_CHAT_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setTimeout(60000);
        req.setBody(JSON.serialize(body));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new ArchAudioException('LLaMA API erreur (' + res.getStatusCode() + '): ' + res.getBody().left(500));
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

        Integer s = content.indexOf('{');
        Integer e = content.lastIndexOf('}');
        if (s != -1 && e > s) content = content.substring(s, e + 1);

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(content);

        // Build full feedback text including criteria details
        String fullFeedback = (String) parsed.get('feedback') + '\n\n';
        if (parsed.containsKey('criteriaResults')) {
            fullFeedback += '── Détail par critère ──\n';
            List<Object> criteria = (List<Object>) parsed.get('criteriaResults');
            for (Object cr : criteria) {
                Map<String, Object> c = (Map<String, Object>) cr;
                fullFeedback += '• ' + (String) c.get('criterion') + ' : ' +
                    c.get('score') + '/' + c.get('max') + ' — ' +
                    (String) c.get('comment') + '\n';
            }
        }
        if (parsed.containsKey('recommendation')) {
            fullFeedback += '\n── Recommandation IA ──\n' + (String) parsed.get('recommendation');
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('score', parsed.get('score'));
        result.put('feedback', fullFeedback);
        return result;
    }

    // ═══════════════════════════════════════
    //  UPDATE STATUS — helper
    // ═══════════════════════════════════════
    private void updateStatus(String status, String feedback, Decimal score, String transcription) {
        Architecture_Interview__c ai = [
            SELECT Id FROM Architecture_Interview__c WHERE Id = :interviewId LIMIT 1
        ];
        ai.Status__c = status;
        if (feedback != null)      ai.AI_Feedback__c    = feedback.left(32768);
        if (score != null)         ai.Score__c          = score;
        if (transcription != null) ai.Transcription__c  = transcription.left(131072);
        update ai;
    }

    // ═══════════════════════════════════════
    //  NOTIFY MANAGER — email résultats
    // ═══════════════════════════════════════
    private void notifyManager(Decimal score) {
        String candidateName = 'Candidat';
        List<Lead> leads = [
            SELECT FirstName, LastName, Description FROM Lead
            WHERE ConvertedOpportunityId = :oppId AND IsConverted = true LIMIT 1
        ];
        if (!leads.isEmpty()) {
            candidateName = ((leads[0].FirstName != null ? leads[0].FirstName : '') + ' ' +
                            (leads[0].LastName != null ? leads[0].LastName : '')).trim();
        }

        // Find manager via JOB_ID
        String managerEmail = '';
        if (!leads.isEmpty() && leads[0].Description != null) {
            for (String line : leads[0].Description.split('\n')) {
                if (line.startsWith('JOB_ID:')) {
                    try {
                        Id jobPostingId = (Id) line.replace('JOB_ID:', '').trim();
                        List<Opportunity> jobs = [SELECT Owner.Email FROM Opportunity WHERE Id = :jobPostingId LIMIT 1];
                        if (!jobs.isEmpty()) managerEmail = jobs[0].Owner.Email;
                    } catch (Exception e) { /* ignore */ }
                    break;
                }
            }
        }

        if (String.isBlank(managerEmail)) return;

        String scoreColor = score >= 70 ? '#22c55e' : (score >= 50 ? '#f59e0b' : '#ef4444');

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ managerEmail });
        mail.setSubject('🏗️ Résultats Entretien Architecture — ' + candidateName);
        mail.setHtmlBody(
            '<div style="font-family:Inter,Arial,sans-serif;max-width:600px;margin:0 auto;">'
            + '<div style="background:linear-gradient(135deg,#7c3aed,#a78bfa);padding:30px 40px;border-radius:16px 16px 0 0;">'
            + '<h1 style="color:#fff;margin:0;font-size:22px;">🏗️ Entretien Architecture — Résultats IA</h1>'
            + '<p style="color:rgba(255,255,255,0.8);margin:8px 0 0;font-size:13px;">HR Talent Portal · Talan Tunisie</p>'
            + '</div>'
            + '<div style="background:#fff;padding:30px 40px;border:1px solid #e5e7eb;border-top:none;">'
            + '<p style="font-size:16px;color:#334155;">Candidat : <strong>' + candidateName + '</strong></p>'
            + '<div style="text-align:center;margin:20px 0;padding:20px;background:#f8fafc;border:2px solid ' + scoreColor + ';border-radius:12px;">'
            + '<div style="font-size:36px;font-weight:bold;color:' + scoreColor + ';">' + score.intValue() + '/100</div>'
            + '<div style="font-size:14px;color:#475569;margin-top:8px;">Score Architecture IA</div>'
            + '</div>'
            + '<p style="font-size:14px;color:#475569;line-height:1.7;">La transcription et l\'analyse détaillée sont disponibles dans le dashboard manager.</p>'
            + '<div style="text-align:center;margin:24px 0;">'
            + '<a href="https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2" '
            + 'style="display:inline-block;padding:12px 32px;background:linear-gradient(135deg,#7c3aed,#5b21b6);color:#fff;text-decoration:none;border-radius:8px;font-weight:bold;">'
            + 'Consulter les résultats</a>'
            + '</div>'
            + '</div>'
            + '<div style="text-align:center;padding:16px;font-size:11px;color:#94a3b8;">TALAN Tunisie — HR Talent Portal</div>'
            + '</div>'
        );
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Architecture manager notification error: ' + e.getMessage());
        }
    }

    public class ArchAudioException extends Exception {}
}
