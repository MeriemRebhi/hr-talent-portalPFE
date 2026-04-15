/**
 * ArchitectureInterviewController
 * ────────────────────────────────
 * Controller pour l'entretien Architecture assisté par IA.
 *
 * Flux :
 *   1. Recruteur planifie l'entretien → Jitsi room auto-générée (UUID)
 *   2. Candidat + Recruteur rejoignent la visio Jitsi (iframe intégré)
 *   3. Recruteur clique "Enregistrer" → capture audio via MediaRecorder
 *   4. Fin → audio uploadé en ContentVersion dans Salesforce
 *   5. Groq Whisper → transcription speech-to-text
 *   6. Groq LLaMA  → analyse transcription → score + feedback structuré
 *   7. Manager consulte transcription + score → valide/ajuste → décision
 */
public without sharing class ArchitectureInterviewController {

    private static final String JITSI_BASE_URL = 'https://meet.jit.si/';
    private static final String SITE_URL       = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2';

    // ═══════════════════════════════════════
    //  GENERATE JITSI ROOM — UUID-based
    // ═══════════════════════════════════════
    public static String generateJitsiRoom() {
        String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        return 'talan-arch-' + hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' + hex.substring(12, 16) + '-' + hex.substring(16, 20);
    }

    // ═══════════════════════════════════════
    //  GET INTERVIEW INFO — page candidat / recruteur
    // ═══════════════════════════════════════
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getArchInterviewInfo(Id oppId) {
        Opportunity opp = [
            SELECT Id, Name, StageName, AccountId, Score_Matching__c, Gaming_Test_Score__c
            FROM Opportunity WHERE Id = :oppId LIMIT 1
        ];

        List<Architecture_Interview__c> aiList = [
            SELECT Id, Interview_DateTime__c, Duration__c, Status__c,
                   Score__c, Meet_Link__c, Jitsi_Room__c, Transcription__c,
                   AI_Feedback__c, Audio_ContentVersion_Id__c, Reschedule_Requested__c
            FROM Architecture_Interview__c
            WHERE Opportunity__c = :oppId LIMIT 1
        ];
        Architecture_Interview__c ai = aiList.isEmpty() ? new Architecture_Interview__c() : aiList[0];

        // Candidate name
        String candidateName = 'Candidat';
        List<Lead> leads = [
            SELECT FirstName, LastName FROM Lead
            WHERE ConvertedOpportunityId = :oppId AND IsConverted = true LIMIT 1
        ];
        if (!leads.isEmpty()) {
            candidateName = ((leads[0].FirstName != null ? leads[0].FirstName : '') + ' ' +
                            (leads[0].LastName != null ? leads[0].LastName : '')).trim();
        }

        // Job title
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

        // Technical interview score (from previous stage)
        Decimal techScore = null;
        List<Technical_Interview__c> tiList = [
            SELECT Score__c, Composite_Score__c FROM Technical_Interview__c
            WHERE Opportunity__c = :oppId LIMIT 1
        ];
        if (!tiList.isEmpty()) {
            techScore = tiList[0].Composite_Score__c;
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('oppId', opp.Id);
        result.put('candidateName', candidateName);
        result.put('jobTitle', jobTitle);
        result.put('stageName', opp.StageName);
        result.put('alreadyCompleted', ai.Status__c == 'Completed');
        result.put('existingScore', ai.Score__c);
        result.put('scheduledDate', ai.Interview_DateTime__c);
        result.put('isScheduled', ai.Interview_DateTime__c != null);
        result.put('meetLink', ai.Meet_Link__c);
        result.put('jitsiRoom', ai.Jitsi_Room__c);
        result.put('duration', ai.Duration__c);
        result.put('status', ai.Status__c);
        result.put('transcription', ai.Transcription__c);
        result.put('aiFeedback', ai.AI_Feedback__c);
        result.put('hasAudio', String.isNotBlank(ai.Audio_ContentVersion_Id__c));
        result.put('rescheduleRequested', ai.Reschedule_Requested__c);
        result.put('techCompositeScore', techScore);
        result.put('gamingScore', opp.Gaming_Test_Score__c);
        result.put('matchingScore', opp.Score_Matching__c);
        return result;
    }

    // ═══════════════════════════════════════
    //  UPLOAD AUDIO — from browser MediaRecorder blob
    //  Receives base64-encoded audio data
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> uploadAudio(Id oppId, String audioBase64, String fileName) {
        if (String.isBlank(audioBase64)) {
            throw new AuraHandledException('Aucun fichier audio fourni.');
        }

        // Find or create interview record
        List<Architecture_Interview__c> aiList = [
            SELECT Id FROM Architecture_Interview__c WHERE Opportunity__c = :oppId LIMIT 1
        ];
        if (aiList.isEmpty()) {
            throw new AuraHandledException('Aucun entretien architecture trouvé pour cette candidature.');
        }
        Architecture_Interview__c ai = aiList[0];

        // Create ContentVersion (file in Salesforce)
        ContentVersion cv = new ContentVersion();
        cv.Title = fileName != null ? fileName : 'architecture-interview-' + oppId + '.webm';
        cv.PathOnClient = cv.Title;
        cv.VersionData = EncodingUtil.base64Decode(audioBase64);
        cv.FirstPublishLocationId = ai.Id;
        insert cv;

        // Save reference
        ai.Audio_ContentVersion_Id__c = cv.Id;
        ai.Status__c = 'Audio Uploaded';
        update ai;

        Map<String, Object> result = new Map<String, Object>();
        result.put('contentVersionId', cv.Id);
        result.put('success', true);
        return result;
    }

    // ═══════════════════════════════════════
    //  PROCESS AUDIO — Whisper transcription + LLaMA analysis
    //  Called after audio upload, runs as Queueable
    // ═══════════════════════════════════════
    @AuraEnabled
    public static void processAudio(Id oppId) {
        List<Architecture_Interview__c> aiList = [
            SELECT Id, Audio_ContentVersion_Id__c FROM Architecture_Interview__c
            WHERE Opportunity__c = :oppId LIMIT 1
        ];
        if (aiList.isEmpty() || String.isBlank(aiList[0].Audio_ContentVersion_Id__c)) {
            throw new AuraHandledException('Aucun audio trouvé. Veuillez d\'abord uploader l\'enregistrement.');
        }

        Architecture_Interview__c ai = aiList[0];
        ai.Status__c = 'Processing';
        update ai;

        System.enqueueJob(new ArchitectureAudioProcessor(oppId, ai.Id, ai.Audio_ContentVersion_Id__c));
    }

    // ═══════════════════════════════════════
    //  GET PROCESSING STATUS — polling from LWC
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> getProcessingStatus(Id oppId) {
        List<Architecture_Interview__c> aiList = [
            SELECT Id, Status__c, Score__c, Transcription__c, AI_Feedback__c
            FROM Architecture_Interview__c
            WHERE Opportunity__c = :oppId LIMIT 1
        ];

        Map<String, Object> result = new Map<String, Object>();
        if (aiList.isEmpty()) {
            result.put('status', 'Not Found');
            return result;
        }

        Architecture_Interview__c ai = aiList[0];
        result.put('status', ai.Status__c);
        result.put('score', ai.Score__c);
        result.put('transcription', ai.Transcription__c);
        result.put('aiFeedback', ai.AI_Feedback__c);
        result.put('isComplete', ai.Status__c == 'Completed');
        return result;
    }

    // ═══════════════════════════════════════
    //  REQUEST RESCHEDULE — candidat demande un report
    // ═══════════════════════════════════════
    @AuraEnabled
    public static Map<String, Object> requestReschedule(Id oppId, String reason) {
        List<Architecture_Interview__c> aiList = [
            SELECT Id, Reschedule_Requested__c, Interview_DateTime__c, Opportunity__c
            FROM Architecture_Interview__c
            WHERE Opportunity__c = :oppId LIMIT 1
        ];

        if (aiList.isEmpty()) {
            throw new AuraHandledException('Aucun entretien architecture trouvé.');
        }

        Architecture_Interview__c ai = aiList[0];
        if (ai.Reschedule_Requested__c == true) {
            throw new AuraHandledException('Vous avez déjà utilisé votre demande de report.');
        }

        ai.Reschedule_Requested__c = true;
        update ai;

        // Notify recruiter
        String candidateName = 'Candidat';
        List<Lead> leads = [
            SELECT FirstName, LastName, Email, Description FROM Lead
            WHERE ConvertedOpportunityId = :oppId AND IsConverted = true LIMIT 1
        ];
        if (!leads.isEmpty()) {
            candidateName = ((leads[0].FirstName != null ? leads[0].FirstName : '') + ' ' +
                            (leads[0].LastName != null ? leads[0].LastName : '')).trim();
        }

        // Find recruiter email via JOB_ID
        String recruiterEmail = '';
        if (!leads.isEmpty() && leads[0].Description != null) {
            for (String line : leads[0].Description.split('\n')) {
                if (line.startsWith('JOB_ID:')) {
                    try {
                        Id jobPostingId = (Id) line.replace('JOB_ID:', '').trim();
                        List<Opportunity> jobs = [SELECT Owner.Email FROM Opportunity WHERE Id = :jobPostingId LIMIT 1];
                        if (!jobs.isEmpty()) recruiterEmail = jobs[0].Owner.Email;
                    } catch (Exception e) { /* ignore */ }
                    break;
                }
            }
        }

        if (String.isNotBlank(recruiterEmail)) {
            String dateFmt = ai.Interview_DateTime__c != null
                ? ai.Interview_DateTime__c.format('dd/MM/yyyy \'à\' HH:mm', 'Europe/Paris') : 'Non définie';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ recruiterEmail });
            mail.setSubject('🔄 Demande de report — Entretien Architecture — ' + candidateName);
            mail.setHtmlBody(
                '<div style="font-family:Inter,Arial,sans-serif;max-width:600px;margin:0 auto;">'
                + '<div style="background:linear-gradient(135deg,#f59e0b,#d97706);padding:30px 40px;border-radius:16px 16px 0 0;">'
                + '<h1 style="color:#fff;margin:0;font-size:22px;">📅 Demande de report</h1>'
                + '<p style="color:rgba(255,255,255,0.8);margin:8px 0 0;">Entretien Architecture — HR Talent Portal</p>'
                + '</div>'
                + '<div style="background:#fff;padding:30px 40px;border:1px solid #e5e7eb;border-top:none;">'
                + '<p style="font-size:15px;color:#334155;line-height:1.7;">Le candidat <strong>' + candidateName + '</strong> demande le report de son entretien architecture.</p>'
                + '<div style="background:#fffbeb;border:1px solid #fbbf24;border-radius:12px;padding:16px 20px;margin:20px 0;">'
                + '<p style="margin:0 0 8px;font-size:13px;color:#92400e;font-weight:600;">📅 Date prévue : ' + dateFmt + '</p>'
                + '<p style="margin:0;font-size:13px;color:#92400e;font-weight:600;">💬 Motif : ' + (String.isNotBlank(reason) ? reason.escapeHtml4() : 'Non précisé') + '</p>'
                + '</div>'
                + '<p style="font-size:14px;color:#475569;">Veuillez replanifier depuis le dashboard recruteur.</p>'
                + '</div>'
                + '<div style="text-align:center;padding:16px;font-size:11px;color:#94a3b8;">TALAN Tunisie — HR Talent Portal</div>'
                + '</div>'
            );
            try {
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Reschedule email error: ' + e.getMessage());
            }
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('success', true);
        result.put('message', 'Votre demande de report a été envoyée au recruteur.');
        return result;
    }
}
