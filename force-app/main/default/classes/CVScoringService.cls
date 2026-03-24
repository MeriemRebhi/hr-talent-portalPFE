/**
 * CVScoringService - HR Talent Portal - Talan Tunisie PFE 2024/2025
 * OCR pipeline: TextPreview → OCR.space → PROFILE_TEXT fallback
 */
public class CVScoringService {

    private static final Decimal QUALIFICATION_THRESHOLD = 30;
    private static final Integer HOT_THRESHOLD           = 70;
    private static final Integer WARM_THRESHOLD          = 40;
    private static final String  GROQ_MODEL              = 'llama-3.3-70b-versatile';
    private static final String  GROQ_ENDPOINT           = 'https://api.groq.com/openai/v1/chat/completions';
    private static final String  OCR_ENDPOINT            = 'https://api.ocr.space/parse/image';
    private static final Integer HTTP_TIMEOUT            = 30000;
    private static final Integer MAX_CV_CHARS            = 4000;
    private static final String  CANDIDATE_LOGIN_URL     = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/rinitialisation-mot-de-passe';

    // ── Points d'entrée ──

    public static void scoreCVForLeads(Set<String> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) return;
        System.enqueueJob(new CVScoringQueue(new List<String>(leadIds)));
    }

    public static void scoreCVForLeadNow(String leadId) {
        runScoring(leadId);
    }

    private class CVScoringQueue implements Queueable, Database.AllowsCallouts {
        private List<String> leadIds;
        public CVScoringQueue(List<String> ids) { this.leadIds = ids == null ? new List<String>() : ids; }
        public void execute(QueueableContext ctx) {
            for (String id : leadIds) { if (!String.isBlank(id)) runScoring(id); }
        }
    }

    // ── Moteur principal ──

    private static void runScoring(String leadId) {
        try {
            Lead lead = [
                SELECT Id, FirstName, LastName, Email, Phone,
                       Score_Matching__c, AI_Recommendation__c,
                       AI_Points_Forts__c, AI_Points_Faibles__c,
                       IsConverted, Description, Rating
                FROM Lead WHERE Id = :leadId LIMIT 1
            ];

            if (lead.IsConverted) { System.debug('⚠️ Lead déjà converti'); return; }

            Id     jobId   = extractJobIdFromDescription(lead.Description);
            String jobCtx  = loadJobDescription(jobId);
            String profile = extractCandidateProfile(lead.Description);

            System.debug('📋 JOB_ID: ' + jobId + ' | Job context: ' + (jobCtx != null ? 'OUI' : 'NON'));

            ContentVersion cv = loadLatestCV(leadId);
            String cvText = extractBestCvText(cv, profile);

            if (String.isBlank(cvText)) {
                updateLeadWithError(lead, 'CV non lisible. Uploadez un PDF texte/DOCX ou renseignez votre profil.');
                return;
            }
            System.debug('✅ Texte extrait: ' + cvText.length() + ' chars');

            AI_Configuration__c config = AI_Configuration__c.getOrgDefaults();
            String groqKey = config.Groq_API_Key__c != null ? config.Groq_API_Key__c.trim() : '';
            if (String.isBlank(groqKey)) { updateLeadWithError(lead, 'Clé Groq manquante.'); return; }

            Map<String, Object> result = sendGroqRequest(groqKey, buildRHPrompt(cvText, jobCtx));
            if (result == null || result.containsKey('error')) {
                updateLeadWithError(lead, 'Service Groq indisponible.');
                return;
            }

            Decimal score = extractScore(result);
            System.debug('🎯 Score: ' + score + '/100');

            lead.Score_Matching__c    = score;
            lead.Rating               = deriveLeadRating(score);
            lead.AI_Recommendation__c = truncate((String) result.get('recommandation'), 255);
            lead.AI_Points_Forts__c   = truncate((String) result.get('points_forts'), 32000);
            lead.AI_Points_Faibles__c = truncate((String) result.get('points_faibles'), 32000);
            lead.Description          = upsertATSReport(lead.Description, buildATSReport(result, score));
            update lead;
            System.debug('✅ Lead mis à jour — Score: ' + score + ' | Rating: ' + lead.Rating);

            if (score != null && score >= QUALIFICATION_THRESHOLD) {
                Id oppId = convertLeadToContactAndOpportunity(lead, score, jobId);
                if (oppId != null) sendInvitationEmail(lead, score, oppId);
            } else {
                System.debug('❌ Score ' + score + ' < ' + QUALIFICATION_THRESHOLD + ' → non qualifié');
            }

        } catch (Exception e) {
            System.debug('❌ runScoring: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    // ── Pipeline extraction texte CV ──

    private static String extractBestCvText(ContentVersion cv, String profile) {
        String cvText = null;

        if (cv != null) {
            String ext = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : '';
            System.debug('📄 CV: ' + cv.Title + ' | Ext: ' + ext);

            // Méthode 1: Texte brut
            if (ext == 'txt' || ext == 'rtf' || ext == 'csv') {
                try { cvText = cv.VersionData.toString(); System.debug('✅ M1 texte brut: ' + cvText.length()); }
                catch (Exception e) { System.debug('⚠️ M1 échoué: ' + e.getMessage()); }
            }

            // Méthode 2: TextPreview Salesforce (PDF texte / DOCX)
            if (String.isBlank(cvText) && !String.isBlank(cv.TextPreview)) {
                cvText = cv.TextPreview;
                System.debug('✅ M2 TextPreview: ' + cvText.length());
            }

            // Méthode 3: OCR.space (PDF scanné / image)
            if (String.isBlank(cvText) && cv.VersionData != null) {
                System.debug('🔍 TextPreview vide → OCR.space...');
                cvText = callOcrSpaceApi(cv);
                if (!String.isBlank(cvText)) System.debug('✅ M3 OCR.space: ' + cvText.length());
                else System.debug('⚠️ OCR.space: aucun texte retourné');
            }
        }

        // Méthode 4: Profil texte (fallback)
        if (!String.isBlank(profile)) {
            cvText = String.isBlank(cvText)
                ? 'PROFIL CANDIDAT:\n' + profile
                : cvText + '\n\nPROFIL CANDIDAT (saisi):\n' + profile;
            System.debug('✅ M4 profil texte ajouté');
        }

        return cvText;
    }

    private static String callOcrSpaceApi(ContentVersion cv) {
        try {
            AI_Configuration__c config = AI_Configuration__c.getOrgDefaults();
            String ocrKey = 'helloworld';
            if (config.PDFco_API_Key__c != null && !String.isBlank(config.PDFco_API_Key__c)) {
                ocrKey = config.PDFco_API_Key__c.trim();
            }

            String ext      = cv.FileExtension != null ? cv.FileExtension.toLowerCase() : 'pdf';
            String mimeType = ext == 'png' ? 'image/png' : (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'application/pdf');

            // OCR.space gratuit: limite 1MB → tronquer à 700KB si nécessaire
            Blob fileData = cv.VersionData;
            Integer maxBytes = 700 * 1024;
            if (fileData.size() > maxBytes) {
                // Encoder en base64, tronquer, redécoder
                String fullB64  = EncodingUtil.base64Encode(fileData);
                Integer maxB64  = (maxBytes * 4 / 3) & ~3; // multiple de 4
                if (fullB64.length() > maxB64) fullB64 = fullB64.substring(0, maxB64);
                fileData = EncodingUtil.base64Decode(fullB64);
                System.debug('⚠️ PDF tronqué à 700KB pour OCR.space (original: ' + cv.VersionData.size() + ' bytes)');
            }
            String dataUri = 'data:' + mimeType + ';base64,' + EncodingUtil.base64Encode(fileData);

            String body =
                'apikey='                 + EncodingUtil.urlEncode(ocrKey, 'UTF-8') +
                '&base64Image='           + EncodingUtil.urlEncode(dataUri, 'UTF-8') +
                '&language=fre' +
                '&isOverlayRequired=false' +
                '&detectOrientation=true' +
                '&scale=true' +
                '&OCREngine=2';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(OCR_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setBody(body);
            req.setTimeout(HTTP_TIMEOUT);

            HttpResponse res = new Http().send(req);
            System.debug('🌐 OCR.space HTTP: ' + res.getStatusCode());

            if (res.getStatusCode() != 200) return null;

            Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (json.get('IsErroredOnProcessing') == true) {
                System.debug('❌ OCR erreur: ' + json.get('ErrorMessage'));
                return null;
            }

            List<Object> pages = (List<Object>) json.get('ParsedResults');
            if (pages == null || pages.isEmpty()) return null;

            List<String> parts = new List<String>();
            for (Object p : pages) {
                String t = (String) ((Map<String, Object>) p).get('ParsedText');
                if (!String.isBlank(t)) parts.add(t.trim());
            }
            String extracted = String.join(parts, '\n');
            return String.isBlank(extracted) ? null : extracted;

        } catch (Exception e) {
            System.debug('❌ OCR.space exception: ' + e.getMessage());
            return null;
        }
    }

    // ── Groq API ──

    private static String buildRHPrompt(String cvText, String jobCtx) {
        String cv  = cvText.length() > MAX_CV_CHARS ? cvText.substring(0, MAX_CV_CHARS) + '\n[tronqué]' : cvText;
        String job = String.isBlank(jobCtx)
            ? 'Aucun poste: évalue en tant que développeur IT généraliste.'
            : 'DESCRIPTION DU POSTE:\n' + jobCtx;
        return
            'Tu es un ATS expert en recrutement IT. Analyse le CV vs le poste.\n\n' +
            'RÈGLES:\n' +
            '1. Ne pas inventer de compétences absentes du CV.\n' +
            '2. Stage ≠ expérience professionnelle.\n' +
            '3. Poste senior + CV étudiant = score max 35.\n' +
            '4. JSON pur uniquement, pas de markdown.\n' +
            '5. Textes en FRANÇAIS.\n\n' +
            'SCORE (0-100): Skills 50% | Expérience 30% | Formation 20%\n\n' +
            job + '\n\nCV:\n' + cv + '\n\n' +
            'JSON attendu:\n' +
            '{"score":75,"recommandation":"...","points_forts":"...","points_faibles":"...",' +
            '"matched_skills":["S1"],"missing_skills":["S2"],"experience_years":2,' +
            '"seniority_match":"good_fit","education_match":"strong","summary":"..."}';
    }

    private static Map<String, Object> sendGroqRequest(String apiKey, String prompt) {
        try {
            Map<String, Object> body = new Map<String, Object>{
                'model'           => GROQ_MODEL,
                'messages'        => new List<Object>{ new Map<String, Object>{ 'role' => 'user', 'content' => prompt } },
                'temperature'     => 0.1,
                'max_tokens'      => 800,
                'response_format' => new Map<String, Object>{ 'type' => 'json_object' }
            };
            HttpRequest req = new HttpRequest();
            req.setEndpoint(GROQ_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + apiKey);
            req.setBody(JSON.serialize(body));
            req.setTimeout(HTTP_TIMEOUT);
            HttpResponse res = new Http().send(req);
            System.debug('🌐 Groq HTTP: ' + res.getStatusCode());
            if (res.getStatusCode() == 200) return parseGroqResponse(res.getBody());
            if (res.getStatusCode() == 401) return buildErrorResult('Clé Groq invalide.');
            if (res.getStatusCode() == 429) return buildErrorResult('Quota Groq dépassé.');
            return buildErrorResult('Groq HTTP ' + res.getStatusCode());
        } catch (Exception e) { return buildErrorResult('Exception: ' + e.getMessage()); }
    }

    private static Map<String, Object> parseGroqResponse(String body) {
        try {
            Map<String, Object> resp = (Map<String, Object>) JSON.deserializeUntyped(body);
            String content = (String) ((Map<String, Object>) ((Map<String, Object>) ((List<Object>) resp.get('choices'))[0]).get('message')).get('content');
            content = content.trim();
            if (content.startsWith('```')) {
                Integer s = content.indexOf('\n'), e = content.lastIndexOf('```');
                if (s != -1 && e > s) content = content.substring(s, e).trim();
            }
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(content);
            System.debug('✅ Groq parsé — Score: ' + result.get('score'));
            return result;
        } catch (Exception e) {
            System.debug('❌ Parse Groq: ' + e.getMessage() + '\nBody: ' + body.left(300));
            return buildErrorResult('Parse échoué.');
        }
    }

    // ── Conversion Lead ──

    private static Id convertLeadToContactAndOpportunity(Lead lead, Decimal score, Id jobId) {
        try {
            Id accountId = getOrCreateAccountForCandidate(lead);
            Id contactId = resolveContact(lead, accountId);
            System.debug(contactId != null ? '✅ Contact: ' + contactId : '⚠️ Contact non créé');
            if (contactId != null) createPortalUser(contactId, lead);

            Id appRtId = getOpportunityRecordTypeId('Application');
            Opportunity opp = new Opportunity(
                Name        = lead.FirstName + ' ' + lead.LastName + ' - Candidature (' + score.intValue() + '%)',
                StageName   = 'Gaming',
                CloseDate   = Date.today().addDays(30),
                AccountId   = accountId,
                Description = lead.AI_Recommendation__c
            );
            if (appRtId != null) opp.RecordTypeId = appRtId;
            insert opp;
            System.debug('✅ Opportunity: ' + opp.Id);

            List<LeadStatus> conv = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
            update new Lead(Id = lead.Id, Status = conv.isEmpty() ? 'Qualified' : conv[0].MasterLabel);
            return opp.Id;
        } catch (Exception e) {
            System.debug('❌ Conversion: ' + e.getMessage());
            return null;
        }
    }

    private static Id resolveContact(Lead lead, Id accountId) {
        if (!String.isBlank(lead.Email)) {
            List<Contact> c = [SELECT Id FROM Contact WHERE Email = :lead.Email ORDER BY LastModifiedDate DESC LIMIT 1];
            if (!c.isEmpty()) return c[0].Id;
        }
        Contact nc = new Contact(
            FirstName = lead.FirstName,
            LastName  = lead.LastName != null ? lead.LastName : 'Candidat',
            Email     = lead.Email,
            Phone     = lead.Phone,
            AccountId = accountId
        );
        Database.DMLOptions o = new Database.DMLOptions();
        o.DuplicateRuleHeader.allowSave = true;
        List<Database.SaveResult> r = Database.insert(new List<Contact>{ nc }, o);
        if (r[0].isSuccess()) return r[0].getId();
        if (!String.isBlank(lead.FirstName) && !String.isBlank(lead.LastName)) {
            List<Contact> bn = [SELECT Id FROM Contact WHERE FirstName = :lead.FirstName AND LastName = :lead.LastName ORDER BY LastModifiedDate DESC LIMIT 1];
            if (!bn.isEmpty()) return bn[0].Id;
        }
        return null;
    }

    // ── Email invitation ──

    private static void sendInvitationEmail(Lead lead, Decimal score, Id oppId) {
        try {
            if (String.isBlank(lead.Email)) return;
            String sc  = String.valueOf(score.intValue());
            String bg  = score >= 70 ? '#0b7a72' : (score >= 40 ? '#11998e' : '#e07b39');
            String fn  = lead.FirstName != null ? lead.FirstName : '';
            String ln  = lead.LastName  != null ? lead.LastName  : '';

            String html =
                '<html><body style="font-family:Arial,sans-serif;background:#f6f8fa;margin:0;">' +
                '<table width="100%" style="padding:0;margin:0;"><tr><td align="center" style="padding:40px 0;">' +
                '<table width="420" style="background:#fff;border-radius:14px;box-shadow:0 4px 18px rgba(0,0,0,.08);overflow:hidden;">' +
                '<tr><td style="background:#11998e;padding:32px 24px;text-align:center;">' +
                '<h1 style="color:#fff;font-size:26px;margin:0 0 8px;">Bienvenue sur le Portail Candidat</h1>' +
                '<p style="color:#e0fff0;font-size:15px;margin:0;">Votre candidature a été retenue !</p>' +
                '</td></tr>' +
                '<tr><td style="padding:28px 24px 18px;text-align:center;">' +
                '<div style="font-size:16px;color:#222;margin-bottom:18px;">Bonjour <strong>' + fn + ' ' + ln + '</strong>,</div>' +
                '<div style="color:#555;font-size:15px;margin-bottom:18px;">' +
                'Votre profil correspond à nos critères.<br>Pour accéder à votre espace, veuillez définir votre mot de passe.' +
                '</div>' +
                '<a href="' + CANDIDATE_LOGIN_URL + '" style="display:inline-block;padding:13px 32px;background:#11998e;color:#fff;font-weight:700;font-size:16px;border-radius:7px;text-decoration:none;margin:18px 0 10px;">Définir mon mot de passe</a>' +
                '<div style="color:#888;font-size:13px;margin-top:12px;">Ou copiez ce lien dans votre navigateur :<br><span style="color:#11998e;word-break:break-all;">' + CANDIDATE_LOGIN_URL + '</span></div>' +
                '</td></tr>' +
                '<tr><td style="padding:0 24px 24px;text-align:center;">' +
                '<div style="color:#aaa;font-size:12px;margin-top:18px;">HR Talent Portal · Talan Tunisie · 2026</div>' +
                '</td></tr>' +
                '</table></td></tr></table></body></html>';

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ lead.Email });
            mail.setSubject('Votre candidature est retenue - HR Talent Portal | Talan Tunisie');
            mail.setHtmlBody(html);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            System.debug('✅ Email envoyé: ' + lead.Email);
        } catch (Exception e) { System.debug('⚠️ Email: ' + e.getMessage()); }
    }

    // ── Utilitaires ──

    private static ContentVersion loadLatestCV(String leadId) {
        List<ContentDocumentLink> links = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :leadId ORDER BY SystemModstamp DESC LIMIT 1];
        if (links.isEmpty()) return null;
        List<ContentVersion> cvs = [SELECT Id, Title, FileExtension, VersionData, TextPreview FROM ContentVersion WHERE ContentDocumentId = :links[0].ContentDocumentId AND IsLatest = true LIMIT 1];
        return cvs.isEmpty() ? null : cvs[0];
    }

    private static Id extractJobIdFromDescription(String d) {
        try {
            if (String.isBlank(d)) return null;
            Integer i = d.indexOf('JOB_ID:'); if (i == -1) return null;
            String t = d.substring(i + 7).trim(); if (t.length() < 15) return null;
            return (Id) t.split('[\\s\\n\\r]')[0];
        } catch (Exception e) { return null; }
    }

    private static String loadJobDescription(Id jobId) {
        if (jobId == null) return null;
        List<Opportunity> j = [SELECT Name, Description_Poste__c FROM Opportunity WHERE Id = :jobId LIMIT 1];
        if (j.isEmpty()) return null;
        return 'Poste: ' + j[0].Name + '\n' + (j[0].Description_Poste__c != null ? j[0].Description_Poste__c : '');
    }

    private static String extractCandidateProfile(String d) {
        try {
            if (String.isBlank(d)) return null;
            Integer i = d.indexOf('PROFILE_TEXT:'); if (i == -1) return null;
            String p = d.substring(i + 13).trim();
            return String.isBlank(p) ? null : p;
        } catch (Exception e) { return null; }
    }

    private static Id getOrCreateAccountForCandidate(Lead lead) {
        String k = String.isBlank(lead.Email) ? (lead.FirstName + ' ' + lead.LastName) : lead.Email;
        List<Account> a = [SELECT Id FROM Account WHERE Name = :k LIMIT 1];
        if (!a.isEmpty()) return a[0].Id;
        Account acc = new Account(Name = k);
        insert acc;
        return acc.Id;
    }

    private static Id getOpportunityRecordTypeId(String devName) {
        List<RecordType> r = [SELECT Id FROM RecordType WHERE SObjectType = 'Opportunity' AND DeveloperName = :devName LIMIT 1];
        return r.isEmpty() ? null : r[0].Id;
    }

    private static Id createPortalUser(Id contactId, Lead lead) {
        try {
            if (contactId == null || String.isBlank(lead.Email)) return null;
            List<User> ex = [SELECT Id FROM User WHERE ContactId = :contactId LIMIT 1];
            if (!ex.isEmpty()) { sendPortalPasswordSetupEmail(ex[0].Id, lead.Email); return ex[0].Id; }
            ex = [SELECT Id FROM User WHERE Email = :lead.Email AND ContactId != null LIMIT 1];
            if (!ex.isEmpty()) { sendPortalPasswordSetupEmail(ex[0].Id, lead.Email); return ex[0].Id; }
            Id pid = resolvePortalProfileId();
            if (pid == null) return null;
            String bn = ((lead.FirstName != null ? lead.FirstName : '') + (lead.LastName != null ? lead.LastName : '')).replaceAll('[^a-zA-Z0-9]', '');
            if (String.isBlank(bn)) bn = 'candidate';
            String al = bn.length() > 8 ? bn.substring(0, 8) : bn;
            String s = String.valueOf(contactId);
            if (s.length() > 6) s = s.substring(s.length() - 6);
            String nn = (bn.length() > 24 ? bn.substring(0, 24) : bn).toLowerCase() + '_' + s;
            String atI = lead.Email.indexOf('@') > 0 ? lead.Email.substring(0, lead.Email.indexOf('@')) : 'candidate';
            String dom = lead.Email.indexOf('@') > 0 ? lead.Email.substring(lead.Email.indexOf('@') + 1) : 'example.com';
            User u = new User();
            u.ContactId = contactId;
            u.ProfileId = pid;
            u.Username = atI + '+portal-' + s + '@' + dom;
            u.Email = lead.Email;
            u.FirstName = lead.FirstName;
            u.LastName = lead.LastName != null ? lead.LastName : 'Candidat';
            u.Alias = al.toLowerCase();
            u.CommunityNickname = nn;
            u.TimeZoneSidKey = 'Africa/Tunis';
            u.LocaleSidKey = 'fr_TN';
            u.EmailEncodingKey = 'UTF-8';
            u.LanguageLocaleKey = 'fr';
            u.IsActive = true;
            insert u;
            sendPortalPasswordSetupEmail(u.Id, lead.Email);
            return u.Id;
        } catch (Exception e) { System.debug('User portail: ' + e.getMessage()); return null; }
    }

    private static Id resolvePortalProfileId() {
        List<Profile> p = [SELECT Id FROM Profile WHERE UserType IN ('CSPLitePortal', 'PowerCustomerSuccess', 'CustomerSuccess') ORDER BY Name LIMIT 1];
        if (!p.isEmpty()) return p[0].Id;
        p = [SELECT Id FROM Profile WHERE UserLicense.Name LIKE '%Community%' ORDER BY Name LIMIT 1];
        return p.isEmpty() ? null : p[0].Id;
    }

    private static void sendPortalPasswordSetupEmail(Id uid, String email) {
        try { if (uid != null && !Test.isRunningTest()) System.resetPassword(uid, true); }
        catch (Exception e) { System.debug('⚠️ Reset pwd: ' + e.getMessage()); }
    }

    private static Decimal extractScore(Map<String, Object> r) {
        try { return r == null || r.get('score') == null ? -1 : Decimal.valueOf(String.valueOf(r.get('score'))); }
        catch (Exception e) { return -1; }
    }

    private static String deriveLeadRating(Decimal score) {
        Integer s = score == null ? -1 : score.intValue();
        return s >= HOT_THRESHOLD ? 'Hot' : (s >= WARM_THRESHOLD ? 'Warm' : 'Cold');
    }

    private static String buildATSReport(Map<String, Object> r, Decimal score) {
        List<String> l = new List<String>();
        l.add('ATS Score: ' + (score != null ? score.intValue() + '%' : 'N/A'));
        List<String> m = toStringList((List<Object>) r.get('matched_skills'));
        if (!m.isEmpty()) l.add('Matched: ' + String.join(m, ', '));
        List<String> mi = toStringList((List<Object>) r.get('missing_skills'));
        if (!mi.isEmpty()) l.add('Missing: ' + String.join(mi, ', '));
        if (r.get('experience_years') != null) l.add('Exp: ' + r.get('experience_years') + ' ans');
        if (r.get('seniority_match')  != null) l.add('Seniority: ' + r.get('seniority_match'));
        if (r.get('education_match')  != null) l.add('Education: ' + r.get('education_match'));
        if (r.get('summary')          != null) l.add('Summary: ' + r.get('summary'));
        return String.join(l, '\n');
    }

    private static String upsertATSReport(String existingDesc, String report) {
        String ex = existingDesc == null ? '' : existingDesc;
        String sm = '[ATS_REPORT_START]', em = '[ATS_REPORT_END]';
        Integer si = ex.indexOf(sm), ei = ex.indexOf(em);
        if (si != -1 && ei > si) ex = (ex.substring(0, si) + ex.substring(ei + em.length())).trim();
        String block = sm + '\n' + report + '\n' + em;
        return String.isBlank(ex) ? block : block + '\n\n' + ex;
    }

    private static List<String> toStringList(List<Object> values) {
        List<String> out = new List<String>();
        if (values == null) return out;
        for (Object v : values) { if (v != null) out.add(String.valueOf(v)); }
        return out;
    }

    private static Map<String, Object> buildErrorResult(String msg) {
        return new Map<String, Object>{ 'error' => true, 'recommandation' => 'IA indisponible: ' + msg, 'points_forts' => 'Non évalué.', 'points_faibles' => 'Non évalué.' };
    }

    private static void updateLeadWithError(Lead lead, String msg) {
        try { update new Lead(Id = lead.Id, AI_Recommendation__c = truncate('Scoring échoué: ' + msg, 255)); }
        catch (Exception e) { System.debug('⚠️ Update erreur: ' + e.getMessage()); }
    }

    private static String truncate(String s, Integer maxLen) {
        if (String.isBlank(s)) return s;
        return s.length() > maxLen ? s.substring(0, maxLen) : s;
    }
}