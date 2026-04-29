/**
 * InternalDashboardController — HR Talent Portal
 * Controller partagé pour les dashboards internes :
 * Recruteur, Manager, Responsable RH
 */
public with sharing class InternalDashboardController {

    // ══════════════════════════════════════════
    // RECRUTEUR — Opportunités à gérer
    // ══════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRecruteurData() {
        Map<String, Object> result = new Map<String, Object>();

        Id currentUserId = UserInfo.getUserId();

        // Find Job Postings owned by the current recruiter
        List<Opportunity> myJobs = [
            SELECT Id FROM Opportunity
            WHERE RecordType.DeveloperName = 'Job_Posting'
            AND OwnerId = :currentUserId
        ];
        Set<Id> myJobIds = new Set<Id>();
        for (Opportunity j : myJobs) myJobIds.add(j.Id);

        // Find Leads that reference these Job Postings (via JOB_ID in Description)
        Set<Id> myOppIds = new Set<Id>();
        if (!myJobIds.isEmpty()) {
            for (Lead l : [
                SELECT ConvertedOpportunityId, Description
                FROM Lead
                WHERE IsConverted = true AND ConvertedOpportunityId != null
                LIMIT 500
            ]) {
                if (l.Description == null) continue;
                for (Id jId : myJobIds) {
                    if (l.Description.contains('JOB_ID:' + jId)) {
                        myOppIds.add(l.ConvertedOpportunityId);
                        break;
                    }
                }
            }
        }

        // Also include Application opps directly owned by this user
        for (Opportunity o : [
            SELECT Id FROM Opportunity
            WHERE RecordType.DeveloperName = 'Application'
            AND OwnerId = :currentUserId
            LIMIT 200
        ]) {
            myOppIds.add(o.Id);
        }

        // Query only filtered opportunities
        List<Opportunity> opps;
        if (myOppIds.isEmpty()) {
            opps = new List<Opportunity>();
        } else {
            opps = [
                SELECT Id, Name, StageName, CloseDate, AccountId, Account.Name,
                       Description, CreatedDate, RecordType.DeveloperName,
                       Score_Matching__c,
                       Gaming_Test_DateTime__c, Gaming_Test_Duration__c, Gaming_Meet_Link__c,
                       Gaming_Test_Score__c, Gaming_Test_Status__c,
                       Manager_Validated_Score__c
                FROM Opportunity
                WHERE RecordType.DeveloperName = 'Application'
                AND Id IN :myOppIds
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        }

        // Collect opp IDs for Technical_Interview__c lookup
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity o : opps) oppIds.add(o.Id);

        // Query Technical_Interview__c records
        Map<Id, Technical_Interview__c> tiByOpp = new Map<Id, Technical_Interview__c>();
        for (Technical_Interview__c ti : [
            SELECT Opportunity__c, Interview_DateTime__c, Duration__c,
                   Meet_Link__c, Score__c, Status__c, Composite_Score__c,
                   Reschedule_Requested__c
            FROM Technical_Interview__c
            WHERE Opportunity__c IN :oppIds
        ]) {
            tiByOpp.put(ti.Opportunity__c, ti);
        }

        // Query Architecture_Interview__c records
        Map<Id, Architecture_Interview__c> archByOpp = new Map<Id, Architecture_Interview__c>();
        for (Architecture_Interview__c ai : [
            SELECT Opportunity__c, Interview_DateTime__c, Duration__c,
                   Meet_Link__c, Jitsi_Room__c, Score__c, Status__c,
                   Transcription__c, AI_Feedback__c, Reschedule_Requested__c
            FROM Architecture_Interview__c
            WHERE Opportunity__c IN :oppIds
        ]) {
            archByOpp.put(ai.Opportunity__c, ai);
        }

        // Query RH_Fit_Interview__c records
        Map<Id, RH_Fit_Interview__c> rhfitByOpp = new Map<Id, RH_Fit_Interview__c>();
        for (RH_Fit_Interview__c ri : [
            SELECT Opportunity__c, Interview_DateTime__c, Duration__c,
                   Meet_Link__c, Jitsi_Room__c, Status__c,
                   Audio_ContentVersion_Id__c,
                   Generated_Questions__c, AI_RHFit_Score__c,
                   Sentiment_Score__c, Sentiment_Label__c,
                   Recruiter_Validated_Score__c, Reschedule_Requested__c
            FROM RH_Fit_Interview__c
            WHERE Opportunity__c IN :oppIds
        ]) {
            rhfitByOpp.put(ri.Opportunity__c, ri);
        }

        // Join Lead (score IA) via ConvertedOpportunityId

        Map<Id, Lead> oppLeadMap = new Map<Id, Lead>();
        for (Lead l : [
            SELECT Id, ConvertedOpportunityId, Score_Matching__c,
                   AI_Recommendation__c, AI_Points_Forts__c, AI_Points_Faibles__c,
                   FirstName, LastName, Email, Phone, Description
            FROM Lead
            WHERE ConvertedOpportunityId IN :oppIds
        ]) {
            oppLeadMap.put(l.ConvertedOpportunityId, l);
        }

        // Resolve Job Posting titles via JOB_ID in Lead.Description
        Set<Id> jobIds = new Set<Id>();
        Map<Id, Id> oppIdToJobId = new Map<Id, Id>();
        for (Id oId : oppIds) {
            Lead l = oppLeadMap.get(oId);
            if (l == null || String.isBlank(l.Description)) continue;
            for (String line : l.Description.split('\n')) {
                if (line.startsWith('JOB_ID:')) {
                    String jId = line.replace('JOB_ID:', '').trim();
                    if (String.isNotBlank(jId)) {
                        try {
                            Id jobOppId = (Id) jId;
                            jobIds.add(jobOppId);
                            oppIdToJobId.put(oId, jobOppId);
                        } catch (Exception ex) {}
                    }
                    break;
                }
            }
        }
        Map<Id, String> jobNameById = new Map<Id, String>();
        if (!jobIds.isEmpty()) {
            for (Opportunity job : [SELECT Id, Name FROM Opportunity WHERE Id IN :jobIds]) {
                jobNameById.put(job.Id, job.Name);
            }
        }

        // Stats par stage
        Integer gaming = 0, technique = 0, architecture = 0, rhfit = 0, closed = 0;
        for (Opportunity o : opps) {
            String s = o.StageName != null ? o.StageName : '';
            if      (s == 'Gaming')          gaming++;
            else if (s == 'Technique')       technique++;
            else if (s == 'Architecture')    architecture++;
            else if (s == 'RH Fit')          rhfit++;
            else if (s.startsWith('Closed')) closed++;
        }

        // Build enriched rows
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Opportunity o : opps) {
            Lead l = oppLeadMap.get(o.Id);
            Decimal score = (l != null && l.Score_Matching__c != null) ? l.Score_Matching__c : null;
            String recoType = 'none';
            String reco     = 'Score IA indisponible';
            if (score != null) {
                if      (score >= 70) { recoType = 'high';   reco = 'Fortement recommandé'; }
                else if (score >= 50) { recoType = 'mid';    reco = 'À évaluer en entretien'; }
                else if (score >= 30) { recoType = 'low';    reco = 'Profil risqué'; }
                else                  { recoType = 'reject'; reco = 'Non recommandé'; }
            }
            Map<String, Object> row = new Map<String, Object>();
            row.put('Id',              o.Id);
            row.put('Name',            o.Name);
            row.put('StageName',       o.StageName);
            row.put('CloseDate',       o.CloseDate);
            row.put('accountName',     o.Account != null ? o.Account.Name : '—');
            row.put('score',           score);
            row.put('reco',            reco);
            row.put('recoType',        recoType);
            row.put('leadEmail',       l != null ? l.Email       : '');
            row.put('leadPhone',       l != null ? l.Phone       : '');
            row.put('aiForts',         l != null ? l.AI_Points_Forts__c   : '');
            row.put('aiReco',          l != null ? l.AI_Recommendation__c : '');
            row.put('gamingDateTime',  o.Gaming_Test_DateTime__c);
            row.put('gamingDuration',  o.Gaming_Test_Duration__c);
            row.put('gamingMeetLink',  o.Gaming_Meet_Link__c);
            row.put('gamingScore',     o.Gaming_Test_Score__c);
            row.put('gamingStatus',    o.Gaming_Test_Status__c);
            row.put('managerValidatedScore', o.Manager_Validated_Score__c);
            // Technical interview from Technical_Interview__c
            Technical_Interview__c ti = tiByOpp.get(o.Id);
            row.put('techDateTime',    ti != null ? ti.Interview_DateTime__c : null);
            row.put('techDuration',    ti != null ? ti.Duration__c : null);
            row.put('techMeetLink',    ti != null ? ti.Meet_Link__c : null);
            row.put('techScore',       ti != null ? ti.Score__c : null);
            row.put('techStatus',      ti != null ? ti.Status__c : null);
            row.put('techComposite',   ti != null ? ti.Composite_Score__c : null);
            row.put('techRescheduleRequested', ti != null ? ti.Reschedule_Requested__c : false);
            // Architecture interview from Architecture_Interview__c
            Architecture_Interview__c archI = archByOpp.get(o.Id);
            row.put('archDateTime',    archI != null ? archI.Interview_DateTime__c : null);
            row.put('archDuration',    archI != null ? archI.Duration__c : null);
            row.put('archMeetLink',    archI != null ? archI.Meet_Link__c : null);
            row.put('archJitsiRoom',   archI != null ? archI.Jitsi_Room__c : null);
            row.put('archScore',       archI != null ? archI.Score__c : null);
            row.put('archStatus',      archI != null ? archI.Status__c : null);
            row.put('archRescheduleRequested', archI != null ? archI.Reschedule_Requested__c : false);
            // RH Fit interview from RH_Fit_Interview__c
            RH_Fit_Interview__c rhI = rhfitByOpp.get(o.Id);
            row.put('rhfitDateTime',    rhI != null ? rhI.Interview_DateTime__c : null);
            row.put('rhfitDuration',    rhI != null ? rhI.Duration__c : null);
            row.put('rhfitMeetLink',    rhI != null ? rhI.Meet_Link__c : null);
            row.put('rhfitJitsiRoom',   rhI != null ? rhI.Jitsi_Room__c : null);
            row.put('rhfitStatus',      rhI != null ? rhI.Status__c : null);
            row.put('rhfitHasAudio',    rhI != null ? String.isNotBlank(rhI.Audio_ContentVersion_Id__c) : false);
            row.put('rhfitQuestions',   rhI != null ? rhI.Generated_Questions__c : null);
            row.put('rhfitAIScore',     rhI != null ? rhI.AI_RHFit_Score__c : null);
            row.put('rhfitSentimentScore', rhI != null ? rhI.Sentiment_Score__c : null);
            row.put('rhfitSentimentLabel', rhI != null ? rhI.Sentiment_Label__c : null);
            row.put('rhfitValidatedScore', rhI != null ? rhI.Recruiter_Validated_Score__c : null);
            row.put('rhfitRescheduleRequested', rhI != null ? rhI.Reschedule_Requested__c : false);
            // Job Posting title
            String jobTitle = '';
            Id jId = oppIdToJobId.get(o.Id);
            if (jId != null && jobNameById.containsKey(jId)) {
                jobTitle = jobNameById.get(jId);
            }
            row.put('jobTitle', jobTitle);
            rows.add(row);
        }

        result.put('rows',           rows);
        result.put('totalCandidats', opps.size());
        result.put('enGaming',       gaming);
        result.put('enTechnique',    technique);
        result.put('enArchitecture', architecture);
        result.put('enRHFit',        rhfit);
        result.put('closed',         closed);
        return result;
    }

    // ══════════════════════════════════════════
    // ACTION — Planifier le test Gaming
    // ══════════════════════════════════════════

    @AuraEnabled
    public static void scheduleGamingTest(
        Id oppId,
        String testDateTime,
        String duration
    ) {
        try {
            // Parser la chaîne datetime (format: "2026-04-08T10:00" ou "2026-04-08 10:00:00")
            DateTime parsedDt = DateTime.valueOf(testDateTime.replace('T', ' ').length() == 16
                ? testDateTime.replace('T', ' ') + ':00'
                : testDateTime.replace('T', ' '));

            Opportunity opp = [
                SELECT Id, Name, StageName, AccountId,
                       Gaming_Test_DateTime__c, Gaming_Test_Duration__c, Gaming_Meet_Link__c
                FROM Opportunity WHERE Id = :oppId LIMIT 1
            ];

            // Générer lien vers la page Gaming Test (Experience Cloud)
            String meetLink = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/testgaming?id=' + oppId;

            opp.Gaming_Test_DateTime__c = parsedDt;
            opp.Gaming_Test_Duration__c = duration;
            opp.Gaming_Meet_Link__c     = meetLink;
            update opp;

            // Trouver l'email du candidat (Lead converti OU Contact lié)
            String candidatEmail;
            String prenom = '';
            String nom = '';

            // 1) Chercher le Lead converti
            List<Lead> leads = [
                SELECT Id, FirstName, LastName, Email
                FROM Lead
                WHERE ConvertedOpportunityId = :oppId
                LIMIT 1
            ];
            if (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) {
                candidatEmail = leads[0].Email;
                prenom = leads[0].FirstName != null ? leads[0].FirstName : '';
                nom    = leads[0].LastName  != null ? leads[0].LastName  : '';
            }

            // 2) Fallback : chercher via OpportunityContactRole
            if (String.isBlank(candidatEmail)) {
                List<OpportunityContactRole> ocrs = [
                    SELECT ContactId, Contact.FirstName, Contact.LastName, Contact.Email
                    FROM OpportunityContactRole
                    WHERE OpportunityId = :oppId AND Contact.Email != null
                    LIMIT 1
                ];
                if (!ocrs.isEmpty()) {
                    candidatEmail = ocrs[0].Contact.Email;
                    prenom = ocrs[0].Contact.FirstName != null ? ocrs[0].Contact.FirstName : '';
                    nom    = ocrs[0].Contact.LastName  != null ? ocrs[0].Contact.LastName  : '';
                }
            }

            // 3) Fallback : Contact lié au compte de l'Opportunity
            if (String.isBlank(candidatEmail) && opp.AccountId != null) {
                List<Contact> contacts = [
                    SELECT Id, FirstName, LastName, Email
                    FROM Contact
                    WHERE AccountId = :opp.AccountId AND Email != null
                    LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    candidatEmail = contacts[0].Email;
                    prenom = contacts[0].FirstName != null ? contacts[0].FirstName : '';
                    nom    = contacts[0].LastName  != null ? contacts[0].LastName  : '';
                }
            }

            if (String.isNotBlank(candidatEmail)) {

                // Format date en français
                String dateLabel = parsedDt.format('dd/MM/yyyy \'à\' HH:mm');
                String dureeLabel = duration == '30'  ? '30 minutes'
                                  : duration == '60'  ? '1 heure'
                                  : duration == '90'  ? '1h30'
                                  : duration == '120' ? '2 heures'
                                  : duration + ' min';

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ candidatEmail });
                mail.setSubject('📅 Invitation — Test Gaming HR Talent Portal · Talan Tunisie');
                mail.setHtmlBody(
                    '<div style="font-family:Segoe UI,Arial,sans-serif;background:#f4f6f9;padding:40px 0;">'
                    + '<div style="max-width:580px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.10);">'
                    + '<div style="background:linear-gradient(135deg,#1a1f36 0%,#2d3561 100%);padding:40px 40px 32px;">'
                    + '<h1 style="margin:0;color:#fff;font-size:26px;font-weight:700;">🎮 Test Gaming Planifié</h1>'
                    + '<p style="margin:8px 0 0;color:#a0aec0;font-size:15px;">HR Talent Portal · Talan Tunisie</p>'
                    + '</div>'
                    + '<div style="padding:36px 40px;">'
                    + '<p style="font-size:16px;color:#2d3748;margin:0 0 24px;">Bonjour <strong>' + prenom + ' ' + nom + '</strong>,</p>'
                    + '<p style="font-size:15px;color:#4a5568;line-height:1.7;margin:0 0 28px;">'
                    + 'Nous avons le plaisir de vous confirmer la planification de votre <strong>test Gaming</strong> '
                    + 'dans le cadre de votre candidature chez <strong>Talan Tunisie</strong>.'
                    + '</p>'
                    + '<div style="background:#f7faff;border-left:4px solid #667eea;border-radius:8px;padding:20px 24px;margin:0 0 28px;">'
                    + '<table style="width:100%;border-collapse:collapse;">'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">📅 Date &amp; Heure</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dateLabel + '</td></tr>'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">⏱ Durée</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dureeLabel + '</td></tr>'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">🖥 Format</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">Quiz Gaming en ligne</td></tr>'
                    + '</table>'
                    + '</div>'
                    + '<div style="text-align:center;margin:0 0 28px;">'
                    + '<a href="' + meetLink + '" '
                    + 'style="display:inline-block;background:#667eea;color:#ffffff;'
                    + 'font-size:16px;font-weight:700;padding:14px 36px;border-radius:50px;text-decoration:none;">'
                    + '&#127918; Passer le test Gaming'
                    + '</a>'
                    + '</div>'
                    + '<p style="font-size:13px;color:#718096;line-height:1.6;margin:0 0 8px;">'
                    + '<strong>Instructions :</strong> 10 questions adaptées à votre profil, chronomètre par question, '
                    + 'bonus de rapidité. Aucune installation — votre navigateur suffit.'
                    + '</p>'
                    + '</div>'
                    + '<div style="background:#f7faff;border-top:1px solid #e8ecf5;padding:20px 40px;text-align:center;">'
                    + '<p style="margin:0;font-size:12px;color:#a0aec0;">HR Talent Portal · Talan Tunisie · Ne pas répondre à cet email</p>'
                    + '</div>'
                    + '</div></div>'
                );

                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            }
        } catch (Exception e) {
            throw new AuraHandledException('Erreur planification : ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════
    // ACTION — Annuler un test Gaming planifié
    // ══════════════════════════════════════════

    @AuraEnabled
    public static void cancelGamingTest(Id oppId) {
        try {
            Opportunity opp = [
                SELECT Id, Gaming_Test_DateTime__c, Gaming_Test_Duration__c, Gaming_Meet_Link__c
                FROM Opportunity WHERE Id = :oppId LIMIT 1
            ];
            opp.Gaming_Test_DateTime__c = null;
            opp.Gaming_Test_Duration__c = null;
            opp.Gaming_Meet_Link__c     = null;
            update opp;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur annulation : ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════
    // ACTION — Planifier en lot (batch)
    // ══════════════════════════════════════════

    @AuraEnabled
    public static List<Map<String, Object>> scheduleBatchGamingTests(
        List<Id> oppIds,
        String startDateTime,
        String duration,
        Integer gapMinutes
    ) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();

        if (oppIds == null || oppIds.isEmpty()) {
            throw new AuraHandledException('Aucun candidat sélectionné.');
        }
        if (String.isBlank(startDateTime)) {
            throw new AuraHandledException('Veuillez choisir une date de début.');
        }
        // Parser la chaîne datetime
        DateTime parsedStartDt = DateTime.valueOf(startDateTime.replace('T', ' ').length() == 16
            ? startDateTime.replace('T', ' ') + ':00'
            : startDateTime.replace('T', ' '));

        Integer durationMin = Integer.valueOf(duration);
        Integer slotMin = durationMin + gapMinutes; // durée + pause entre chaque

        // Charger toutes les opportunités
        Map<Id, Opportunity> oppsMap = new Map<Id, Opportunity>([
            SELECT Id, Name, StageName, AccountId,
                   Gaming_Test_DateTime__c, Gaming_Test_Duration__c, Gaming_Meet_Link__c
            FROM Opportunity WHERE Id IN :oppIds
        ]);

        // Charger les leads associés pour les emails
        Map<Id, Lead> leadsByOpp = new Map<Id, Lead>();
        for (Lead l : [
            SELECT Id, FirstName, LastName, Email, ConvertedOpportunityId
            FROM Lead WHERE ConvertedOpportunityId IN :oppIds
        ]) {
            leadsByOpp.put(l.ConvertedOpportunityId, l);
        }

        // Charger les OpportunityContactRoles pour fallback
        Map<Id, OpportunityContactRole> ocrByOpp = new Map<Id, OpportunityContactRole>();
        for (OpportunityContactRole ocr : [
            SELECT OpportunityId, Contact.FirstName, Contact.LastName, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId IN :oppIds AND Contact.Email != null
        ]) {
            if (!ocrByOpp.containsKey(ocr.OpportunityId)) {
                ocrByOpp.put(ocr.OpportunityId, ocr);
            }
        }

        // Charger les Contacts par AccountId pour dernier fallback
        Set<Id> accountIds = new Set<Id>();
        for (Opportunity o : oppsMap.values()) {
            if (o.AccountId != null) accountIds.add(o.AccountId);
        }
        Map<Id, Contact> contactByAccount = new Map<Id, Contact>();
        if (!accountIds.isEmpty()) {
            for (Contact c : [
                SELECT Id, FirstName, LastName, Email, AccountId
                FROM Contact WHERE AccountId IN :accountIds AND Email != null
            ]) {
                if (!contactByAccount.containsKey(c.AccountId)) {
                    contactByAccount.put(c.AccountId, c);
                }
            }
        }

        List<Opportunity> toUpdate = new List<Opportunity>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Integer slotIndex = 0;

        for (Id oppId : oppIds) {
            Opportunity opp = oppsMap.get(oppId);
            if (opp == null) continue;

            DateTime slotTime = parsedStartDt.addMinutes(slotIndex * slotMin);
            String meetLink = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/testgaming?id=' + oppId;

            opp.Gaming_Test_DateTime__c = slotTime;
            opp.Gaming_Test_Duration__c = duration;
            opp.Gaming_Meet_Link__c     = meetLink;
            toUpdate.add(opp);

            // Préparer le résultat
            Map<String, Object> row = new Map<String, Object>();
            row.put('oppId', oppId);
            row.put('name', opp.Name);
            row.put('dateTime', slotTime);
            row.put('meetLink', meetLink);
            results.add(row);

            // Préparer l'email — 3-level fallback: Lead → OCR → Contact
            String candidatEmail;
            String prenom = '';
            String nom = '';

            Lead lead = leadsByOpp.get(oppId);
            if (lead != null && String.isNotBlank(lead.Email)) {
                candidatEmail = lead.Email;
                prenom = lead.FirstName != null ? lead.FirstName : '';
                nom    = lead.LastName  != null ? lead.LastName  : '';
            }
            if (String.isBlank(candidatEmail)) {
                OpportunityContactRole ocr = ocrByOpp.get(oppId);
                if (ocr != null) {
                    candidatEmail = ocr.Contact.Email;
                    prenom = ocr.Contact.FirstName != null ? ocr.Contact.FirstName : '';
                    nom    = ocr.Contact.LastName  != null ? ocr.Contact.LastName  : '';
                }
            }
            if (String.isBlank(candidatEmail) && opp.AccountId != null) {
                Contact c = contactByAccount.get(opp.AccountId);
                if (c != null) {
                    candidatEmail = c.Email;
                    prenom = c.FirstName != null ? c.FirstName : '';
                    nom    = c.LastName  != null ? c.LastName  : '';
                }
            }

            if (String.isNotBlank(candidatEmail)) {
                String dateLabel = slotTime.format('dd/MM/yyyy \'à\' HH:mm');
                String dureeLabel = duration == '30'  ? '30 minutes'
                                  : duration == '60'  ? '1 heure'
                                  : duration == '90'  ? '1h30'
                                  : duration == '120' ? '2 heures'
                                  : duration + ' min';

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ candidatEmail });
                mail.setSubject('📅 Invitation — Test Gaming HR Talent Portal · Talan Tunisie');
                mail.setHtmlBody(
                    '<div style="font-family:Segoe UI,Arial,sans-serif;background:#f4f6f9;padding:40px 0;">'
                    + '<div style="max-width:580px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.10);">'
                    + '<div style="background:linear-gradient(135deg,#1a1f36 0%,#2d3561 100%);padding:40px 40px 32px;">'
                    + '<h1 style="margin:0;color:#fff;font-size:26px;font-weight:700;">🎮 Test Gaming Planifié</h1>'
                    + '<p style="margin:8px 0 0;color:#a0aec0;font-size:15px;">HR Talent Portal · Talan Tunisie</p>'
                    + '</div>'
                    + '<div style="padding:36px 40px;">'
                    + '<p style="font-size:16px;color:#2d3748;margin:0 0 24px;">Bonjour <strong>' + prenom + ' ' + nom + '</strong>,</p>'
                    + '<p style="font-size:15px;color:#4a5568;line-height:1.7;margin:0 0 28px;">'
                    + 'Nous avons le plaisir de vous confirmer la planification de votre <strong>test Gaming</strong> '
                    + 'dans le cadre de votre candidature chez <strong>Talan Tunisie</strong>.</p>'
                    + '<div style="background:#f7faff;border-left:4px solid #667eea;border-radius:8px;padding:20px 24px;margin:0 0 28px;">'
                    + '<table style="width:100%;border-collapse:collapse;">'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">📅 Date &amp; Heure</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dateLabel + '</td></tr>'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">⏱ Durée</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dureeLabel + '</td></tr>'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">🖥 Format</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">Quiz Gaming en ligne</td></tr>'
                    + '</table></div>'
                    + '<div style="text-align:center;margin:0 0 28px;">'
                    + '<a href="' + meetLink + '" '
                    + 'style="display:inline-block;background:#667eea;color:#ffffff;'
                    + 'font-size:16px;font-weight:700;padding:14px 36px;border-radius:50px;text-decoration:none;">'
                    + '&#127918; Passer le test Gaming</a></div>'
                    + '<p style="font-size:13px;color:#718096;line-height:1.6;margin:0 0 8px;">'
                    + '<strong>Instructions :</strong> 10 questions adaptées à votre profil, chronomètre par question, '
                    + 'bonus de rapidité. Aucune installation — votre navigateur suffit.'
                    + '</div>'
                    + '<div style="background:#f7faff;border-top:1px solid #e8ecf5;padding:20px 40px;text-align:center;">'
                    + '<p style="margin:0;font-size:12px;color:#a0aec0;">HR Talent Portal · Talan Tunisie · Ne pas répondre à cet email</p>'
                    + '</div></div></div>'
                );
                emails.add(mail);
            }

            slotIndex++;
        }

        try {
            update toUpdate;
            if (!emails.isEmpty()) {
                Messaging.sendEmail(emails);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Erreur planification en lot : ' + e.getMessage());
        }

        return results;
    }

    // ══════════════════════════════════════════
    // MANAGER — Vue décisionnelle
    // ══════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getManagerData() {
        Map<String, Object> result = new Map<String, Object>();

        // Candidats en attente de validation (RH Fit = dernière étape avant décision)
        List<Opportunity> rhFitOpps = [
            SELECT Id, Name, StageName, CloseDate, Account.Name,
                   Description, CreatedDate, Score_Matching__c
            FROM Opportunity
            WHERE RecordType.DeveloperName = 'Application'
            AND StageName IN ('RH Fit', 'Architecture', 'Technique')
            ORDER BY CloseDate ASC
            LIMIT 50
        ];

        // Enrich with Technical_Interview__c data + Lead info
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity o : rhFitOpps) oppIds.add(o.Id);

        Map<Id, Technical_Interview__c> tiByOpp = new Map<Id, Technical_Interview__c>();
        for (Technical_Interview__c ti : [
            SELECT Opportunity__c, Interview_DateTime__c, Duration__c,
                   Meet_Link__c, Score__c, Status__c, Composite_Score__c,
                   Reschedule_Requested__c
            FROM Technical_Interview__c
            WHERE Opportunity__c IN :oppIds
        ]) {
            tiByOpp.put(ti.Opportunity__c, ti);
        }

        Map<Id, Lead> oppLeadMap = new Map<Id, Lead>();
        for (Lead l : [
            SELECT Id, ConvertedOpportunityId, FirstName, LastName, Email,
                   Score_Matching__c, AI_Recommendation__c, AI_Points_Forts__c
            FROM Lead
            WHERE ConvertedOpportunityId IN :oppIds
        ]) {
            oppLeadMap.put(l.ConvertedOpportunityId, l);
        }

        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Opportunity o : rhFitOpps) {
            Lead l = oppLeadMap.get(o.Id);
            Technical_Interview__c ti = tiByOpp.get(o.Id);
            Map<String, Object> row = new Map<String, Object>();
            row.put('Id',            o.Id);
            row.put('Name',          o.Name);
            row.put('StageName',     o.StageName);
            row.put('CloseDate',     o.CloseDate);
            row.put('accountName',   o.Account != null ? o.Account.Name : '—');
            row.put('candidateName', l != null ? ((l.FirstName != null ? l.FirstName : '') + ' ' + (l.LastName != null ? l.LastName : '')).trim() : o.Name);
            row.put('leadEmail',     l != null ? l.Email : '');
            row.put('scoreCV',       l != null ? l.Score_Matching__c : o.Score_Matching__c);
            row.put('aiForts',       l != null ? l.AI_Points_Forts__c : '');
            row.put('aiReco',        l != null ? l.AI_Recommendation__c : '');
            row.put('techScore',     ti != null ? ti.Score__c : null);
            row.put('techComposite', ti != null ? ti.Composite_Score__c : null);
            row.put('techStatus',    ti != null ? ti.Status__c : null);
            row.put('techDateTime',  ti != null ? ti.Interview_DateTime__c : null);
            rows.add(row);
        }

        // Candidats acceptés (Closed Won)
        Integer acceptes = [
            SELECT COUNT() FROM Opportunity
            WHERE RecordType.DeveloperName = 'Application'
            AND StageName = 'Closed Won'
        ];

        // Candidats refusés (Closed Lost)
        Integer refuses = [
            SELECT COUNT() FROM Opportunity
            WHERE RecordType.DeveloperName = 'Application'
            AND StageName = 'Closed Lost'
        ];

        // Total
        Integer total = [
            SELECT COUNT() FROM Opportunity
            WHERE RecordType.DeveloperName = 'Application'
        ];

        result.put('enAttente', rows);
        result.put('totalAcceptes', acceptes);
        result.put('totalRefuses', refuses);
        result.put('totalCandidats', total);
        result.put('tauxAcceptation', total > 0 ? ((Decimal)acceptes / total * 100).setScale(0) : 0);
        return result;
    }

    // ══════════════════════════════════════════
    // RESPONSABLE RH — Vue globale
    // ══════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRHData() {
        Map<String, Object> result = new Map<String, Object>();

        // Leads (phase 1)
        Integer totalLeads = [SELECT COUNT() FROM Lead WHERE LeadSource = 'Talent Portal'];
        Integer leadsConverted = [SELECT COUNT() FROM Lead WHERE LeadSource = 'Talent Portal' AND IsConverted = true];
        Integer leadsRefuses = [SELECT COUNT() FROM Lead WHERE LeadSource = 'Talent Portal' AND Status = 'Condidature Réfusé'];
        Integer leadsEnCours = [SELECT COUNT() FROM Lead WHERE LeadSource = 'Talent Portal' AND IsConverted = false AND Status != 'Condidature Réfusé'];

        // Score moyen IA
        AggregateResult[] scoreAgg = [
            SELECT AVG(Score_Matching__c) avgScore
            FROM Lead
            WHERE LeadSource = 'Talent Portal'
            AND Score_Matching__c != null
        ];
        Decimal avgScore = scoreAgg.isEmpty() || scoreAgg[0].get('avgScore') == null
            ? 0 : ((Decimal)scoreAgg[0].get('avgScore')).setScale(0);

        // Offres actives
        Integer offresActives = [
            SELECT COUNT() FROM Opportunity
            WHERE RecordType.DeveloperName = 'Job_Posting' AND IsClosed = false
        ];

        // Utilisateurs portail actifs
        Integer portalUsers = [
            SELECT COUNT() FROM User
            WHERE Profile.Name = 'Customer Community Login User' AND IsActive = true
        ];

        // Derniers leads
        List<Lead> recentLeads = [
            SELECT Id, FirstName, LastName, Email, Status, Score_Matching__c,
                   IsConverted, CreatedDate, AI_Recommendation__c
            FROM Lead
            WHERE LeadSource = 'Talent Portal'
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        result.put('totalLeads', totalLeads);
        result.put('leadsConverted', leadsConverted);
        result.put('leadsRefuses', leadsRefuses);
        result.put('leadsEnCours', leadsEnCours);
        result.put('avgScore', avgScore);
        result.put('offresActives', offresActives);
        result.put('portalUsers', portalUsers);
        result.put('recentLeads', recentLeads);
        result.put('tauxConversion', totalLeads > 0 ? ((Decimal)leadsConverted / totalLeads * 100).setScale(0) : 0);
        return result;
    }

    // ══════════════════════════════════════════
    // ACTION — Changer stage d'une Opportunité
    //          + email notification automatique
    // ══════════════════════════════════════════

    @AuraEnabled
    public static void updateOpportunityStage(Id oppId, String newStage) {
        try {
            Opportunity opp = [SELECT Id, Name, StageName, AccountId FROM Opportunity WHERE Id = :oppId LIMIT 1];
            String oldStage = opp.StageName;
            opp.StageName = newStage;
            update opp;

            // Trouver l'email du candidat (Lead → OCR → Contact)
            String candidatEmail;
            String prenom = '';

            List<Lead> leads = [
                SELECT Id, FirstName, LastName, Email
                FROM Lead WHERE ConvertedOpportunityId = :oppId LIMIT 1
            ];
            if (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) {
                candidatEmail = leads[0].Email;
                prenom = leads[0].FirstName != null ? leads[0].FirstName : '';
            }
            if (String.isBlank(candidatEmail)) {
                List<OpportunityContactRole> ocrs = [
                    SELECT ContactId, Contact.FirstName, Contact.Email
                    FROM OpportunityContactRole
                    WHERE OpportunityId = :oppId AND Contact.Email != null
                    LIMIT 1
                ];
                if (!ocrs.isEmpty()) {
                    candidatEmail = ocrs[0].Contact.Email;
                    prenom = ocrs[0].Contact.FirstName != null ? ocrs[0].Contact.FirstName : '';
                }
            }
            if (String.isBlank(candidatEmail) && opp.AccountId != null) {
                List<Contact> contacts = [
                    SELECT Id, FirstName, Email
                    FROM Contact WHERE AccountId = :opp.AccountId AND Email != null LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    candidatEmail = contacts[0].Email;
                    prenom = contacts[0].FirstName != null ? contacts[0].FirstName : '';
                }
            }

            if (String.isNotBlank(candidatEmail)) {
                String stageLabel = newStage;
                String stageDesc = '';
                String stageColor = '#2F7D59';
                if (newStage == 'Technique') {
                    stageDesc = 'Vous avez brillamment passé l\'étape Gaming ! Nous souhaitons maintenant vous rencontrer pour un entretien technique.';
                    stageColor = '#3b82f6';
                } else if (newStage == 'Architecture') {
                    stageDesc = 'Félicitations pour l\'entretien technique ! La prochaine étape est une mise en situation architecture.';
                    stageColor = '#8b5cf6';
                } else if (newStage == 'RH Fit') {
                    stageDesc = 'Bravo ! Vous êtes dans la dernière étape. Un entretien RH pour valider l\'adéquation avec notre culture.';
                    stageColor = '#ec4899';
                } else if (newStage == 'Closed Won') {
                    stageDesc = 'Toutes nos félicitations ! Votre candidature a été retenue. Notre équipe RH vous contactera très prochainement.';
                    stageColor = '#22c55e';
                } else if (newStage == 'Closed Lost') {
                    stageDesc = 'Après examen attentif de votre dossier, nous ne sommes malheureusement pas en mesure de retenir votre candidature. Nous vous souhaitons le meilleur pour la suite.';
                    stageColor = '#ef4444';
                }

                if (String.isNotBlank(stageDesc)) {
                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(new String[]{ candidatEmail });
                    mail.setSubject('Talan Tunisie — Mise à jour de votre candidature');
                    mail.setHtmlBody(
                        '<div style="font-family:Inter,Arial,sans-serif;max-width:600px;margin:0 auto;">'
                        + '<div style="background:linear-gradient(135deg,' + stageColor + ',#1a4d2e);padding:30px 40px;border-radius:16px 16px 0 0;">'
                        + '<h1 style="color:#fff;margin:0;font-size:22px;">Mise à jour de votre candidature</h1>'
                        + '</div>'
                        + '<div style="background:#fff;padding:30px 40px;border:1px solid #e5e7eb;border-top:none;">'
                        + '<p style="font-size:15px;color:#374151;">Bonjour ' + prenom + ',</p>'
                        + '<div style="background:' + stageColor + '15;border-left:4px solid ' + stageColor + ';padding:16px 20px;border-radius:0 8px 8px 0;margin:20px 0;">'
                        + '<p style="margin:0;font-size:14px;font-weight:700;color:' + stageColor + ';">Nouvelle étape : ' + stageLabel + '</p>'
                        + '</div>'
                        + '<p style="font-size:14px;color:#4b5563;line-height:1.7;">' + stageDesc + '</p>'
                        + '<p style="font-size:13px;color:#9ca3af;margin-top:20px;">Cordialement,<br/>L\'équipe Talan Talent Intelligence</p>'
                        + '</div>'
                        + '<div style="background:#f9fafb;padding:16px;text-align:center;border-radius:0 0 16px 16px;border:1px solid #e5e7eb;border-top:none;">'
                        + '<p style="margin:0;font-size:11px;color:#9ca3af;">Talan Tunisie · HR Talent Portal</p>'
                        + '</div></div>'
                    );
                    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Erreur mise à jour : ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════
    // OFFRES D'EMPLOI — CRUD
    // ══════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getJobPostings() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        Id currentUserId = UserInfo.getUserId();

        List<Opportunity> jobs = [
            SELECT Id, Name, StageName, CloseDate, CreatedDate,
                   Localisation__c, Type_de_Contrat__c, Salaire_Propos__c,
                   Description_Poste__c, Departement__c, IsClosed
            FROM Opportunity
            WHERE RecordType.DeveloperName = 'Job_Posting'
            AND OwnerId = :currentUserId
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        // Count applications per job posting via Application Opportunities
        Set<Id> jobIds = new Set<Id>();
        for (Opportunity job : jobs) jobIds.add(job.Id);

        // Get all converted leads that reference these job IDs
        Map<Id, Integer> appCountMap = new Map<Id, Integer>();
        for (Id jId : jobIds) appCountMap.put(jId, 0);

        for (Lead l : [
            SELECT Id, Description, ConvertedOpportunityId
            FROM Lead
            WHERE IsConverted = true
            LIMIT 500
        ]) {
            if (l.Description == null) continue;
            for (Id jId : jobIds) {
                if (l.Description.contains('JOB_ID:' + jId)) {
                    appCountMap.put(jId, appCountMap.get(jId) + 1);
                    break;
                }
            }
        }

        for (Opportunity job : jobs) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('Id',          job.Id);
            row.put('Name',        job.Name);
            row.put('Stage',       job.StageName);
            row.put('CloseDate',   job.CloseDate);
            row.put('CreatedDate', job.CreatedDate);
            row.put('Location',    job.Localisation__c);
            row.put('Contract',    job.Type_de_Contrat__c);
            row.put('Salary',      job.Salaire_Propos__c);
            row.put('Description', job.Description_Poste__c);
            row.put('Department',  job.Departement__c);
            row.put('IsClosed',    job.IsClosed);

            // Nombre de candidatures liées
            row.put('AppCount', appCountMap.containsKey(job.Id) ? appCountMap.get(job.Id) : 0);
            result.add(row);
        }
        return result;
    }

    @AuraEnabled
    public static Id createJobPosting(String title, String department, String location,
                                       String contractType, Decimal salary, String description,
                                       Date closeDate) {
        try {
            Id rtId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName()
                          .get('Job_Posting').getRecordTypeId();
            Opportunity job = new Opportunity();
            job.RecordTypeId       = rtId;
            job.Name               = title;
            job.StageName          = 'Prospecting';
            job.CloseDate          = closeDate;
            job.Departement__c     = department;
            job.Localisation__c    = location;
            job.Type_de_Contrat__c = contractType;
            job.Salaire_Propos__c  = salary;
            job.Description_Poste__c = description;
            insert job;
            return job.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur création offre : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void toggleJobPosting(Id jobId, Boolean close) {
        try {
            Opportunity job = [SELECT Id, StageName FROM Opportunity WHERE Id = :jobId LIMIT 1];
            job.StageName = close ? 'Closed Won' : 'Prospecting';
            update job;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur : ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════
    // IA — Relancer le scoring NLP
    // ══════════════════════════════════════════

    @AuraEnabled
    public static Map<String, Object> rescoreCandidat(Id oppId) {
        try {
            List<Lead> leads = [
                SELECT Id, FirstName, LastName, Email, Score_Matching__c,
                       AI_Recommendation__c, AI_Points_Forts__c
                FROM Lead WHERE ConvertedOpportunityId = :oppId LIMIT 1
            ];
            if (leads.isEmpty()) {
                throw new AuraHandledException('Lead non trouvé pour cette candidature.');
            }
            Lead l = leads[0];

            // Relancer le scoring
            CVScoringService.scoreCVForLeadNow(l.Id);

            // Recharger les données mises à jour
            Lead updated = [
                SELECT Id, Score_Matching__c, AI_Recommendation__c,
                       AI_Points_Forts__c, AI_Points_Faibles__c
                FROM Lead WHERE Id = :l.Id LIMIT 1
            ];

            Map<String, Object> result = new Map<String, Object>();
            result.put('score', updated.Score_Matching__c);
            result.put('recommendation', updated.AI_Recommendation__c);
            result.put('pointsForts', updated.AI_Points_Forts__c);
            return result;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur re-scoring : ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════
    // IA — Générer description d'offre d'emploi
    // ══════════════════════════════════════════

    @AuraEnabled
    public static String generateJobDescription(String title, String department, String location,
                                                 String contractType, Decimal salary, String rawDescription) {
        try {
            List<AI_Configuration__c> configs = [SELECT Groq_API_Key__c FROM AI_Configuration__c LIMIT 1];
            if (configs.isEmpty() || String.isBlank(configs[0].Groq_API_Key__c)) {
                throw new AuraHandledException('Clé API Groq non configurée.');
            }
            String apiKey = configs[0].Groq_API_Key__c;

            String contextInfo = 'Titre du poste : ' + (title != null ? title : '') + '\n'
                + 'Département : ' + (department != null ? department : '') + '\n'
                + 'Localisation : ' + (location != null ? location : '') + '\n'
                + 'Type de contrat : ' + (contractType != null ? contractType : '') + '\n'
                + (salary != null ? 'Salaire : ' + salary + ' TND\n' : '')
                + 'Description brute du recruteur :\n' + (rawDescription != null ? rawDescription : '');

            String systemPrompt =
                'Tu es un expert en rédaction RH pour Talan Tunisie, une ESN leader en IT et consulting. '
                + 'À partir des informations fournies par le recruteur (qui peuvent contenir des fautes, être incomplètes ou en style brouillon), '
                + 'génère une description d\'offre d\'emploi professionnelle, attractive et structurée en français. '
                + 'La description doit inclure :\n'
                + '1. Un paragraphe d\'introduction sur le poste et Talan\n'
                + '2. Les missions principales (liste à puces avec •)\n'
                + '3. Le profil recherché (compétences, expérience)\n'
                + '4. Les avantages (environnement Talan)\n'
                + 'Corrige toutes les fautes d\'orthographe et de grammaire. '
                + 'Garde un ton professionnel mais dynamique. '
                + 'Réponds UNIQUEMENT avec le texte de la description, sans balises HTML ni markdown.';

            Map<String, Object> body = new Map<String, Object>{
                'model'       => 'llama-3.3-70b-versatile',
                'temperature' => 0.7,
                'max_tokens'  => 1000,
                'messages'    => new List<Map<String, String>>{
                    new Map<String, String>{ 'role' => 'system', 'content' => systemPrompt },
                    new Map<String, String>{ 'role' => 'user',   'content' => contextInfo  }
                }
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.groq.com/openai/v1/chat/completions');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + apiKey);
            req.setTimeout(30000);
            req.setBody(JSON.serialize(body));

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                throw new AuraHandledException('Erreur API IA (' + res.getStatusCode() + ')');
            }

            Map<String, Object> resp    = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object>        choices = (List<Object>) resp.get('choices');
            Map<String, Object> msg     = (Map<String, Object>) ((Map<String, Object>) choices[0]).get('message');
            String content = ((String) msg.get('content')).trim();

            return content;
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur génération IA : ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════
    // ACTION — Planifier l'entretien technique
    // ══════════════════════════════════════════

    @AuraEnabled
    public static void scheduleTechnicalInterview(
        Id oppId,
        String interviewDateTime,
        String duration,
        String meetUrl
    ) {
        try {
            DateTime parsedDt = DateTime.valueOf(interviewDateTime.replace('T', ' ').length() == 16
                ? interviewDateTime.replace('T', ' ') + ':00'
                : interviewDateTime.replace('T', ' '));

            Opportunity opp = [
                SELECT Id, Name, StageName, AccountId
                FROM Opportunity WHERE Id = :oppId LIMIT 1
            ];

            String exerciseLink = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/entretientechnique1?id=' + oppId;

            // Auto-generate Jitsi link if no custom meet URL provided
            String videoLink;
            if (String.isNotBlank(meetUrl)) {
                videoLink = meetUrl.trim();
            } else {
                String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
                String jitsiRoom = 'talan-tech-' + hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' + hex.substring(12, 16);
                videoLink = 'https://meet.jit.si/' + jitsiRoom;
            }

            // Upsert Technical_Interview__c record
            List<Technical_Interview__c> tiList = [
                SELECT Id FROM Technical_Interview__c WHERE Opportunity__c = :oppId LIMIT 1
            ];
            Technical_Interview__c ti = tiList.isEmpty()
                ? new Technical_Interview__c(Opportunity__c = oppId)
                : tiList[0];
            ti.Interview_DateTime__c = parsedDt;
            ti.Duration__c           = duration;
            ti.Meet_Link__c          = videoLink != null ? videoLink : exerciseLink;
            ti.Status__c             = 'Scheduled';
            ti.Reschedule_Requested__c = false;
            upsert ti;

            // Find candidate email
            String candidatEmail;
            String prenom = '';
            String nom = '';

            List<Lead> leads = [
                SELECT Id, FirstName, LastName, Email, Description
                FROM Lead WHERE ConvertedOpportunityId = :oppId LIMIT 1
            ];
            if (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) {
                candidatEmail = leads[0].Email;
                prenom = leads[0].FirstName != null ? leads[0].FirstName : '';
                nom    = leads[0].LastName  != null ? leads[0].LastName  : '';
            }

            if (String.isBlank(candidatEmail)) {
                List<OpportunityContactRole> ocrs = [
                    SELECT Contact.FirstName, Contact.LastName, Contact.Email
                    FROM OpportunityContactRole
                    WHERE OpportunityId = :oppId AND Contact.Email != null LIMIT 1
                ];
                if (!ocrs.isEmpty()) {
                    candidatEmail = ocrs[0].Contact.Email;
                    prenom = ocrs[0].Contact.FirstName != null ? ocrs[0].Contact.FirstName : '';
                    nom    = ocrs[0].Contact.LastName  != null ? ocrs[0].Contact.LastName  : '';
                }
            }

            if (String.isBlank(candidatEmail) && opp.AccountId != null) {
                List<Contact> contacts = [
                    SELECT FirstName, LastName, Email
                    FROM Contact WHERE AccountId = :opp.AccountId AND Email != null LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    candidatEmail = contacts[0].Email;
                    prenom = contacts[0].FirstName != null ? contacts[0].FirstName : '';
                    nom    = contacts[0].LastName  != null ? contacts[0].LastName  : '';
                }
            }

            String dateLabel = parsedDt.format('dd/MM/yyyy \'à\' HH:mm');
            String dureeLabel = duration == '30'  ? '30 minutes'
                              : duration == '45'  ? '45 minutes'
                              : duration == '60'  ? '1 heure'
                              : duration == '90'  ? '1h30'
                              : duration + ' min';

            // ── Build Meet section (only if video link provided)
            String meetSection = '';
            if (videoLink != null) {
                meetSection = '<div style="text-align:center;margin:0 0 20px;">'
                    + '<a href="' + videoLink + '" '
                    + 'style="display:inline-block;background:linear-gradient(135deg,#10b981,#059669);color:#ffffff;'
                    + 'font-size:16px;font-weight:700;padding:14px 36px;border-radius:50px;text-decoration:none;">'
                    + '🎥 Rejoindre la visioconférence'
                    + '</a>'
                    + '<p style="font-size:12px;color:#718096;margin:8px 0 0;">Un recruteur vous attend en visio pendant l\'entretien.</p>'
                    + '</div>';
            }

            // ── Email to candidate ──
            if (String.isNotBlank(candidatEmail)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ candidatEmail });
                mail.setSubject('💻 Invitation — Entretien Technique HR Talent Portal · Talan Tunisie');
                mail.setHtmlBody(
                    '<div style="font-family:Inter,Arial,sans-serif;background:#f4f6f9;padding:40px 0;">'
                    + '<div style="max-width:580px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.10);">'
                    + '<div style="background:linear-gradient(135deg,#1e40af 0%,#3b82f6 100%);padding:40px 40px 32px;">'
                    + '<h1 style="margin:0;color:#fff;font-size:26px;font-weight:700;">💻 Entretien Technique Planifié</h1>'
                    + '<p style="margin:8px 0 0;color:rgba(255,255,255,0.7);font-size:15px;">HR Talent Portal · Talan Tunisie</p>'
                    + '</div>'
                    + '<div style="padding:36px 40px;">'
                    + '<p style="font-size:16px;color:#2d3748;margin:0 0 24px;">Bonjour <strong>' + prenom + ' ' + nom + '</strong>,</p>'
                    + '<p style="font-size:15px;color:#4a5568;line-height:1.7;margin:0 0 28px;">'
                    + 'Nous vous confirmons la planification de votre <strong>entretien technique</strong> '
                    + 'dans le cadre de votre candidature chez <strong>Talan Tunisie</strong>. '
                    + 'Vous devrez résoudre des exercices de programmation et d\'architecture évalués par l\'IA.'
                    + (videoLink != null ? ' Un recruteur vous accompagnera en <strong>visioconférence</strong>.' : '')
                    + '</p>'
                    + '<div style="background:#eff6ff;border-left:4px solid #3b82f6;border-radius:8px;padding:20px 24px;margin:0 0 28px;">'
                    + '<table style="width:100%;border-collapse:collapse;">'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">📅 Date &amp; Heure</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dateLabel + '</td></tr>'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">⏱ Durée</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dureeLabel + '</td></tr>'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">🖥 Format</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">5 exercices techniques (code, architecture, debug)</td></tr>'
                    + (videoLink != null ? '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">🎥 Visio</td>'
                        + '<td style="color:#1a202c;font-size:15px;font-weight:600;">Avec recruteur en direct</td></tr>' : '')
                    + '</table>'
                    + '</div>'
                    + meetSection
                    + '<div style="text-align:center;margin:0 0 28px;">'
                    + '<a href="' + exerciseLink + '" '
                    + 'style="display:inline-block;background:linear-gradient(135deg,#3b82f6,#1d4ed8);color:#ffffff;'
                    + 'font-size:16px;font-weight:700;padding:14px 36px;border-radius:50px;text-decoration:none;">'
                    + '💻 Accéder aux exercices techniques'
                    + '</a>'
                    + '</div>'
                    + '<p style="font-size:13px;color:#718096;line-height:1.6;margin:0;">'
                    + '<strong>Instructions :</strong> 5 exercices de programmation adaptés au poste, '
                    + 'évaluation IA en temps réel, bonus de rapidité. Votre navigateur suffit.'
                    + '</p>'
                    + '</div>'
                    + '<div style="background:#eff6ff;border-top:1px solid #dbeafe;padding:20px 40px;text-align:center;">'
                    + '<p style="margin:0;font-size:12px;color:#94a3b8;">HR Talent Portal · Talan Tunisie · Ne pas répondre à cet email</p>'
                    + '</div>'
                    + '</div></div>'
                );

                List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{ mail };

                // ── Email to manager (copy) ──
                // Find the Job Posting owner (manager/tech lead) via Lead.Description JOB_ID
                Id jobPostingId = null;
                if (!leads.isEmpty() && leads[0].Description != null) {
                    for (String line : leads[0].Description.split('\n')) {
                        if (line.startsWith('JOB_ID:')) {
                            try {
                                jobPostingId = (Id) line.replace('JOB_ID:', '').trim();
                            } catch (Exception ex) {}
                            break;
                        }
                    }
                }
                if (jobPostingId != null) {
                    List<Opportunity> jobList = [
                        SELECT OwnerId, Owner.Email, Owner.FirstName, Owner.LastName, Name
                        FROM Opportunity WHERE Id = :jobPostingId LIMIT 1
                    ];
                    if (!jobList.isEmpty() && String.isNotBlank(jobList[0].Owner.Email)) {
                        Opportunity job = jobList[0];
                        String mgrEmail = job.Owner.Email;
                        // Don't send to manager if same as current user (the recruiter)
                        if (mgrEmail != UserInfo.getUserEmail()) {
                            Messaging.SingleEmailMessage mgrMail = new Messaging.SingleEmailMessage();
                            mgrMail.setToAddresses(new List<String>{ mgrEmail });
                            mgrMail.setSubject('📋 Entretien technique planifié — ' + prenom + ' ' + nom + ' · ' + job.Name);
                            mgrMail.setHtmlBody(
                                '<div style="font-family:Inter,Arial,sans-serif;background:#f4f6f9;padding:40px 0;">'
                                + '<div style="max-width:580px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.10);">'
                                + '<div style="background:linear-gradient(135deg,#7c3aed 0%,#a78bfa 100%);padding:40px 40px 32px;">'
                                + '<h1 style="margin:0;color:#fff;font-size:24px;font-weight:700;">📋 Entretien Technique — Notification Manager</h1>'
                                + '<p style="margin:8px 0 0;color:rgba(255,255,255,0.7);font-size:15px;">HR Talent Portal · Talan Tunisie</p>'
                                + '</div>'
                                + '<div style="padding:36px 40px;">'
                                + '<p style="font-size:16px;color:#2d3748;margin:0 0 24px;">Bonjour <strong>'
                                + (job.Owner.FirstName != null ? job.Owner.FirstName : '') + '</strong>,</p>'
                                + '<p style="font-size:15px;color:#4a5568;line-height:1.7;margin:0 0 28px;">'
                                + 'Un entretien technique a été planifié pour le candidat <strong>' + prenom + ' ' + nom + '</strong> '
                                + 'pour le poste <strong>' + job.Name + '</strong>. '
                                + 'Vous pouvez rejoindre la visioconférence pour observer l\'entretien.'
                                + '</p>'
                                + '<div style="background:#f5f3ff;border-left:4px solid #7c3aed;border-radius:8px;padding:20px 24px;margin:0 0 28px;">'
                                + '<table style="width:100%;border-collapse:collapse;">'
                                + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">👤 Candidat</td>'
                                + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + prenom + ' ' + nom + '</td></tr>'
                                + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">📅 Date</td>'
                                + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dateLabel + '</td></tr>'
                                + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">⏱ Durée</td>'
                                + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dureeLabel + '</td></tr>'
                                + '</table>'
                                + '</div>'
                                + (videoLink != null ?
                                    '<div style="text-align:center;margin:0 0 20px;">'
                                    + '<a href="' + videoLink + '" '
                                    + 'style="display:inline-block;background:linear-gradient(135deg,#10b981,#059669);color:#ffffff;'
                                    + 'font-size:16px;font-weight:700;padding:14px 36px;border-radius:50px;text-decoration:none;">'
                                    + '🎥 Rejoindre la visioconférence'
                                    + '</a></div>' : '')
                                + '<p style="font-size:13px;color:#718096;line-height:1.6;margin:0;">'
                                + 'Les résultats seront disponibles dans votre dashboard après l\'entretien.'
                                + '</p>'
                                + '</div>'
                                + '<div style="background:#f5f3ff;border-top:1px solid #ddd6fe;padding:20px 40px;text-align:center;">'
                                + '<p style="margin:0;font-size:12px;color:#94a3b8;">HR Talent Portal · Talan Tunisie</p>'
                                + '</div>'
                                + '</div></div>'
                            );
                            emails.add(mgrMail);
                        }
                    }
                }

                Messaging.sendEmail(emails);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Erreur planification entretien technique : ' + e.getMessage());
        }
    }

    // ══════════════════════════════════════════
    // ACTION — Planifier l'entretien Architecture
    //          avec Jitsi room auto-générée (UUID)
    // ══════════════════════════════════════════

    @AuraEnabled
    public static Map<String, Object> scheduleArchitectureInterview(
        Id oppId,
        String interviewDateTime,
        String duration
    ) {
        try {
            DateTime parsedDt = DateTime.valueOf(interviewDateTime.replace('T', ' ').length() == 16
                ? interviewDateTime.replace('T', ' ') + ':00'
                : interviewDateTime.replace('T', ' '));

            Opportunity opp = [
                SELECT Id, Name, StageName, AccountId
                FROM Opportunity WHERE Id = :oppId LIMIT 1
            ];

            // Auto-generate Jitsi room with UUID
            String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
            String jitsiRoom = 'talan-arch-' + hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' + hex.substring(12, 16) + '-' + hex.substring(16, 20);
            String jitsiUrl = 'https://meet.jit.si/' + jitsiRoom;

            String portalLink = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/architectureinterview?id=' + oppId;

            // Upsert Architecture_Interview__c record
            List<Architecture_Interview__c> aiList = [
                SELECT Id FROM Architecture_Interview__c WHERE Opportunity__c = :oppId LIMIT 1
            ];
            Architecture_Interview__c ai = aiList.isEmpty()
                ? new Architecture_Interview__c(Opportunity__c = oppId)
                : aiList[0];
            ai.Interview_DateTime__c   = parsedDt;
            ai.Duration__c             = duration;
            ai.Jitsi_Room__c           = jitsiRoom;
            ai.Meet_Link__c            = jitsiUrl;
            ai.Status__c               = 'Scheduled';
            ai.Reschedule_Requested__c = false;
            upsert ai;

            // Find candidate email (3-level fallback)
            String candidatEmail;
            String prenom = '';
            String nom = '';

            List<Lead> leads = [
                SELECT Id, FirstName, LastName, Email, Description
                FROM Lead WHERE ConvertedOpportunityId = :oppId LIMIT 1
            ];
            if (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) {
                candidatEmail = leads[0].Email;
                prenom = leads[0].FirstName != null ? leads[0].FirstName : '';
                nom    = leads[0].LastName  != null ? leads[0].LastName  : '';
            }
            if (String.isBlank(candidatEmail)) {
                List<OpportunityContactRole> ocrs = [
                    SELECT Contact.FirstName, Contact.LastName, Contact.Email
                    FROM OpportunityContactRole
                    WHERE OpportunityId = :oppId AND Contact.Email != null LIMIT 1
                ];
                if (!ocrs.isEmpty()) {
                    candidatEmail = ocrs[0].Contact.Email;
                    prenom = ocrs[0].Contact.FirstName != null ? ocrs[0].Contact.FirstName : '';
                    nom    = ocrs[0].Contact.LastName  != null ? ocrs[0].Contact.LastName  : '';
                }
            }
            if (String.isBlank(candidatEmail) && opp.AccountId != null) {
                List<Contact> contacts = [
                    SELECT FirstName, LastName, Email
                    FROM Contact WHERE AccountId = :opp.AccountId AND Email != null LIMIT 1
                ];
                if (!contacts.isEmpty()) {
                    candidatEmail = contacts[0].Email;
                    prenom = contacts[0].FirstName != null ? contacts[0].FirstName : '';
                    nom    = contacts[0].LastName  != null ? contacts[0].LastName  : '';
                }
            }

            String dateLabel = parsedDt.format('dd/MM/yyyy \'à\' HH:mm');
            String dureeLabel = duration == '30'  ? '30 minutes'
                              : duration == '45'  ? '45 minutes'
                              : duration == '60'  ? '1 heure'
                              : duration == '90'  ? '1h30'
                              : duration + ' min';

            if (String.isNotBlank(candidatEmail)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ candidatEmail });
                mail.setSubject('🏗️ Invitation — Entretien Architecture HR Talent Portal · Talan Tunisie');
                mail.setHtmlBody(
                    '<div style="font-family:Inter,Arial,sans-serif;background:#f4f6f9;padding:40px 0;">'
                    + '<div style="max-width:580px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.10);">'
                    + '<div style="background:linear-gradient(135deg,#7c3aed 0%,#a78bfa 100%);padding:40px 40px 32px;">'
                    + '<h1 style="margin:0;color:#fff;font-size:26px;font-weight:700;">🏗️ Entretien Architecture Planifié</h1>'
                    + '<p style="margin:8px 0 0;color:rgba(255,255,255,0.7);font-size:15px;">HR Talent Portal · Talan Tunisie</p>'
                    + '</div>'
                    + '<div style="padding:36px 40px;">'
                    + '<p style="font-size:16px;color:#2d3748;margin:0 0 24px;">Bonjour <strong>' + prenom + ' ' + nom + '</strong>,</p>'
                    + '<p style="font-size:15px;color:#4a5568;line-height:1.7;margin:0 0 28px;">'
                    + 'Nous vous confirmons la planification de votre <strong>entretien architecture</strong> '
                    + 'dans le cadre de votre candidature chez <strong>Talan Tunisie</strong>. '
                    + 'Un recruteur vous posera des questions sur la conception logicielle et l\'architecture technique en visioconférence.'
                    + '</p>'
                    + '<div style="background:#f5f3ff;border-left:4px solid #7c3aed;border-radius:8px;padding:20px 24px;margin:0 0 28px;">'
                    + '<table style="width:100%;border-collapse:collapse;">'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">📅 Date &amp; Heure</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dateLabel + '</td></tr>'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">⏱ Durée</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">' + dureeLabel + '</td></tr>'
                    + '<tr><td style="color:#718096;font-size:13px;padding:6px 0;">🖥 Format</td>'
                    + '<td style="color:#1a202c;font-size:15px;font-weight:600;">Visioconférence Jitsi + Enregistrement IA</td></tr>'
                    + '</table>'
                    + '</div>'
                    + '<div style="text-align:center;margin:0 0 20px;">'
                    + '<a href="' + portalLink + '" '
                    + 'style="display:inline-block;background:linear-gradient(135deg,#7c3aed,#5b21b6);color:#ffffff;'
                    + 'font-size:16px;font-weight:700;padding:14px 36px;border-radius:50px;text-decoration:none;">'
                    + '🏗️ Accéder à l\'entretien architecture'
                    + '</a>'
                    + '</div>'
                    + '<div style="background:#fffbeb;border:1px solid #fbbf24;border-radius:8px;padding:12px 16px;margin:0 0 20px;">'
                    + '<p style="margin:0;font-size:13px;color:#92400e;">⚠️ <strong>Important :</strong> Cet entretien sera enregistré et analysé par l\'intelligence artificielle. '
                    + 'Vous devrez donner votre consentement avant le début.</p>'
                    + '</div>'
                    + '<p style="font-size:13px;color:#718096;line-height:1.6;margin:0;">'
                    + '<strong>Conseil :</strong> Préparez-vous à discuter de patterns de conception, '
                    + 'd\'architecture microservices, de choix techniques et de scalabilité. Votre navigateur suffit.'
                    + '</p>'
                    + '</div>'
                    + '<div style="background:#f5f3ff;border-top:1px solid #ddd6fe;padding:20px 40px;text-align:center;">'
                    + '<p style="margin:0;font-size:12px;color:#94a3b8;">HR Talent Portal · Talan Tunisie · Ne pas répondre à cet email</p>'
                    + '</div>'
                    + '</div></div>'
                );

                List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>{ mail };

                // Notify manager
                Id jobPostingId = null;
                if (!leads.isEmpty() && leads[0].Description != null) {
                    for (String line : leads[0].Description.split('\n')) {
                        if (line.startsWith('JOB_ID:')) {
                            try { jobPostingId = (Id) line.replace('JOB_ID:', '').trim(); }
                            catch (Exception ex) {}
                            break;
                        }
                    }
                }
                if (jobPostingId != null) {
                    List<Opportunity> jobList = [
                        SELECT OwnerId, Owner.Email, Owner.FirstName, Name
                        FROM Opportunity WHERE Id = :jobPostingId LIMIT 1
                    ];
                    if (!jobList.isEmpty() && String.isNotBlank(jobList[0].Owner.Email)
                        && jobList[0].Owner.Email != UserInfo.getUserEmail()) {
                        Messaging.SingleEmailMessage mgrMail = new Messaging.SingleEmailMessage();
                        mgrMail.setToAddresses(new List<String>{ jobList[0].Owner.Email });
                        mgrMail.setSubject('🏗️ Entretien Architecture planifié — ' + prenom + ' ' + nom + ' · ' + jobList[0].Name);
                        mgrMail.setHtmlBody(
                            '<div style="font-family:Inter,Arial,sans-serif;background:#f4f6f9;padding:40px 0;">'
                            + '<div style="max-width:580px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,.10);">'
                            + '<div style="background:linear-gradient(135deg,#7c3aed,#a78bfa);padding:40px 40px 32px;">'
                            + '<h1 style="margin:0;color:#fff;font-size:22px;">🏗️ Entretien Architecture — Notification</h1>'
                            + '<p style="margin:8px 0 0;color:rgba(255,255,255,0.7);font-size:15px;">HR Talent Portal · Talan Tunisie</p>'
                            + '</div>'
                            + '<div style="padding:36px 40px;">'
                            + '<p style="font-size:15px;color:#4a5568;line-height:1.7;">'
                            + 'Un entretien architecture a été planifié pour <strong>' + prenom + ' ' + nom + '</strong> '
                            + 'pour le poste <strong>' + jobList[0].Name + '</strong>.</p>'
                            + '<div style="background:#f5f3ff;border-left:4px solid #7c3aed;border-radius:8px;padding:16px 20px;margin:20px 0;">'
                            + '<p style="margin:0 0 4px;font-size:13px;color:#4a5568;">📅 ' + dateLabel + '</p>'
                            + '<p style="margin:0;font-size:13px;color:#4a5568;">⏱ ' + dureeLabel + '</p>'
                            + '</div>'
                            + '<div style="text-align:center;margin:20px 0;">'
                            + '<a href="' + jitsiUrl + '" '
                            + 'style="display:inline-block;padding:12px 32px;background:linear-gradient(135deg,#10b981,#059669);color:#fff;text-decoration:none;border-radius:8px;font-weight:bold;">'
                            + '🎥 Rejoindre la visio Jitsi</a>'
                            + '</div>'
                            + '<p style="font-size:13px;color:#718096;">Les résultats IA seront disponibles dans votre dashboard après l\'entretien.</p>'
                            + '</div>'
                            + '<div style="text-align:center;padding:16px;font-size:11px;color:#94a3b8;">HR Talent Portal · Talan Tunisie</div>'
                            + '</div></div>'
                        );
                        emails.add(mgrMail);
                    }
                }

                Messaging.sendEmail(emails);
            }

            // Return Jitsi info for display
            Map<String, Object> result = new Map<String, Object>();
            result.put('jitsiRoom', jitsiRoom);
            result.put('jitsiUrl', jitsiUrl);
            result.put('success', true);
            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Erreur planification entretien architecture : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> scheduleRHFitInterview(
        Id oppId,
        String interviewDateTime,
        String duration
    ) {
        try {
            DateTime parsedDt = DateTime.valueOf(interviewDateTime.replace('T', ' ').length() == 16
                ? interviewDateTime.replace('T', ' ') + ':00'
                : interviewDateTime.replace('T', ' '));

            Opportunity opp = [
                SELECT Id, Name, StageName, AccountId, OwnerId, Owner.Email
                FROM Opportunity
                WHERE Id = :oppId
                LIMIT 1
            ];

            String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
            String jitsiRoom = 'talan-rhfit-' + hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' + hex.substring(12, 16) + '-' + hex.substring(16, 20);
            String jitsiUrl = 'https://meet.jit.si/' + jitsiRoom;
            String portalLink = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/rhfitinterview?id=' + oppId;

            List<RH_Fit_Interview__c> listRec = [
                SELECT Id
                FROM RH_Fit_Interview__c
                WHERE Opportunity__c = :oppId
                LIMIT 1
            ];
            RH_Fit_Interview__c rec = listRec.isEmpty()
                ? new RH_Fit_Interview__c(Opportunity__c = oppId)
                : listRec[0];

            rec.Interview_DateTime__c = parsedDt;
            rec.Duration__c = duration;
            rec.Jitsi_Room__c = jitsiRoom;
            rec.Meet_Link__c = jitsiUrl;
            rec.Status__c = 'Scheduled';
            rec.Reschedule_Requested__c = false;
            upsert rec;

            String candidatEmail = '';
            String prenom = '';
            String nom = '';
            List<Lead> leads = [
                SELECT Id, FirstName, LastName, Email, Description
                FROM Lead
                WHERE ConvertedOpportunityId = :oppId
                LIMIT 1
            ];
            if (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) {
                candidatEmail = leads[0].Email;
                prenom = leads[0].FirstName != null ? leads[0].FirstName : '';
                nom = leads[0].LastName != null ? leads[0].LastName : '';
            }
            String candidateDisplayName = (prenom + ' ' + nom).trim();
            if (String.isBlank(candidateDisplayName)) {
                candidateDisplayName = String.isNotBlank(opp.Name) ? opp.Name : 'Candidat';
            }

            String dateLabel = parsedDt.format('dd/MM/yyyy \'a\' HH:mm');
            String dureeLabel = duration == '30' ? '30 minutes'
                : duration == '45' ? '45 minutes'
                : duration == '60' ? '1 heure'
                : duration == '90' ? '1h30'
                : duration + ' min';
            String recruiterConsoleLink = URL.getOrgDomainUrl().toExternalForm() + '/lightning/n/Recruteur_Dashboard';

            if (String.isNotBlank(candidatEmail)) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{ candidatEmail });
                mail.setSubject('Invitation - Entretien RH Fit - Talan Tunisie');
                mail.setHtmlBody(
                    '<div style="font-family:Inter,Arial,sans-serif;max-width:620px;margin:0 auto;">' +
                    '<div style="background:linear-gradient(135deg,#0f766e,#14b8a6);padding:26px 30px;border-radius:14px 14px 0 0;">' +
                    '<h1 style="color:#fff;margin:0;font-size:22px;">Entretien RH Fit planifie</h1>' +
                    '<p style="color:rgba(255,255,255,0.8);margin:8px 0 0;">HR Talent Portal - Talan Tunisie</p>' +
                    '</div>' +
                    '<div style="background:#fff;padding:26px 30px;border:1px solid #e5e7eb;border-top:none;">' +
                    '<p style="margin:0 0 14px;font-size:15px;color:#334155;">Bonjour <strong>' + prenom + ' ' + nom + '</strong>,</p>' +
                    '<p style="margin:0 0 14px;font-size:14px;color:#475569;line-height:1.7;">Votre entretien RH Fit est planifie. Le recruteur animera l entretien et vous posera les questions en direct.</p>' +
                    '<div style="background:#f0fdfa;border:1px solid #99f6e4;border-radius:10px;padding:12px 14px;margin-bottom:16px;">' +
                    '<p style="margin:0 0 6px;font-size:13px;color:#0f766e;"><strong>Date:</strong> ' + dateLabel + '</p>' +
                    '<p style="margin:0 0 6px;font-size:13px;color:#0f766e;"><strong>Duree:</strong> ' + dureeLabel + '</p>' +
                    '<p style="margin:0;font-size:13px;color:#0f766e;"><strong>Format:</strong> Entretien RH Fit via votre espace candidat</p>' +
                    '</div>' +
                    '<div style="text-align:center;margin:18px 0;">' +
                    '<a href="' + portalLink + '" style="display:inline-block;padding:11px 28px;background:#0f766e;color:#fff;text-decoration:none;border-radius:8px;font-weight:700;">Acceder a l entretien RH Fit</a>' +
                    '</div>' +
                    '<p style="margin:0;font-size:12px;color:#94a3b8;">Depuis cette page, vous pourrez rejoindre Meet puis suivre les etapes de l entretien.</p>' +
                    '</div>' +
                    '</div>'
                );
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            }

            Set<String> recruiterEmails = new Set<String>();
            if (String.isNotBlank(opp.Owner != null ? opp.Owner.Email : null)) {
                recruiterEmails.add(opp.Owner.Email);
            }
            if (String.isNotBlank(UserInfo.getUserEmail())) {
                recruiterEmails.add(UserInfo.getUserEmail());
            }
            recruiterEmails.remove(candidatEmail);

            if (!recruiterEmails.isEmpty()) {
                Messaging.SingleEmailMessage recruiterMail = new Messaging.SingleEmailMessage();
                recruiterMail.setToAddresses(new List<String>(recruiterEmails));
                recruiterMail.setSubject('Notification recruteur - Entretien RH Fit planifie');
                recruiterMail.setHtmlBody(
                    '<div style="font-family:Inter,Arial,sans-serif;max-width:620px;margin:0 auto;">' +
                    '<div style="background:linear-gradient(135deg,#0f172a,#1f2937);padding:22px 26px;border-radius:14px 14px 0 0;">' +
                    '<h2 style="color:#fff;margin:0;font-size:20px;">Entretien RH Fit a animer</h2>' +
                    '<p style="color:rgba(255,255,255,0.8);margin:8px 0 0;">Action recruteur: conduite entretien + enregistrement + analyse IA</p>' +
                    '</div>' +
                    '<div style="background:#fff;padding:22px 26px;border:1px solid #e5e7eb;border-top:none;">' +
                    '<p style="margin:0 0 10px;font-size:14px;color:#334155;"><strong>Candidat:</strong> ' + candidateDisplayName + '</p>' +
                    '<p style="margin:0 0 10px;font-size:14px;color:#334155;"><strong>Date:</strong> ' + dateLabel + '</p>' +
                    '<p style="margin:0 0 16px;font-size:14px;color:#334155;"><strong>Duree:</strong> ' + dureeLabel + '</p>' +
                    '<div style="text-align:center;margin:0 0 14px;">' +
                    '<a href="' + jitsiUrl + '" style="display:inline-block;padding:10px 20px;background:#0f766e;color:#fff;text-decoration:none;border-radius:8px;font-weight:700;margin-right:8px;">Rejoindre Meet</a>' +
                    '<a href="' + recruiterConsoleLink + '" style="display:inline-block;padding:10px 20px;background:#1d4ed8;color:#fff;text-decoration:none;border-radius:8px;font-weight:700;">Ouvrir Dashboard Recruteur</a>' +
                    '</div>' +
                    '<p style="margin:0;font-size:12px;color:#64748b;">Apres l entretien, importez l audio dans le dashboard puis lancez transcription + analyse IA.</p>' +
                    '</div>' +
                    '</div>'
                );
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ recruiterMail });
            }

            createRHFitRecruiterTask(
                opp.OwnerId != null ? opp.OwnerId : UserInfo.getUserId(),
                opp.Id,
                candidateDisplayName,
                parsedDt,
                jitsiUrl
            );
            Set<Id> notifRecipients = new Set<Id>();
            if (opp.OwnerId != null) notifRecipients.add(opp.OwnerId);
            notifRecipients.add(UserInfo.getUserId());
            for (Id uid : notifRecipients) {
                sendRHFitBellNotification(
                    uid,
                    opp.Id,
                    'Entretien RH Fit planifie',
                    'Candidat: ' + candidateDisplayName + ' - ' + dateLabel + '. Cliquez pour rejoindre la salle Meet.',
                    jitsiUrl
                );
            }

            return new Map<String, Object>{
                'success' => true,
                'jitsiRoom' => jitsiRoom,
                'jitsiUrl' => jitsiUrl,
                'portalLink' => portalLink
            };
        } catch (Exception e) {
            throw new AuraHandledException('Erreur planification RH Fit : ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Map<String, Object> validateRHFitInterview(
        Id oppId,
        Decimal recruiterScore,
        String decision,
        String recruiterNotes
    ) {
        try {
            if (oppId == null) throw new AuraHandledException('Candidature introuvable.');
            if (String.isBlank(decision)) throw new AuraHandledException('Veuillez choisir une decision.');

            Decimal score = recruiterScore != null ? recruiterScore : 0;
            if (score < 0) score = 0;
            if (score > 100) score = 100;

            List<RH_Fit_Interview__c> listRec = [
                SELECT Id, Manager_Notes__c
                FROM RH_Fit_Interview__c
                WHERE Opportunity__c = :oppId
                LIMIT 1
            ];
            RH_Fit_Interview__c rec = listRec.isEmpty()
                ? new RH_Fit_Interview__c(Opportunity__c = oppId)
                : listRec[0];
            rec.Recruiter_Validated_Score__c = score;
            rec.Status__c = decision == 'review' ? 'Review' : 'Validated';
            if (String.isNotBlank(recruiterNotes)) {
                rec.Manager_Notes__c = (
                    (rec.Manager_Notes__c != null ? rec.Manager_Notes__c + '\n\n' : '') +
                    'Decision RH Fit: ' + decision + '\n' +
                    'Score valide: ' + score + '/100\n' +
                    recruiterNotes
                ).left(32768);
            }
            upsert rec;

            String newStage;
            Boolean hired = false;
            String recommendation;

            if (decision == 'accept') {
                if (score < 75) {
                    throw new AuraHandledException('Score < 75/100. Utilisez review/reject ou ajustez le score.');
                }
                newStage = 'Closed Won';
                hired = true;
                recommendation = 'Candidat embauche.';
                updateOpportunityStage(oppId, newStage);
            } else if (decision == 'reject') {
                newStage = 'Closed Lost';
                recommendation = 'Candidat non retenu apres RH Fit.';
                updateOpportunityStage(oppId, newStage);
            } else if (decision == 'review') {
                newStage = 'RH Fit';
                recommendation = 'Revue complementaire requise.';
            } else {
                throw new AuraHandledException('Decision invalide.');
            }

            return new Map<String, Object>{
                'success' => true,
                'hired' => hired,
                'newStage' => newStage,
                'recommendation' => recommendation,
                'validatedScore' => score
            };
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur validation RH Fit : ' + e.getMessage());
        }
    }

    private static void createRHFitRecruiterTask(
        Id ownerId,
        Id oppId,
        String candidateName,
        Datetime interviewDateTime,
        String meetLink
    ) {
        if (ownerId == null || oppId == null) return;
        try {
            Task t = new Task();
            t.OwnerId = ownerId;
            t.WhatId = oppId;
            t.Subject = 'RH Fit a animer - ' + (String.isNotBlank(candidateName) ? candidateName : 'Candidat');
            t.Priority = 'High';
            t.Status = 'Not Started';
            t.ActivityDate = interviewDateTime != null ? interviewDateTime.date() : Date.today();
            t.Description =
                'Entretien RH Fit planifie.' + '\n' +
                'Candidat: ' + (String.isNotBlank(candidateName) ? candidateName : 'Candidat') + '\n' +
                'Date: ' + (interviewDateTime != null ? interviewDateTime.format('dd/MM/yyyy HH:mm') : 'N/A') + '\n' +
                'Meet: ' + (String.isNotBlank(meetLink) ? meetLink : 'N/A') + '\n' +
                'Action: conduire l entretien, enregistrer, puis lancer transcription + analyse IA.';
            insert t;
        } catch (Exception ex) {
            System.debug('RH Fit task notification error: ' + ex.getMessage());
        }
    }

    private static void sendRHFitBellNotification(
        Id recipientUserId,
        Id targetId,
        String title,
        String body,
        String targetUrl
    ) {
        if (recipientUserId == null || targetId == null) return;
        try {
            Id notifTypeId = getRHFitNotificationTypeId();
            if (notifTypeId == null) return;

            Messaging.CustomNotification notif = new Messaging.CustomNotification();
            notif.setNotificationTypeId(notifTypeId);
            notif.setTitle((String.isNotBlank(title) ? title : 'Notification RH Fit').left(80));
            notif.setBody((String.isNotBlank(body) ? body : 'Mise a jour RH Fit.').left(750));
            if (String.isNotBlank(targetUrl)) {
                Map<String, Object> pageRef = new Map<String, Object>{
                    'type' => 'standard__webPage',
                    'attributes' => new Map<String, Object>{
                        'url' => targetUrl
                    }
                };
                notif.setTargetPageRef(JSON.serialize(pageRef));
            } else {
                notif.setTargetId(targetId);
            }
            notif.send(new Set<String>{ String.valueOf(recipientUserId) });
        } catch (Exception ex) {
            System.debug('RH Fit bell notification error: ' + ex.getMessage());
        }
    }

    private static Id getRHFitNotificationTypeId() {
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
        if (!types.isEmpty()) return types[0].Id;

        List<CustomNotificationType> fallbackTypes = [
            SELECT Id
            FROM CustomNotificationType
            LIMIT 1
        ];
        return fallbackTypes.isEmpty() ? null : fallbackTypes[0].Id;
    }

    @AuraEnabled
    public static Map<String, Object> validateArchitectureInterview(
        Id oppId,
        Decimal designScore,
        Decimal tradeoffScore,
        Decimal scalabilityScore,
        Decimal communicationScore,
        Decimal collaborationScore,
        String decision,
        String managerNotes
    ) {
        try {
            if (oppId == null) {
                throw new AuraHandledException('Candidature introuvable.');
            }
            if (String.isBlank(decision)) {
                throw new AuraHandledException('Veuillez choisir une decision.');
            }

            Decimal d = normalizeArchitectureCriteriaScore(designScore);
            Decimal t = normalizeArchitectureCriteriaScore(tradeoffScore);
            Decimal s = normalizeArchitectureCriteriaScore(scalabilityScore);
            Decimal c = normalizeArchitectureCriteriaScore(communicationScore);
            Decimal p = normalizeArchitectureCriteriaScore(collaborationScore);

            Decimal finalScore =
                ((d / 5) * 30) +
                ((t / 5) * 25) +
                ((s / 5) * 20) +
                ((c / 5) * 15) +
                ((p / 5) * 10);
            finalScore = finalScore.setScale(1, RoundingMode.HALF_UP);

            List<Architecture_Interview__c> aiList = [
                SELECT Id
                FROM Architecture_Interview__c
                WHERE Opportunity__c = :oppId
                LIMIT 1
            ];
            Architecture_Interview__c ai = aiList.isEmpty()
                ? new Architecture_Interview__c(Opportunity__c = oppId)
                : aiList[0];

            String structuredNotes =
                'Validation Architecture (recruteur)' + '\n' +
                'Design architecture (30): ' + d + '/5' + '\n' +
                'Trade-offs techniques (25): ' + t + '/5' + '\n' +
                'Scalabilite/Securite/Performance (20): ' + s + '/5' + '\n' +
                'Communication (15): ' + c + '/5' + '\n' +
                'Collaboration/Posture (10): ' + p + '/5' + '\n' +
                'Score final: ' + finalScore + '/100';
            if (String.isNotBlank(managerNotes)) {
                structuredNotes += '\n---\n' + managerNotes;
            }

            ai.Score__c = finalScore;
            ai.Status__c = decision == 'review' ? 'Review' : 'Completed';
            ai.Manager_Notes__c = structuredNotes.left(32768);
            upsert ai;

            String newStage;
            Boolean passed = false;
            String recommendation;

            if (decision == 'accept') {
                if (finalScore < 70) {
                    throw new AuraHandledException(
                        'Le score est inferieur a 70/100. Utilisez review/reject, ou ajustez les criteres.'
                    );
                }
                newStage = 'RH Fit';
                passed = true;
                recommendation = 'Candidat valide pour RH Fit.';
                updateOpportunityStage(oppId, newStage);
            } else if (decision == 'reject') {
                newStage = 'Closed Lost';
                recommendation = 'Candidat non retenu apres entretien architecture.';
                updateOpportunityStage(oppId, newStage);
            } else if (decision == 'review') {
                newStage = 'Architecture';
                recommendation = 'Candidat a revoir (2e avis ou entretien complementaire).';
            } else {
                throw new AuraHandledException('Decision invalide.');
            }

            Map<String, Object> result = new Map<String, Object>();
            result.put('finalScore', finalScore);
            result.put('newStage', newStage);
            result.put('passed', passed);
            result.put('recommendation', recommendation);
            return result;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur validation architecture : ' + e.getMessage());
        }
    }

    private static Decimal normalizeArchitectureCriteriaScore(Decimal score) {
        if (score == null) return 0;
        if (score < 0) return 0;
        if (score > 5) return 5;
        return score;
    }
}
