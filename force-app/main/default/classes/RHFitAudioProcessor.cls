public without sharing class RHFitAudioProcessor implements Queueable, Database.AllowsCallouts {

    private static final String GROQ_WHISPER_ENDPOINT = 'https://api.groq.com/openai/v1/audio/transcriptions';
    private static final String GROQ_CHAT_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
    private static final String WHISPER_MODEL = 'whisper-large-v3-turbo';
    private static final String LLAMA_MODEL = 'llama-3.3-70b-versatile';

    private Id oppId;
    private Id interviewId;
    private Id contentVersionId;

    public RHFitAudioProcessor(Id oppId, Id interviewId, Id contentVersionId) {
        this.oppId = oppId;
        this.interviewId = interviewId;
        this.contentVersionId = contentVersionId;
    }

    public void execute(QueueableContext context) {
        try {
            List<AI_Configuration__c> configs = [SELECT Groq_API_Key__c FROM AI_Configuration__c LIMIT 1];
            if (configs.isEmpty() || String.isBlank(configs[0].Groq_API_Key__c)) {
                updateStatus('Error', 'Cle API Groq non configuree.', null, null, null, null);
                return;
            }
            String apiKey = configs[0].Groq_API_Key__c;

            ContentVersion cv = [
                SELECT VersionData, Title, FileExtension, ContentSize
                FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];
            if (cv.ContentSize == null || cv.ContentSize <= 0) {
                updateStatus('Error', 'Fichier audio vide. Merci de reuploader un enregistrement valide.', null, null, null, null);
                return;
            }
            if (cv.ContentSize > 25 * 1024 * 1024) {
                updateStatus('Error', 'Fichier audio trop volumineux (> 25 MB).', null, null, null, null);
                return;
            }

            Opportunity opp = [SELECT Name FROM Opportunity WHERE Id = :oppId LIMIT 1];
            String transcription = callWhisper(
                apiKey,
                cv.VersionData,
                buildAudioFileName(cv.Title, cv.FileExtension)
            );
            if (String.isBlank(transcription)) {
                updateStatus('Error', 'La transcription n a retourne aucun texte.', null, null, null, null);
                return;
            }

            Map<String, Object> analysis = callLlamaAnalysis(apiKey, transcription, opp.Name);
            Decimal aiScore = parseDecimal(analysis.get('score'));
            Decimal sentimentScore = parseDecimal(analysis.get('sentimentScore'));
            String sentimentLabel = (String) analysis.get('sentimentLabel');
            String feedback = (String) analysis.get('feedback');

            updateStatus('Completed', feedback, aiScore, transcription, sentimentScore, sentimentLabel);
            notifyManager(aiScore, sentimentLabel);
        } catch (Exception e) {
            updateStatus('Error', 'Erreur de traitement RH Fit : ' + e.getMessage().left(400), null, null, null, null);
        }
    }

    private String callWhisper(String apiKey, Blob audioData, String fileName) {
        String boundary = '----FormBoundary' + String.valueOf(DateTime.now().getTime());
        String safeFileName = sanitizeFileName(fileName);
        String contentType = resolveAudioMimeType(safeFileName);

        String header =
            '--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="file"; filename="' + safeFileName + '"\r\n' +
            'Content-Type: ' + contentType + '\r\n\r\n';

        String modelPart =
            '\r\n--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="model"\r\n\r\n' +
            WHISPER_MODEL;

        String langPart =
            '\r\n--' + boundary + '\r\n' +
            'Content-Disposition: form-data; name="language"\r\n\r\nfr';

        String footer = '\r\n--' + boundary + '--';

        // Assemble binary multipart body via hex concatenation to avoid base64 padding corruption.
        Blob requestBody = EncodingUtil.convertFromHex(
            EncodingUtil.convertToHex(Blob.valueOf(header)) +
            EncodingUtil.convertToHex(audioData) +
            EncodingUtil.convertToHex(Blob.valueOf(modelPart + langPart + footer))
        );

        HttpRequest req = new HttpRequest();
        req.setEndpoint(GROQ_WHISPER_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setTimeout(120000);
        req.setBodyAsBlob(requestBody);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            String whisperErr = res.getBody() != null ? res.getBody().left(300) : '';
            if (whisperErr.toLowerCase().contains('unexpected eof')) {
                throw new RHFitAudioException(
                    'Fichier audio invalide ou tronque. Reessayez avec un fichier .webm/.mp3/.wav et relancez l upload.'
                );
            }
            throw new RHFitAudioException('Whisper error: ' + whisperErr);
        }
        Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) resp.get('text');
    }

    private String buildAudioFileName(String title, String ext) {
        String safeTitle = String.isNotBlank(title) ? title.trim() : 'rhfit-interview';
        String safeExt = String.isNotBlank(ext) ? ext.trim().toLowerCase() : '';
        if (String.isNotBlank(safeExt) && !safeTitle.toLowerCase().endsWith('.' + safeExt)) {
            return safeTitle + '.' + safeExt;
        }
        return safeTitle;
    }

    private String sanitizeFileName(String input) {
        String value = String.isNotBlank(input) ? input : 'rhfit-interview.webm';
        value = value.replace('"', '');
        value = value.replace('\r', '');
        value = value.replace('\n', '');
        value = value.replace('\\', '-');
        return value;
    }

    private String resolveAudioMimeType(String fileName) {
        String name = String.isNotBlank(fileName) ? fileName.toLowerCase() : '';
        if (name.endsWith('.webm')) return 'audio/webm';
        if (name.endsWith('.mp3')) return 'audio/mpeg';
        if (name.endsWith('.wav')) return 'audio/wav';
        if (name.endsWith('.m4a')) return 'audio/mp4';
        if (name.endsWith('.ogg')) return 'audio/ogg';
        if (name.endsWith('.flac')) return 'audio/flac';
        return 'application/octet-stream';
    }

    private Map<String, Object> callLlamaAnalysis(String apiKey, String transcription, String jobTitle) {
        String systemPrompt =
            'Tu es un evaluateur RH senior. Analyse une transcription d entretien RH Fit.\n' +
            'Retourne UNIQUEMENT un JSON valide:\n' +
            '{' +
            '"score":78,' +
            '"sentimentScore":0.35,' +
            '"sentimentLabel":"Positif",' +
            '"feedback":"3 a 6 phrases en francais, professionnel, actionnable."' +
            '}\n' +
            'Regles:\n' +
            '- score entre 0 et 100\n' +
            '- sentimentScore entre -1 et 1\n' +
            '- sentimentLabel dans {Positif, Neutre, Mitige, Negatif}\n';

        String userPrompt =
            'Poste: ' + jobTitle + '\n' +
            'Transcription RH Fit:\n' + transcription.left(28000);

        Map<String, Object> body = new Map<String, Object>{
            'model' => LLAMA_MODEL,
            'temperature' => 0.2,
            'max_tokens' => 1500,
            'messages' => new List<Map<String, String>>{
                new Map<String, String>{ 'role' => 'system', 'content' => systemPrompt },
                new Map<String, String>{ 'role' => 'user', 'content' => userPrompt }
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
            throw new RHFitAudioException('LLaMA error: ' + res.getBody().left(300));
        }

        Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> choices = (List<Object>) resp.get('choices');
        Map<String, Object> msg = (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
        String content = ((String) msg.get('content')).trim();

        if (content.startsWith('```json')) content = content.substring(7);
        else if (content.startsWith('```')) content = content.substring(3);
        if (content.endsWith('```')) content = content.substring(0, content.length() - 3);
        content = content.trim();

        Integer s = content.indexOf('{');
        Integer e = content.lastIndexOf('}');
        if (s != -1 && e > s) content = content.substring(s, e + 1);

        return (Map<String, Object>) JSON.deserializeUntyped(content);
    }

    private Decimal parseDecimal(Object value) {
        if (value == null) return null;
        String raw = String.valueOf(value);
        if (String.isBlank(raw)) return null;
        try {
            return Decimal.valueOf(raw);
        } catch (Exception e) {
            return null;
        }
    }

    private void updateStatus(
        String status,
        String feedback,
        Decimal aiScore,
        String transcription,
        Decimal sentimentScore,
        String sentimentLabel
    ) {
        RH_Fit_Interview__c rec = [
            SELECT Id
            FROM RH_Fit_Interview__c
            WHERE Id = :interviewId
            LIMIT 1
        ];
        rec.Status__c = status;
        if (feedback != null) rec.AI_Feedback__c = feedback.left(32768);
        if (aiScore != null) rec.AI_RHFit_Score__c = aiScore;
        if (transcription != null) rec.Transcription__c = transcription.left(131072);
        if (sentimentScore != null) rec.Sentiment_Score__c = sentimentScore;
        if (sentimentLabel != null) rec.Sentiment_Label__c = sentimentLabel.left(40);
        update rec;
    }

    private void notifyManager(Decimal score, String sentimentLabel) {
        Opportunity appOpp = [
            SELECT Id, Name, OwnerId, Owner.Email
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        String candidateName = String.isNotBlank(appOpp.Name) ? appOpp.Name : 'Candidat';
        Set<String> recipientEmails = new Set<String>();
        if (String.isNotBlank(appOpp.Owner != null ? appOpp.Owner.Email : null)) {
            recipientEmails.add(appOpp.Owner.Email);
        }
        if (String.isNotBlank(UserInfo.getUserEmail())) {
            recipientEmails.add(UserInfo.getUserEmail());
        }

        List<Lead> leads = [
            SELECT FirstName, LastName, Description
            FROM Lead
            WHERE ConvertedOpportunityId = :oppId
            AND IsConverted = true
            LIMIT 1
        ];
        if (!leads.isEmpty()) {
            String fullName = (
                (leads[0].FirstName != null ? leads[0].FirstName : '') + ' ' +
                (leads[0].LastName != null ? leads[0].LastName : '')
            ).trim();
            if (String.isNotBlank(fullName)) {
                candidateName = fullName;
            }

            if (leads[0].Description != null) {
                for (String line : leads[0].Description.split('\n')) {
                    if (line.startsWith('JOB_ID:')) {
                        try {
                            Id jobPostingId = (Id) line.replace('JOB_ID:', '').trim();
                            List<Opportunity> jobs = [
                                SELECT Owner.Email
                                FROM Opportunity
                                WHERE Id = :jobPostingId
                                LIMIT 1
                            ];
                            if (!jobs.isEmpty() && String.isNotBlank(jobs[0].Owner.Email)) {
                                recipientEmails.add(jobs[0].Owner.Email);
                            }
                        } catch (Exception e) {
                        }
                        break;
                    }
                }
            }
        }

        createRecruiterTaskAfterAnalysis(appOpp.OwnerId, appOpp.Id, candidateName, score, sentimentLabel);
        sendRHFitBellNotification(
            appOpp.OwnerId,
            appOpp.Id,
            'Analyse RH Fit terminee',
            'Candidat: ' + candidateName + ' - score IA ' +
            (score != null ? String.valueOf(score) : 'N/A') +
            '/100. Ouvrez le dashboard pour valider la decision.'
        );

        if (recipientEmails.isEmpty()) return;

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>(recipientEmails));
        mail.setSubject('RH Fit termine - ' + candidateName);
        mail.setPlainTextBody(
            'L entretien RH Fit a ete traite.' + '\n' +
            'Score IA: ' + (score != null ? String.valueOf(score) : 'N/A') + '/100' + '\n' +
            'Sentiment: ' + (String.isNotBlank(sentimentLabel) ? sentimentLabel : 'N/A') + '\n' +
            'Action: ouvrir le dashboard recruteur pour valider la decision RH Fit.'
        );
        try {
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug('RH Fit notify error: ' + e.getMessage());
        }
    }

    private void createRecruiterTaskAfterAnalysis(
        Id ownerId,
        Id opportunityId,
        String candidateName,
        Decimal score,
        String sentimentLabel
    ) {
        if (ownerId == null || opportunityId == null) return;
        try {
            Task t = new Task();
            t.OwnerId = ownerId;
            t.WhatId = opportunityId;
            t.Subject = 'Valider RH Fit - ' + (String.isNotBlank(candidateName) ? candidateName : 'Candidat');
            t.Priority = 'High';
            t.Status = 'Not Started';
            t.ActivityDate = Date.today();
            t.Description =
                'Analyse RH Fit terminee.' + '\n' +
                'Candidat: ' + (String.isNotBlank(candidateName) ? candidateName : 'Candidat') + '\n' +
                'Score IA: ' + (score != null ? String.valueOf(score) : 'N/A') + '/100' + '\n' +
                'Sentiment: ' + (String.isNotBlank(sentimentLabel) ? sentimentLabel : 'N/A') + '\n' +
                'Action requise: ouvrir le dashboard recruteur et valider la decision finale RH Fit.';
            insert t;
        } catch (Exception ex) {
            System.debug('RH Fit task creation error: ' + ex.getMessage());
        }
    }

    private void sendRHFitBellNotification(
        Id recipientUserId,
        Id targetId,
        String title,
        String body
    ) {
        if (recipientUserId == null || targetId == null) return;
        try {
            Id notifTypeId = getRHFitNotificationTypeId();
            if (notifTypeId == null) return;

            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setNotificationTypeId(notifTypeId);
            notif.setTitle((String.isNotBlank(title) ? title : 'Notification RH Fit').left(80));
            notif.setBody((String.isNotBlank(body) ? body : 'Mise a jour RH Fit.').left(750));
            notif.setTargetId(targetId);
            notif.send(new Set<String>{ String.valueOf(recipientUserId) });
        } catch (Exception ex) {
            System.debug('RH Fit bell notification error: ' + ex.getMessage());
        }
    }

    private Id getRHFitNotificationTypeId() {
        List<CustomNotificationType> types = [
            SELECT Id, DeveloperName
            FROM CustomNotificationType
            WHERE DeveloperName IN (
                'RH_Fit_Recruteur_Notification',
                'RH_Fit_Recruteur',
                'RHFit_Recruteur_Notification'
            )
            LIMIT 1
        ];
        return types.isEmpty() ? null : types[0].Id;
    }

    public class RHFitAudioException extends Exception {}
}
