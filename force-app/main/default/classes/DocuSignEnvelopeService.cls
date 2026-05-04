public with sharing class DocuSignEnvelopeService {

    public class EnvelopeDispatchResult {
        public Boolean success;
        public String envelopeId;
        public String status;
        public String message;
        public String rawResponse;
        public String accountId;
        public String baseUri;
    }

    private class CandidateInfo {
        public String email;
        public String firstName;
        public String lastName;

        public String getFullName() {
            String first = firstName == null ? '' : firstName.trim();
            String last = lastName == null ? '' : lastName.trim();
            String full = (first + ' ' + last).trim();
            return String.isBlank(full) ? 'Candidate' : full;
        }
    }

    public class DocuSignEnvelopeException extends Exception {}

    private static final String SIGN_ANCHOR = '/candidate_sign/';

    @TestVisible
    private static Blob testContractPdfBlob;

    public static EnvelopeDispatchResult sendContractForOpportunity(Id oppId) {
        if (oppId == null) {
            throw new DocuSignEnvelopeException('Opportunity id is required.');
        }

        Opportunity opp = [
            SELECT Id,
                   Name,
                   StageName,
                   AccountId,
                   Is_Candidature__c,
                   DocuSign_Envelope_Id__c,
                   Contract_Status__c,
                   Contract_Error__c,
                   Contract_Sent_At__c,
                   Contract_Attempts__c,
                   Contract_Template_Id__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        if (opp.Is_Candidature__c != true) {
            return buildNoop('Opportunity is not a candidature. No DocuSign contract sent.');
        }

        if (opp.StageName != 'Closed Won') {
            return buildNoop('Opportunity stage is not Closed Won. No contract sent.');
        }

        if (String.isNotBlank(opp.DocuSign_Envelope_Id__c) &&
            isActiveEnvelopeStatus(opp.Contract_Status__c)) {
            return buildNoop('An envelope already exists and is still active.');
        }

        DocuSignConfigService.Config cfg = DocuSignConfigService.getConfigOrThrow();

        CandidateInfo candidate = resolveCandidate(opp);
        if (candidate == null || String.isBlank(candidate.email)) {
            markOpportunityError(opp.Id, 'No candidate email found to send contract.');
            throw new DocuSignEnvelopeException('Candidate email not found.');
        }

        String templateId = resolveTemplateId(opp, cfg);
        Boolean usesDocuSignTemplate = String.isNotBlank(templateId);

        DocuSignAuthService.AuthResult auth = DocuSignAuthService.authenticate();

        Map<String, Object> reqBody = usesDocuSignTemplate
            ? buildTemplateEnvelopeRequest(opp, candidate, cfg, templateId)
            : buildVisualforceEnvelopeRequest(opp, candidate);

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setEndpoint(
            auth.baseUri + '/restapi/v2.1/accounts/' +
            EncodingUtil.urlEncode(auth.accountId, 'UTF-8') + '/envelopes'
        );
        req.setHeader('Authorization', 'Bearer ' + auth.accessToken);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(reqBody));

        HttpResponse res = new Http().send(req);

        EnvelopeDispatchResult result = new EnvelopeDispatchResult();
        result.success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
        result.rawResponse = res.getBody();
        result.accountId = auth.accountId;
        result.baseUri = auth.baseUri;

        if (!result.success) {
            String err = 'DocuSign envelope create error (' + res.getStatusCode() + '): ' + safeBody(res.getBody());
            markOpportunityError(opp.Id, err);
            throw new DocuSignEnvelopeException(err);
        }

        Map<String, Object> respBody = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        result.envelopeId = (String) respBody.get('envelopeId');
        result.status = (String) respBody.get('status');
        result.message = 'Envelope sent.';

        if (String.isBlank(result.envelopeId)) {
            markOpportunityError(opp.Id, 'DocuSign response missing envelopeId.');
            throw new DocuSignEnvelopeException('DocuSign response missing envelopeId.');
        }

        upsertEnvelopeAndOpportunity(
            opp,
            result.envelopeId,
            String.isNotBlank(result.status) ? result.status : 'sent',
            candidate,
            usesDocuSignTemplate ? templateId : null,
            result.rawResponse
        );

        return result;
    }

    public static Blob downloadCombinedSignedPdf(String envelopeId) {
        if (String.isBlank(envelopeId)) {
            throw new DocuSignEnvelopeException('envelopeId is required.');
        }

        DocuSignAuthService.AuthResult auth = DocuSignAuthService.authenticate();

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(
            auth.baseUri + '/restapi/v2.1/accounts/' +
            EncodingUtil.urlEncode(auth.accountId, 'UTF-8') + '/envelopes/' +
            EncodingUtil.urlEncode(envelopeId, 'UTF-8') + '/documents/combined'
        );
        req.setHeader('Authorization', 'Bearer ' + auth.accessToken);
        req.setHeader('Accept', 'application/pdf');
        req.setTimeout(120000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new DocuSignEnvelopeException(
                'DocuSign download error (' + res.getStatusCode() + '): ' + safeBody(res.getBody())
            );
        }

        return res.getBodyAsBlob();
    }

    @TestVisible
    public static void markOpportunityError(Id oppId, String errorMsg) {
        if (oppId == null) return;
        Opportunity patch = new Opportunity(Id = oppId);
        patch.Contract_Status__c = 'Failed';
        patch.Contract_Error__c = safeTrim(errorMsg, 32768);
        Decimal attempts = 0;

        List<Opportunity> existing = [
            SELECT Id, Contract_Attempts__c
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];
        if (!existing.isEmpty() && existing[0].Contract_Attempts__c != null) {
            attempts = existing[0].Contract_Attempts__c;
        }
        patch.Contract_Attempts__c = attempts + 1;

        update patch;

        createAuditLog('DOCUSIGN_SEND_FAILED', 'CRITICAL', safeTrim(errorMsg, 32000), oppId);
    }

    @TestVisible
    static void setTestContractPdfBlob(Blob pdfBlob) {
        testContractPdfBlob = pdfBlob;
    }

    private static String resolveTemplateId(Opportunity opp, DocuSignConfigService.Config cfg) {
        if (String.isNotBlank(opp.Contract_Template_Id__c)) {
            return opp.Contract_Template_Id__c;
        }
        return cfg.defaultTemplateId;
    }

    private static Map<String, Object> buildTemplateEnvelopeRequest(
        Opportunity opp,
        CandidateInfo candidate,
        DocuSignConfigService.Config cfg,
        String templateId
    ) {
        return new Map<String, Object>{
            'templateId' => templateId,
            'templateRoles' => new List<Object>{
                new Map<String, Object>{
                    'email' => candidate.email,
                    'name' => candidate.getFullName(),
                    'roleName' => cfg.signerRoleName
                }
            },
            'status' => 'sent',
            'emailSubject' => 'Contrat de travail - ' + opp.Name,
            'customFields' => buildCustomFields(opp.Id)
        };
    }

    private static Map<String, Object> buildVisualforceEnvelopeRequest(
        Opportunity opp,
        CandidateInfo candidate
    ) {
        Blob pdfBlob = buildContractPdf(opp, candidate);

        return new Map<String, Object>{
            'emailSubject' => 'Contrat de travail - ' + opp.Name,
            'status' => 'sent',
            'customFields' => buildCustomFields(opp.Id),
            'documents' => new List<Object>{
                new Map<String, Object>{
                    'documentBase64' => EncodingUtil.base64Encode(pdfBlob),
                    'name' => buildContractFileName(opp.Name),
                    'fileExtension' => 'pdf',
                    'documentId' => '1'
                }
            },
            'recipients' => new Map<String, Object>{
                'signers' => new List<Object>{
                    new Map<String, Object>{
                        'email' => candidate.email,
                        'name' => candidate.getFullName(),
                        'recipientId' => '1',
                        'routingOrder' => '1',
                        'tabs' => new Map<String, Object>{
                            'signHereTabs' => new List<Object>{
                                new Map<String, Object>{
                                    'anchorString' => SIGN_ANCHOR,
                                    'anchorUnits' => 'pixels',
                                    'anchorXOffset' => '0',
                                    'anchorYOffset' => '0'
                                }
                            }
                        }
                    }
                }
            }
        };
    }

    private static Map<String, Object> buildCustomFields(Id oppId) {
        return new Map<String, Object>{
            'textCustomFields' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'salesforceOpportunityId',
                    'value' => String.valueOf(oppId),
                    'show' => 'false'
                }
            }
        };
    }

    private static Blob buildContractPdf(Opportunity opp, CandidateInfo candidate) {
        if (Test.isRunningTest()) {
            return testContractPdfBlob == null ? Blob.valueOf('TEST_PDF') : testContractPdfBlob;
        }

        try {
            PageReference pageRef = Page.ContractTemplate;
            pageRef.getParameters().put('id', String.valueOf(opp.Id));
            pageRef.getParameters().put('candidateName', candidate.getFullName());
            pageRef.getParameters().put('candidateEmail', candidate.email);
            pageRef.getParameters().put('generatedOn', Date.today().format());
            return pageRef.getContentAsPDF();
        } catch (Exception ex) {
            throw new DocuSignEnvelopeException('Unable to render Visualforce contract PDF: ' + ex.getMessage());
        }
    }

    private static String buildContractFileName(String oppName) {
        String token = sanitizeFileToken(oppName);
        if (String.isBlank(token)) {
            token = 'candidature';
        }
        return 'Contrat_' + token + '.pdf';
    }

    private static String sanitizeFileToken(String input) {
        if (String.isBlank(input)) return null;

        String compact = input.trim().replaceAll('[\\s]+', '_');
        String safe = compact.replaceAll('[^A-Za-z0-9_-]', '');

        if (safe.length() > 80) {
            safe = safe.substring(0, 80);
        }
        return safe;
    }

    private static void upsertEnvelopeAndOpportunity(
        Opportunity opp,
        String envelopeId,
        String envelopeStatus,
        CandidateInfo candidate,
        String templateId,
        String rawResponse
    ) {
        Opportunity patch = new Opportunity(Id = opp.Id);
        patch.DocuSign_Envelope_Id__c = envelopeId;
        patch.Contract_Status__c = normalizeContractStatus(envelopeStatus);
        patch.Contract_Sent_At__c = System.now();
        patch.Contract_Error__c = null;
        patch.Contract_Attempts__c = (opp.Contract_Attempts__c == null ? 0 : opp.Contract_Attempts__c) + 1;
        update patch;

        DocuSign_Envelope__c env = new DocuSign_Envelope__c();
        env.Envelope_Id__c = envelopeId;
        env.Opportunity__c = opp.Id;
        env.Status__c = envelopeStatus;
        env.Recipient_Email__c = candidate.email;
        env.Recipient_Name__c = candidate.getFullName();
        env.Template_Id__c = templateId;
        env.Sent_At__c = System.now();
        env.Error_Message__c = null;
        env.Raw_Last_Response__c = safeTrim(rawResponse, 131072);
        upsert env Envelope_Id__c;

        createAuditLog('DOCUSIGN_ENVELOPE_SENT', 'INFO',
            'EnvelopeId=' + envelopeId + ' | Candidate=' + candidate.email,
            opp.Id
        );
    }

    private static CandidateInfo resolveCandidate(Opportunity opp) {
        CandidateInfo out = new CandidateInfo();

        List<Lead> leads = [
            SELECT FirstName, LastName, Email
            FROM Lead
            WHERE ConvertedOpportunityId = :opp.Id
            LIMIT 1
        ];
        if (!leads.isEmpty() && String.isNotBlank(leads[0].Email)) {
            out.email = leads[0].Email;
            out.firstName = leads[0].FirstName;
            out.lastName = leads[0].LastName;
            return out;
        }

        List<OpportunityContactRole> ocrs = [
            SELECT Contact.FirstName, Contact.LastName, Contact.Email
            FROM OpportunityContactRole
            WHERE OpportunityId = :opp.Id
              AND Contact.Email != null
            LIMIT 1
        ];
        if (!ocrs.isEmpty()) {
            out.email = ocrs[0].Contact.Email;
            out.firstName = ocrs[0].Contact.FirstName;
            out.lastName = ocrs[0].Contact.LastName;
            return out;
        }

        if (opp.AccountId != null) {
            List<Contact> contacts = [
                SELECT FirstName, LastName, Email
                FROM Contact
                WHERE AccountId = :opp.AccountId
                  AND Email != null
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                out.email = contacts[0].Email;
                out.firstName = contacts[0].FirstName;
                out.lastName = contacts[0].LastName;
                return out;
            }
        }

        return out;
    }

    private static String normalizeContractStatus(String raw) {
        String s = raw == null ? '' : raw.trim().toLowerCase();
        if (s == 'sent' || s == 'created' || s == 'delivered') return 'Sent';
        if (s == 'completed' || s == 'signed') return 'Completed';
        if (s == 'declined') return 'Declined';
        if (s == 'voided') return 'Voided';
        if (s == 'failed') return 'Failed';
        return 'Sent';
    }

    private static Boolean isActiveEnvelopeStatus(String statusValue) {
        if (String.isBlank(statusValue)) return false;
        String s = statusValue.trim().toLowerCase();
        return s == 'sent' || s == 'queued' || s == 'created' || s == 'delivered';
    }

    private static EnvelopeDispatchResult buildNoop(String message) {
        EnvelopeDispatchResult result = new EnvelopeDispatchResult();
        result.success = true;
        result.message = message;
        result.status = 'noop';
        return result;
    }

    private static String safeBody(String body) {
        if (body == null) return '';
        return body.length() > 900 ? body.substring(0, 900) : body;
    }

    private static String safeTrim(String input, Integer max) {
        if (input == null) return null;
        if (max == null || max <= 0) return input;
        return input.length() > max ? input.substring(0, max) : input;
    }

    private static void createAuditLog(String action, String severity, String details, Id oppId) {
        try {
            Security_Audit_Log__c log = new Security_Audit_Log__c(
                Action__c = action,
                Severity__c = severity,
                Timestamp__c = System.now(),
                Email__c = UserInfo.getUserEmail(),
                Details__c =
                    (details != null ? details : '') +
                    (oppId != null ? (' | OpportunityId=' + String.valueOf(oppId)) : '')
            );
            insert log;
        } catch (Exception ex) {
            System.debug('DocuSign audit log insert failed: ' + ex.getMessage());
        }
    }
}
