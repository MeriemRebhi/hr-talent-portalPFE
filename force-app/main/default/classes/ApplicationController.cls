public without sharing class ApplicationController {

    // ─────────────────────────────────────────────
    // CRÉATION LEAD
    // ─────────────────────────────────────────────

    @AuraEnabled
    public static Id createCandidate(String firstName, String lastName, String email, String phone) {
        return createCandidateInternal(firstName, lastName, email, phone, null, null, null, null);
    }

    @AuraEnabled

    public static Id createCandidateForJob(String firstName, String lastName, String email,
                                            String phone, String jobId, String candidateProfile,
                                            String adresse, String codePostale) {
        return createCandidateInternal(firstName, lastName, email, phone, jobId, candidateProfile, adresse, codePostale);
    }

    private static Id createCandidateInternal(String firstName, String lastName, String email,
                                               String phone, String jobId, String candidateProfile,
                                               String adresse, String codePostale) {
        if (String.isBlank(firstName) || String.isBlank(lastName) || String.isBlank(email)) {
            throw new AuraHandledException('Prénom, Nom et Email sont obligatoires.');
        }

        try {
            Lead lead = new Lead();
            lead.FirstName  = firstName;
            lead.LastName   = lastName;
            lead.Email      = email;
            lead.Phone      = phone;
            lead.Company    = 'Candidat';
            lead.LeadSource = 'Talent Portal';
            lead.Adresse_exacte__c = adresse;
            lead.Code_postale__c = codePostale;

            List<String> metadata = new List<String>();
            if (!String.isBlank(jobId)) {
                metadata.add('JOB_ID:' + jobId);
            }
            if (!String.isBlank(candidateProfile)) {
                metadata.add('PROFILE_TEXT:');
                metadata.add(candidateProfile.trim());
            }
            if (!metadata.isEmpty()) {
                lead.Description = String.join(metadata, '\n');
            }

            Database.DMLOptions dmlOpts = new Database.DMLOptions();
            dmlOpts.DuplicateRuleHeader.allowSave = true;
            Database.insert(lead, dmlOpts);
            return lead.Id;

        } catch (Exception e) {
            throw new AuraHandledException('Erreur création Lead : ' + e.getMessage());
        }
    }


    // ─────────────────────────────────────────────
    // UPLOAD CV — VERSION CHUNKED (évite limite 4MB Aura)
    // ─────────────────────────────────────────────

    /**
     * Étape 1 — Initialise l'upload et crée un ContentVersion vide
     * Retourne le ContentVersionId pour les appels suivants
     */
    @AuraEnabled
    public static String initUpload(String leadId, String fileName) {
        try {
            if (String.isBlank(leadId) || String.isBlank(fileName)) {
                throw new AuraHandledException('leadId et fileName sont obligatoires.');
            }
            // On crée un ContentVersion avec un byte vide — sera remplacé au finalizeUpload
            ContentVersion cv = new ContentVersion();
            cv.Title         = fileName;
            cv.PathOnClient  = fileName;
            cv.IsMajorVersion = true;
            cv.VersionData   = Blob.valueOf('PLACEHOLDER');
            insert cv;
            return cv.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur init upload: ' + e.getMessage());
        }
    }

    /**
     * Étape 2 — Reçoit les chunks base64 et les accumule dans un champ texte temporaire
     * chunkIndex: 0-based index du chunk
     * totalChunks: nombre total de chunks
     */
    @AuraEnabled
    public static void uploadChunk(String contentVersionId, String base64Chunk,
                                   Integer chunkIndex, Integer totalChunks) {
        try {
            if (String.isBlank(contentVersionId) || String.isBlank(base64Chunk)) {
                throw new AuraHandledException('Paramètres manquants pour uploadChunk.');
            }

            // Lire le ContentVersion existant
            ContentVersion cv = [
                SELECT Id, VersionData, Title
                FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];

            // Décoder le chunk entrant
            Blob chunkBlob = EncodingUtil.base64Decode(base64Chunk);

            if (chunkIndex == 0) {
                // Premier chunk: remplace le placeholder
                cv.VersionData = chunkBlob;
            } else {
                // Chunks suivants: concaténer avec l'existant
                String existingBase64 = EncodingUtil.base64Encode(cv.VersionData);
                String combined = existingBase64 + base64Chunk;
                cv.VersionData = EncodingUtil.base64Decode(combined);
            }

            update cv;

        } catch (Exception e) {
            throw new AuraHandledException('Erreur uploadChunk [' + chunkIndex + ']: ' + e.getMessage());
        }
    }

    /**
     * Étape 3 — Finalise l'upload: lie le document au Lead et déclenche le scoring
     */
    @AuraEnabled
    public static Id finalizeUpload(String contentVersionId, String leadId) {
        try {
            if (String.isBlank(contentVersionId) || String.isBlank(leadId)) {
                throw new AuraHandledException('contentVersionId et leadId sont obligatoires.');
            }

            // Récupérer le ContentDocumentId
            ContentVersion cv = [
                SELECT ContentDocumentId FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];

            // Lier au Lead
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId    = leadId;
            cdl.ShareType         = 'V';
            insert cdl;

            return cv.ContentDocumentId;

        } catch (Exception e) {
            throw new AuraHandledException('Erreur finalizeUpload: ' + e.getMessage());
        }
    }

    /**
     * Méthode legacy uploadCv — garde la compatibilité pour les petits fichiers (<1MB)
     * Pour les gros fichiers, utiliser initUpload + uploadChunk + finalizeUpload
     */
    @AuraEnabled
    public static Id uploadCv(String leadId, String fileName, String base64Data) {
        try {
            if (String.isBlank(leadId) || String.isBlank(fileName) || String.isBlank(base64Data)) {
                throw new AuraHandledException('Données manquantes pour upload CV');
            }

            // Vérifier la taille (~3MB max pour rester sous la limite Aura)
            Integer maxBase64Length = 3 * 1024 * 1024; // 3MB en base64
            if (base64Data.length() > maxBase64Length) {
                throw new AuraHandledException(
                    'Fichier trop volumineux pour upload direct. Utilisez un CV de moins de 2MB, ' +
                    'ou contactez votre administrateur.'
                );
            }

            ContentVersion cv = new ContentVersion();
            cv.Title         = fileName;
            cv.PathOnClient  = fileName;
            cv.IsMajorVersion = true;
            cv.VersionData   = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = leadId; // Publie directement sur le Lead (compatible Guest User)
            insert cv;

            ContentVersion inserted = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ];

            return inserted.ContentDocumentId;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur upload CV : ' + e.getMessage());
        }
    }


    // ─────────────────────────────────────────────
    // DÉCLENCHEMENT SCORING IA
    // ─────────────────────────────────────────────

    @AuraEnabled
    public static void triggerScoring(Id leadId) {
        if (String.isBlank(leadId)) return;
        CVScoringService.scoreCVForLeads(new Set<String>{ (String)leadId });
    }

    // ─────────────────────────────────────────────
    // CANDIDATURES
    // ─────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getCandidaturesByUser() {
        List<Lead> leads = [
            SELECT Id, FirstName, LastName, Email, Phone, CreatedDate, LeadSource,
                   Score_Matching__c, AI_Recommendation__c,
                   AI_Points_Forts__c, AI_Points_Faibles__c,
                   Status, IsConverted, ConvertedOpportunityId
            FROM Lead
            WHERE LeadSource = 'Talent Portal'
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];

        // Fetch Opportunity stage for converted leads
        Set<Id> oppIds = new Set<Id>();
        for (Lead l : leads) {
            if (l.IsConverted && l.ConvertedOpportunityId != null) {
                oppIds.add(l.ConvertedOpportunityId);
            }
        }
        Map<Id, String> oppStageMap = new Map<Id, String>();
        if (!oppIds.isEmpty()) {
            for (Opportunity o : [SELECT Id, StageName FROM Opportunity WHERE Id IN :oppIds]) {
                oppStageMap.put(o.Id, o.StageName);
            }
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Lead l : leads) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('Id', l.Id);
            row.put('FirstName', l.FirstName);
            row.put('LastName', l.LastName);
            row.put('Email', l.Email);
            row.put('Phone', l.Phone);
            row.put('CreatedDate', l.CreatedDate);
            row.put('Score_Matching__c', l.Score_Matching__c);
            row.put('AI_Recommendation__c', l.AI_Recommendation__c);
            row.put('LeadStatus', l.Status);
            row.put('IsConverted', l.IsConverted);
            String oppStage = (l.IsConverted && l.ConvertedOpportunityId != null)
                ? oppStageMap.get(l.ConvertedOpportunityId) : null;
            row.put('StageName', oppStage);
            result.add(row);
        }
        return result;
    }

    // ─────────────────────────────────────────────
    // DASHBOARD CANDIDAT (portail personnel)
    // ─────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCandidateDashboard() {
        Map<String, Object> result = new Map<String, Object>();

        // 1. Récupérer le User connecté et son Contact
        Id userId = UserInfo.getUserId();
        List<User> users = [SELECT Id, ContactId, FirstName, LastName, Email, Phone, SmallPhotoUrl 
                            FROM User WHERE Id = :userId LIMIT 1];
        
        if (users.isEmpty() || users[0].ContactId == null) {
            result.put('isGuest', true);
            return result;
        }

        User u = users[0];
        Contact con = [SELECT Id, FirstName, LastName, Email, Phone, MailingStreet, MailingCity, 
                               MailingPostalCode, AccountId, Account.Name, CreatedDate
                        FROM Contact WHERE Id = :u.ContactId LIMIT 1];

        // 2. Infos profil
        Map<String, Object> profile = new Map<String, Object>();
        profile.put('firstName', con.FirstName);
        profile.put('lastName', con.LastName);
        profile.put('email', con.Email);
        profile.put('phone', con.Phone);
        profile.put('address', con.MailingStreet);
        profile.put('city', con.MailingCity);
        profile.put('postalCode', con.MailingPostalCode);
        profile.put('photoUrl', u.SmallPhotoUrl);
        profile.put('memberSince', con.CreatedDate);
        result.put('profile', profile);
        result.put('isGuest', false);

        // 3. Candidatures (Opportunities liées au Contact via Account)
        List<Map<String, Object>> candidatures = new List<Map<String, Object>>();
        List<Opportunity> opps = [
            SELECT Id, Name, StageName, Score_Matching__c, CreatedDate, CloseDate,
                   Description_Poste__c, Departement__c, Localisation__c, Type_de_Contrat__c,
                   Gaming_Test_DateTime__c, Gaming_Test_Duration__c, Gaming_Meet_Link__c,
                   RecordType.DeveloperName
            FROM Opportunity 
            WHERE AccountId = :con.AccountId
            AND RecordType.DeveloperName = 'Application'
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];

        // Résoudre les noms de Job Posting via les Leads convertis
        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : opps) oppIds.add(opp.Id);

        Map<Id, String> oppIdToJobTitle = new Map<Id, String>();
        if (!oppIds.isEmpty()) {
            List<Lead> convertedLeads = [
                SELECT ConvertedOpportunityId, Description
                FROM Lead
                WHERE ConvertedOpportunityId IN :oppIds
                AND IsConverted = true
            ];
            Set<Id> jobIds = new Set<Id>();
            Map<Id, Id> oppIdToJobId = new Map<Id, Id>();
            for (Lead cl : convertedLeads) {
                if (String.isBlank(cl.Description)) continue;
                for (String line : cl.Description.split('\n')) {
                    if (line.startsWith('JOB_ID:')) {
                        String jId = line.replace('JOB_ID:', '').trim();
                        if (String.isNotBlank(jId)) {
                            try {
                                Id jobOppId = (Id) jId;
                                jobIds.add(jobOppId);
                                oppIdToJobId.put(cl.ConvertedOpportunityId, jobOppId);
                            } catch (Exception ex) {}
                        }
                        break;
                    }
                }
            }
            if (!jobIds.isEmpty()) {
                Map<Id, String> jobNameById = new Map<Id, String>();
                for (Opportunity job : [SELECT Id, Name FROM Opportunity WHERE Id IN :jobIds]) {
                    jobNameById.put(job.Id, job.Name);
                }
                for (Id appOppId : oppIdToJobId.keySet()) {
                    Id jobId = oppIdToJobId.get(appOppId);
                    if (jobNameById.containsKey(jobId)) {
                        oppIdToJobTitle.put(appOppId, jobNameById.get(jobId));
                    }
                }
            }
        }

        for (Opportunity opp : opps) {
            Map<String, Object> cand = new Map<String, Object>();
            cand.put('id', opp.Id);
            cand.put('name', opp.Name);
            String jobTitle = oppIdToJobTitle.containsKey(opp.Id) ? oppIdToJobTitle.get(opp.Id) : opp.Name;
            cand.put('jobTitle', jobTitle);
            cand.put('stage', opp.StageName);
            cand.put('score', opp.Score_Matching__c);
            cand.put('date', opp.CreatedDate);
            cand.put('closeDate', opp.CloseDate);
            cand.put('department', opp.Departement__c);
            cand.put('location', opp.Localisation__c);
            cand.put('contractType', opp.Type_de_Contrat__c);
            cand.put('gamingDateTime', opp.Gaming_Test_DateTime__c);
            cand.put('gamingDuration', opp.Gaming_Test_Duration__c);
            cand.put('gamingMeetLink', opp.Gaming_Meet_Link__c);
            candidatures.add(cand);
        }

        // 3b. Technical Interview data per candidature
        if (!oppIds.isEmpty()) {
            Map<Id, Technical_Interview__c> tiMap = new Map<Id, Technical_Interview__c>();
            for (Technical_Interview__c ti : [
                SELECT Opportunity__c, Score__c, Interview_DateTime__c, Meet_Link__c,
                       Status__c, Duration__c, Composite_Score__c, Reschedule_Requested__c
                FROM Technical_Interview__c
                WHERE Opportunity__c IN :oppIds
            ]) {
                tiMap.put(ti.Opportunity__c, ti);
            }
            for (Map<String, Object> cand : candidatures) {
                Id candId = (Id) cand.get('id');
                if (tiMap.containsKey(candId)) {
                    Technical_Interview__c ti = tiMap.get(candId);
                    cand.put('techScore', ti.Score__c);
                    cand.put('techDate', ti.Interview_DateTime__c);
                    cand.put('techMeetLink', ti.Meet_Link__c);
                    cand.put('techStatus', ti.Status__c);
                    cand.put('techDuration', ti.Duration__c);
                    cand.put('techCompositeScore', ti.Composite_Score__c);
                    cand.put('techRescheduleRequested', ti.Reschedule_Requested__c);
                } else {
                    cand.put('techScore', null);
                    cand.put('techDate', null);
                    cand.put('techMeetLink', null);
                    cand.put('techStatus', null);
                    cand.put('techDuration', null);
                    cand.put('techCompositeScore', null);
                    cand.put('techRescheduleRequested', false);
                }
            }
        }

        result.put('candidatures', candidatures);
        result.put('totalCandidatures', candidatures.size());

        // 4. CV attaché au Contact
        List<ContentDocumentLink> cvLinks = [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                   ContentDocument.ContentSize, ContentDocument.CreatedDate
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :con.Id
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        if (!cvLinks.isEmpty()) {
            Map<String, Object> cv = new Map<String, Object>();
            cv.put('documentId', cvLinks[0].ContentDocumentId);
            cv.put('title', cvLinks[0].ContentDocument.Title);
            cv.put('extension', cvLinks[0].ContentDocument.FileExtension);
            cv.put('size', cvLinks[0].ContentDocument.ContentSize);
            cv.put('uploadDate', cvLinks[0].ContentDocument.CreatedDate);
            result.put('cv', cv);
        }

        return result;
    }

    @AuraEnabled
    public static void updateCandidateProfile(String phone, String address, String city, String postalCode) {
        Id userId = UserInfo.getUserId();
        List<User> users = [SELECT ContactId FROM User WHERE Id = :userId LIMIT 1];
        if (users.isEmpty() || users[0].ContactId == null) {
            throw new AuraHandledException('Aucun profil candidat trouvé.');
        }
        try {
            Contact con = new Contact(Id = users[0].ContactId);
            if (phone != null) con.Phone = phone;
            if (address != null) con.MailingStreet = address;
            if (city != null) con.MailingCity = city;
            if (postalCode != null) con.MailingPostalCode = postalCode;
            update con;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur mise à jour profil: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // LECTURE CV EN BASE64 (pour affichage dans le portail)
    // ─────────────────────────────────────────────

    @AuraEnabled
    public static Map<String, String> getCvBase64(String documentId) {
        try {
            ContentVersion cv = [
                SELECT VersionData, FileType, Title
                FROM ContentVersion
                WHERE ContentDocumentId = :documentId
                AND IsLatest = true
                LIMIT 1
            ];
            Map<String, String> result = new Map<String, String>();
            result.put('base64', EncodingUtil.base64Encode(cv.VersionData));
            result.put('fileType', cv.FileType);
            result.put('title', cv.Title);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur lecture CV : ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────
    // UPLOAD CV DEPUIS LE DASHBOARD CANDIDAT
    // ─────────────────────────────────────────────

    @AuraEnabled
    public static Id uploadCvForContact(String fileName, String base64Data) {
        try {
            if (String.isBlank(fileName) || String.isBlank(base64Data)) {
                throw new AuraHandledException('Données manquantes pour le CV.');
            }
            Id userId = UserInfo.getUserId();
            List<User> users = [SELECT ContactId FROM User WHERE Id = :userId LIMIT 1];
            if (users.isEmpty() || users[0].ContactId == null) {
                throw new AuraHandledException('Aucun profil candidat trouvé.');
            }
            String contactId = users[0].ContactId;

            ContentVersion cv = new ContentVersion();
            cv.Title              = fileName.contains('.') ? fileName.substringBeforeLast('.') : fileName;
            cv.PathOnClient       = fileName;
            cv.IsMajorVersion     = true;
            cv.VersionData        = EncodingUtil.base64Decode(base64Data);
            cv.FirstPublishLocationId = contactId;
            insert cv;

            ContentVersion inserted = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            return inserted.ContentDocumentId;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur upload CV : ' + e.getMessage());
        }
    }
}