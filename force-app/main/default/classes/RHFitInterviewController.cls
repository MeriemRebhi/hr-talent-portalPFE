public without sharing class RHFitInterviewController {

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRHFitInterviewInfo(Id oppId) {
        Opportunity opp = [
            SELECT Id, Name, StageName, AccountId, Score_Matching__c, Gaming_Test_Score__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        List<RH_Fit_Interview__c> listRec = [
            SELECT Id, Interview_DateTime__c, Duration__c, Status__c,
                   Meet_Link__c, Jitsi_Room__c, Audio_ContentVersion_Id__c,
                   Generated_Questions__c, Transcription__c, AI_Feedback__c,
                   AI_RHFit_Score__c, Sentiment_Score__c, Sentiment_Label__c,
                   Recruiter_Validated_Score__c, Reschedule_Requested__c
            FROM RH_Fit_Interview__c
            WHERE Opportunity__c = :oppId
            LIMIT 1
        ];
        RH_Fit_Interview__c rec = listRec.isEmpty() ? new RH_Fit_Interview__c() : listRec[0];

        Lead lead = getConvertedLead(oppId);
        String candidateName = getCandidateName(lead);
        String jobTitle = resolveJobTitle(opp.Name, lead);

        Map<String, Object> result = new Map<String, Object>();
        result.put('oppId', opp.Id);
        result.put('candidateName', candidateName);
        result.put('jobTitle', jobTitle);
        result.put('stageName', opp.StageName);
        result.put('isScheduled', rec.Interview_DateTime__c != null);
        result.put('scheduledDate', rec.Interview_DateTime__c);
        result.put('duration', rec.Duration__c);
        result.put('status', rec.Status__c);
        result.put('meetLink', rec.Meet_Link__c);
        result.put('jitsiRoom', rec.Jitsi_Room__c);
        result.put('hasAudio', String.isNotBlank(rec.Audio_ContentVersion_Id__c));
        result.put('generatedQuestions', rec.Generated_Questions__c);
        result.put('transcription', rec.Transcription__c);
        result.put('aiFeedback', rec.AI_Feedback__c);
        result.put('aiScore', rec.AI_RHFit_Score__c);
        result.put('sentimentScore', rec.Sentiment_Score__c);
        result.put('sentimentLabel', rec.Sentiment_Label__c);
        result.put('validatedScore', rec.Recruiter_Validated_Score__c);
        result.put('rescheduleRequested', rec.Reschedule_Requested__c);
        result.put('alreadyCompleted', rec.Status__c == 'Completed');
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> uploadAudio(Id oppId, String audioBase64, String fileName) {
        if (UserInfo.getUserType() == 'Guest') {
            throw new AuraHandledException('Action reservee au recruteur.');
        }
        if (String.isBlank(audioBase64)) {
            throw new AuraHandledException('Aucun fichier audio fourni.');
        }
        // Legacy base64 upload path (Apex payload/heap constraints).
        // For larger files, use lightning-file-upload + registerUploadedAudioFile (Salesforce Files direct).
        Integer maxBytes = 4 * 1024 * 1024;
        Integer estimatedBytes = (audioBase64.length() * 3) / 4;
        if (estimatedBytes > maxBytes) {
            throw new AuraHandledException('Mode legacy base64 limite a 4 MB. Utilisez Salesforce Files direct pour des fichiers plus grands.');
        }

        RH_Fit_Interview__c rec = getOrCreateInterviewRecord(oppId);
        Blob audioBlob;
        try {
            audioBlob = EncodingUtil.base64Decode(audioBase64);
        } catch (Exception ex) {
            throw new AuraHandledException('Fichier audio invalide. Veuillez reessayer.');
        }
        if (audioBlob == null || audioBlob.size() <= 0) {
            throw new AuraHandledException('Fichier audio vide. Veuillez reessayer.');
        }
        if (audioBlob.size() > maxBytes) {
            throw new AuraHandledException('Mode legacy base64 limite a 4 MB. Utilisez Salesforce Files direct pour des fichiers plus grands.');
        }

        ContentVersion cv = new ContentVersion();
        cv.Title = String.isNotBlank(fileName) ? fileName : ('rhfit-interview-' + oppId + '.webm');
        cv.PathOnClient = cv.Title;
        cv.VersionData = audioBlob;
        cv.FirstPublishLocationId = rec.Id;
        insert cv;

        rec.Audio_ContentVersion_Id__c = cv.Id;
        rec.Status__c = 'Audio Uploaded';
        update rec;

        return new Map<String, Object>{
            'contentVersionId' => cv.Id,
            'success' => true
        };
    }

    @AuraEnabled
    public static Map<String, Object> registerUploadedAudioFile(Id oppId, Id contentDocumentId) {
        if (UserInfo.getUserType() == 'Guest') {
            throw new AuraHandledException('Action reservee au recruteur.');
        }
        if (oppId == null || contentDocumentId == null) {
            throw new AuraHandledException('Fichier audio invalide.');
        }

        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, ContentSize, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];
        if (versions.isEmpty()) {
            throw new AuraHandledException('Fichier audio introuvable apres upload.');
        }
        ContentVersion cv = versions[0];
        if (cv.ContentSize == null || cv.ContentSize <= 0) {
            throw new AuraHandledException('Fichier audio vide.');
        }
        if (cv.ContentSize > 25 * 1024 * 1024) {
            throw new AuraHandledException('Audio trop volumineux. Taille max: 25 MB.');
        }

        RH_Fit_Interview__c rec = getOrCreateInterviewRecord(oppId);
        rec.Audio_ContentVersion_Id__c = cv.Id;
        rec.Status__c = 'Audio Uploaded';
        update rec;

        // Ensure the uploaded file is also linked to the RH Fit interview record.
        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :cv.ContentDocumentId
              AND LinkedEntityId = :rec.Id
            LIMIT 1
        ];
        if (links.isEmpty()) {
            ContentDocumentLink l = new ContentDocumentLink();
            l.ContentDocumentId = cv.ContentDocumentId;
            l.LinkedEntityId = rec.Id;
            l.ShareType = 'V';
            l.Visibility = 'AllUsers';
            insert l;
        }

        String displayName = cv.Title;
        if (String.isNotBlank(cv.FileExtension) && !displayName.toLowerCase().endsWith('.' + cv.FileExtension.toLowerCase())) {
            displayName += '.' + cv.FileExtension;
        }
        return new Map<String, Object>{
            'success' => true,
            'contentVersionId' => cv.Id,
            'fileName' => displayName,
            'contentSize' => cv.ContentSize
        };
    }

    @AuraEnabled
    public static void processAudio(Id oppId) {
        if (UserInfo.getUserType() == 'Guest') {
            throw new AuraHandledException('Action reservee au recruteur.');
        }
        if (oppId == null) {
            throw new AuraHandledException('Candidature RH Fit introuvable.');
        }
        List<RH_Fit_Interview__c> listRec = [
            SELECT Id, Audio_ContentVersion_Id__c, Status__c
            FROM RH_Fit_Interview__c
            WHERE Opportunity__c = :oppId
            LIMIT 1
        ];
        RH_Fit_Interview__c rec = listRec.isEmpty()
            ? getOrCreateInterviewRecord(oppId)
            : listRec[0];

        Id audioVersionId = rec.Audio_ContentVersion_Id__c;
        if (audioVersionId == null) {
            audioVersionId = resolveLatestAudioVersionId(oppId, rec.Id);
        }
        if (audioVersionId == null) {
            throw new AuraHandledException(
                'Aucun audio trouve. Uploadez un fichier (Salesforce Files), puis relancez transcription + IA.'
            );
        }

        rec.Audio_ContentVersion_Id__c = audioVersionId;
        rec.Status__c = 'Processing';
        update rec;

        System.enqueueJob(new RHFitAudioProcessor(oppId, rec.Id, audioVersionId));
    }

    @AuraEnabled
    public static Map<String, Object> getProcessingStatus(Id oppId) {
        List<RH_Fit_Interview__c> listRec = [
            SELECT Status__c, AI_RHFit_Score__c, Sentiment_Score__c, Sentiment_Label__c,
                   Transcription__c, AI_Feedback__c
            FROM RH_Fit_Interview__c
            WHERE Opportunity__c = :oppId
            LIMIT 1
        ];
        if (listRec.isEmpty()) {
            return new Map<String, Object>{ 'status' => 'Not Found' };
        }

        RH_Fit_Interview__c rec = listRec[0];
        return new Map<String, Object>{
            'status' => rec.Status__c,
            'score' => rec.AI_RHFit_Score__c,
            'sentimentScore' => rec.Sentiment_Score__c,
            'sentimentLabel' => rec.Sentiment_Label__c,
            'transcription' => rec.Transcription__c,
            'aiFeedback' => rec.AI_Feedback__c,
            'isComplete' => rec.Status__c == 'Completed'
        };
    }

    @AuraEnabled
    public static Map<String, Object> requestReschedule(Id oppId, String reason) {
        RH_Fit_Interview__c rec = getOrCreateInterviewRecord(oppId);
        if (rec.Reschedule_Requested__c == true) {
            throw new AuraHandledException('Vous avez deja utilise votre demande de report.');
        }

        rec.Reschedule_Requested__c = true;
        update rec;

        notifyRecruiterReschedule(oppId, reason, rec.Interview_DateTime__c, 'RH Fit');

        return new Map<String, Object>{
            'success' => true,
            'message' => 'Votre demande de report a ete envoyee au recruteur.'
        };
    }

    @AuraEnabled
    public static Map<String, Object> generateQuestions(Id oppId) {
        Lead lead = getConvertedLead(oppId);
        String jobOfferContext = buildJobOfferContext(oppId, lead);
        String candidateContext = buildCandidateContext(oppId, lead);
        String previousInterviewContext = buildPreviousInterviewContext(oppId);
        String recruiterGuidance =
            'Concentre toi sur culture fit, communication, motivation, collaboration, gestion de conflit, alignement valeurs. ' +
            'Reponds exclusivement en francais dans toutes les valeurs JSON.';

        String promptResponse = invokePrompt(jobOfferContext, candidateContext, previousInterviewContext, recruiterGuidance);

        RH_Fit_Interview__c rec = getOrCreateInterviewRecord(oppId);
        if (String.isBlank(promptResponse)) {
            throw new AuraHandledException(
                'Einstein a retourne une reponse vide. Verifiez le Prompt Template RH_Fit_Interview_Question_Generator.'
            );
        }
        rec.Generated_Questions__c = promptResponse.left(32768);
        update rec;

        return new Map<String, Object>{
            'success' => true,
            'questions' => rec.Generated_Questions__c
        };
    }

    private static String invokePrompt(
        String jobOfferContext,
        String candidateContext,
        String previousInterviewContext,
        String recruiterGuidance
    ) {
        Invocable.Action action = Invocable.Action.createCustomAction(
            'generatePromptResponse',
            null,
            'RH_Fit_Interview_Question_Generator'
        );

        action.setInvocationParameter('isPreview', false);
        action.setInvocationParameter('applicationName', 'PromptBuilderPreview');
        action.setInvocationParameter('additionalConfig', new Map<String, Object>());
        action.setInvocationParameter('Input:JobOfferContext', jobOfferContext);
        action.setInvocationParameter('Input:CandidateContext', candidateContext);
        action.setInvocationParameter('Input:PreviousInterviewContext', previousInterviewContext);
        action.setInvocationParameter('Input:RecruiterGuidance', recruiterGuidance);

        List<Invocable.Action.Result> results = action.invoke();
        if (results == null || results.isEmpty()) {
            throw new AuraHandledException('Aucune reponse Einstein.');
        }
        Invocable.Action.Result res = results[0];
        if (!res.isSuccess()) {
            List<String> messages = new List<String>();
            if (res.getErrors() != null) {
                for (Invocable.Action.Error err : res.getErrors()) {
                    messages.add(err.getMessage());
                }
            }
            throw new AuraHandledException('Erreur Einstein: ' + String.join(messages, ' | '));
        }

        Map<String, Object> outputs = res.getOutputParameters();
        if (outputs == null || outputs.isEmpty()) {
            return '';
        }

        if (outputs.containsKey('promptResponse') && outputs.get('promptResponse') != null) {
            return String.valueOf(outputs.get('promptResponse'));
        }
        if (outputs.containsKey('response') && outputs.get('response') != null) {
            return String.valueOf(outputs.get('response'));
        }

        for (String k : outputs.keySet()) {
            if (k != null && k.toLowerCase().contains('prompt') && outputs.get(k) != null) {
                return String.valueOf(outputs.get(k));
            }
        }

        return JSON.serialize(outputs);
    }

    private static RH_Fit_Interview__c getOrCreateInterviewRecord(Id oppId) {
        List<RH_Fit_Interview__c> listRec = [
            SELECT Id, Interview_DateTime__c, Duration__c, Meet_Link__c, Jitsi_Room__c, Status__c,
                   Reschedule_Requested__c
            FROM RH_Fit_Interview__c
            WHERE Opportunity__c = :oppId
            LIMIT 1
        ];
        if (!listRec.isEmpty()) return listRec[0];

        RH_Fit_Interview__c rec = new RH_Fit_Interview__c();
        rec.Opportunity__c = oppId;
        rec.Status__c = 'Draft';
        insert rec;
        return rec;
    }

    private static Lead getConvertedLead(Id oppId) {
        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Email, Description, Score_Matching__c,
                   AI_Recommendation__c, AI_Points_Forts__c, AI_Points_Faibles__c
            FROM Lead
            WHERE ConvertedOpportunityId = :oppId
            AND IsConverted = true
            LIMIT 1
        ];
        return leads.isEmpty() ? null : leads[0];
    }

    private static String getCandidateName(Lead lead) {
        if (lead == null) return 'Candidat';
        String fullName = ((lead.FirstName != null ? lead.FirstName : '') + ' ' +
            (lead.LastName != null ? lead.LastName : '')).trim();
        return String.isNotBlank(fullName) ? fullName : 'Candidat';
    }

    private static Id extractJobPostingId(Lead lead) {
        if (lead == null || String.isBlank(lead.Description)) return null;
        for (String line : lead.Description.split('\n')) {
            if (line.startsWith('JOB_ID:')) {
                try {
                    return (Id) line.replace('JOB_ID:', '').trim();
                } catch (Exception e) {
                    return null;
                }
            }
        }
        return null;
    }

    private static String resolveJobTitle(String oppName, Lead lead) {
        Id jobId = extractJobPostingId(lead);
        if (jobId == null) return oppName;
        List<Opportunity> jobs = [SELECT Name FROM Opportunity WHERE Id = :jobId LIMIT 1];
        return jobs.isEmpty() ? oppName : jobs[0].Name;
    }

    private static String buildJobOfferContext(Id oppId, Lead lead) {
        Id jobId = extractJobPostingId(lead);
        if (jobId == null) {
            Opportunity opp = [SELECT Name, Description FROM Opportunity WHERE Id = :oppId LIMIT 1];
            return 'Poste: ' + opp.Name + '\nDescription: ' + (opp.Description != null ? opp.Description : 'N/A');
        }

        List<Opportunity> jobs = [
            SELECT Name, Description_Poste__c, Departement__c, Localisation__c, Type_de_Contrat__c
            FROM Opportunity
            WHERE Id = :jobId
            LIMIT 1
        ];
        if (jobs.isEmpty()) return 'N/A';
        Opportunity j = jobs[0];
        return 'Poste: ' + j.Name + '\n' +
            'Departement: ' + j.Departement__c + '\n' +
            'Localisation: ' + j.Localisation__c + '\n' +
            'Contrat: ' + j.Type_de_Contrat__c + '\n' +
            'Description: ' + j.Description_Poste__c;
    }

    private static String buildCandidateContext(Id oppId, Lead lead) {
        Opportunity opp = [SELECT Score_Matching__c, Gaming_Test_Score__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
        return
            'Nom: ' + getCandidateName(lead) + '\n' +
            'Email: ' + (lead != null ? lead.Email : 'N/A') + '\n' +
            'Score Matching: ' + (opp.Score_Matching__c != null ? String.valueOf(opp.Score_Matching__c) : 'N/A') + '\n' +
            'Score Gaming: ' + (opp.Gaming_Test_Score__c != null ? String.valueOf(opp.Gaming_Test_Score__c) : 'N/A') + '\n' +
            'Reco IA CV: ' + (lead != null ? lead.AI_Recommendation__c : 'N/A') + '\n' +
            'Points forts CV: ' + (lead != null ? lead.AI_Points_Forts__c : 'N/A') + '\n' +
            'Points faibles CV: ' + (lead != null ? lead.AI_Points_Faibles__c : 'N/A');
    }

    private static String buildPreviousInterviewContext(Id oppId) {
        String result = '';

        List<Technical_Interview__c> tech = [
            SELECT Score__c, Composite_Score__c, Manager_Notes__c
            FROM Technical_Interview__c
            WHERE Opportunity__c = :oppId
            LIMIT 1
        ];
        if (!tech.isEmpty()) {
            result += 'Technique - Score: ' + tech[0].Score__c +
                ', Composite: ' + tech[0].Composite_Score__c + '\n' +
                'Notes manager technique: ' + tech[0].Manager_Notes__c + '\n\n';
        }

        List<Architecture_Interview__c> arch = [
            SELECT Score__c, Manager_Notes__c, AI_Feedback__c
            FROM Architecture_Interview__c
            WHERE Opportunity__c = :oppId
            LIMIT 1
        ];
        if (!arch.isEmpty()) {
            result += 'Architecture - Score: ' + arch[0].Score__c + '\n' +
                'Notes manager architecture: ' + arch[0].Manager_Notes__c + '\n' +
                'Feedback IA architecture: ' + arch[0].AI_Feedback__c;
        }

        return String.isNotBlank(result) ? result : 'Aucun historique d entretien disponible.';
    }

    private static Id resolveLatestAudioVersionId(Id oppId, Id interviewId) {
        Set<Id> linkedEntityIds = new Set<Id>();
        if (oppId != null) linkedEntityIds.add(oppId);
        if (interviewId != null) linkedEntityIds.add(interviewId);
        if (linkedEntityIds.isEmpty()) return null;

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :linkedEntityIds
            ORDER BY SystemModstamp DESC
            LIMIT 200
        ];
        if (links.isEmpty()) return null;

        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            if (link.ContentDocumentId != null) {
                contentDocumentIds.add(link.ContentDocumentId);
            }
        }
        if (contentDocumentIds.isEmpty()) return null;

        List<ContentVersion> versions = [
            SELECT Id, FileExtension, ContentSize, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
            AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
        for (ContentVersion cv : versions) {
            if (cv.ContentSize != null && cv.ContentSize > 0 && isSupportedAudioExtension(cv.FileExtension)) {
                return cv.Id;
            }
        }
        return null;
    }

    private static Boolean isSupportedAudioExtension(String ext) {
        if (String.isBlank(ext)) return false;
        String normalized = ext.trim().toLowerCase();
        Set<String> allowed = new Set<String>{ 'webm', 'mp3', 'wav', 'm4a', 'ogg', 'flac', 'mp4', 'aac' };
        return allowed.contains(normalized);
    }

    private static void notifyRecruiterReschedule(Id oppId, String reason, Datetime plannedDate, String interviewType) {
        Lead lead = getConvertedLead(oppId);
        String candidateName = lead != null ? getCandidateName(lead) : 'Candidat';

        Set<String> recruiterEmails = new Set<String>();
        Opportunity appOpp = [
            SELECT Id, Name, Owner.Email
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        if (String.isBlank(candidateName) && String.isNotBlank(appOpp.Name)) {
            candidateName = appOpp.Name;
        }
        if (String.isNotBlank(appOpp.Owner != null ? appOpp.Owner.Email : null)) {
            recruiterEmails.add(appOpp.Owner.Email);
        }

        if (lead != null) {
            Id jobId = extractJobPostingId(lead);
            if (jobId != null) {
                List<Opportunity> jobs = [SELECT Owner.Email FROM Opportunity WHERE Id = :jobId LIMIT 1];
                if (!jobs.isEmpty() && String.isNotBlank(jobs[0].Owner.Email)) {
                    recruiterEmails.add(jobs[0].Owner.Email);
                }
            }
        }
        if (String.isNotBlank(UserInfo.getUserEmail())) {
            recruiterEmails.add(UserInfo.getUserEmail());
        }
        if (recruiterEmails.isEmpty()) return;

        String dateFmt = plannedDate != null
            ? plannedDate.format('dd/MM/yyyy \'a\' HH:mm', 'Europe/Paris')
            : 'Non definie';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>(recruiterEmails));
        mail.setSubject('Demande de report - ' + interviewType + ' - ' + candidateName);
        mail.setPlainTextBody(
            'Le candidat ' + candidateName + ' demande un report.' + '\n' +
            'Date prevue: ' + dateFmt + '\n' +
            'Motif: ' + (String.isNotBlank(reason) ? reason : 'Non precise')
        );
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }
}
