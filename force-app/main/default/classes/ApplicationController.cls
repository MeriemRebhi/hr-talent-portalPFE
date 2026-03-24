public with sharing class ApplicationController {

    // ─────────────────────────────────────────────
    // CRÉATION LEAD
    // ─────────────────────────────────────────────

    @AuraEnabled
    public static Id createCandidate(String firstName, String lastName, String email, String phone) {
        return createCandidateInternal(firstName, lastName, email, phone, null, null);
    }

    @AuraEnabled
    public static Id createCandidateForJob(String firstName, String lastName, String email,
                                            String phone, String jobId, String candidateProfile) {
        return createCandidateInternal(firstName, lastName, email, phone, jobId, candidateProfile);
    }

    private static Id createCandidateInternal(String firstName, String lastName, String email,
                                               String phone, String jobId, String candidateProfile) {
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
            insert cv;

            ContentVersion inserted = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ];

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = inserted.ContentDocumentId;
            cdl.LinkedEntityId    = leadId;
            cdl.ShareType         = 'V';
            insert cdl;

            return inserted.ContentDocumentId;

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Erreur upload CV : ' + e.getMessage());
        }
    }


    // ─────────────────────────────────────────────
    // CANDIDATURES
    // ─────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Lead> getCandidaturesByUser() {
        return [
            SELECT Id, FirstName, LastName, Email, Phone, CreatedDate, LeadSource,
                   Score_Matching__c, AI_Recommendation__c,
                   AI_Points_Forts__c, AI_Points_Faibles__c
            FROM Lead
            WHERE LeadSource = 'Talent Portal'
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }
}