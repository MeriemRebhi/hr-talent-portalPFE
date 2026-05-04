@RestResource(urlMapping='/docusign/webhook')
global without sharing class DocuSignWebhookRest {

    public class DocuSignWebhookException extends Exception {}

    public class ProcessResult {
        Id opportunityId;
        Id envelopeRecordId;
    }

    @HttpPost
    global static void handleWebhook() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        String payload = req != null && req.requestBody != null ? req.requestBody.toString() : '';
        String signatureHeader = req != null && req.headers != null
            ? req.headers.get('X-DocuSign-Signature-1')
            : null;

        DocuSignConfigService.Config cfg = DocuSignConfigService.getConfig();
        Boolean signatureValidationEnabled = cfg != null && String.isNotBlank(cfg.webhookSecret);
        Boolean signatureValid = !signatureValidationEnabled || verifyHmac(payload, signatureHeader, cfg.webhookSecret);

        Map<String, String> eventData = extractEvent(payload);
        String envelopeId = eventData.get('envelopeId');
        String eventType = eventData.get('eventType');
        String eventStatus = eventData.get('status');

        DocuSignWebhookEvent__c eventLog = new DocuSignWebhookEvent__c();
        eventLog.Envelope_Id__c = envelopeId;
        eventLog.Event_Type__c = eventType;
        eventLog.Event_Status__c = eventStatus;
        eventLog.Received_At__c = System.now();
        eventLog.Signature_Valid__c = signatureValid;
        eventLog.Payload__c = safeTrim(payload, 131072);
        eventLog.Processed__c = false;

        if (!signatureValid) {
            eventLog.Processing_Error__c = 'Invalid DocuSign webhook signature.';
            insert eventLog;

            res.statusCode = 401;
            res.responseBody = Blob.valueOf('INVALID_SIGNATURE');
            return;
        }

        try {
            ProcessResult proc = processWebhook(envelopeId, eventStatus, payload);
            eventLog.Processed__c = true;
            eventLog.Processing_Error__c = null;
            eventLog.Opportunity__c = proc != null ? proc.opportunityId : null;
            eventLog.Envelope__c = proc != null ? proc.envelopeRecordId : null;

            insert eventLog;

            res.statusCode = 200;
            res.responseBody = Blob.valueOf('OK');
        } catch (Exception ex) {
            eventLog.Processed__c = false;
            eventLog.Processing_Error__c = safeTrim(ex.getMessage(), 32768);
            insert eventLog;

            res.statusCode = 500;
            res.responseBody = Blob.valueOf('ERROR');
        }
    }

    @TestVisible
    private static ProcessResult processWebhook(String envelopeId, String eventStatus, String payload) {
        if (String.isBlank(envelopeId)) {
            throw new DocuSignWebhookException('DocuSign webhook missing envelopeId.');
        }

        String normalizedStatus = normalizeStatus(eventStatus);
        if (String.isBlank(normalizedStatus)) {
            normalizedStatus = inferStatusFromPayload(payload);
        }
        if (String.isBlank(normalizedStatus)) {
            normalizedStatus = 'sent';
        }

        DocuSign_Envelope__c envelopeRecord;
        List<DocuSign_Envelope__c> existing = [
            SELECT Id,
                   Opportunity__c,
                   Envelope_Id__c,
                   Status__c,
                   Sent_At__c,
                   Completed_At__c,
                   Last_Webhook_At__c,
                   Error_Message__c,
                   Raw_Last_Response__c
            FROM DocuSign_Envelope__c
            WHERE Envelope_Id__c = :envelopeId
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            envelopeRecord = new DocuSign_Envelope__c(
                Envelope_Id__c = envelopeId,
                Status__c = normalizedStatus,
                Last_Webhook_At__c = System.now(),
                Raw_Last_Response__c = safeTrim(payload, 131072)
            );
            insert envelopeRecord;
        } else {
            envelopeRecord = existing[0];
            envelopeRecord.Status__c = normalizedStatus;
            envelopeRecord.Last_Webhook_At__c = System.now();
            envelopeRecord.Raw_Last_Response__c = safeTrim(payload, 131072);
            if (normalizedStatus == 'completed') {
                envelopeRecord.Completed_At__c = System.now();
            }
            if (normalizedStatus == 'sent' && envelopeRecord.Sent_At__c == null) {
                envelopeRecord.Sent_At__c = System.now();
            }
            envelopeRecord.Error_Message__c = null;
            update envelopeRecord;
        }

        Id opportunityId = envelopeRecord.Opportunity__c;

        if (opportunityId == null) {
            List<Opportunity> opps = [
                SELECT Id
                FROM Opportunity
                WHERE DocuSign_Envelope_Id__c = :envelopeId
                LIMIT 1
            ];
            if (!opps.isEmpty()) {
                opportunityId = opps[0].Id;
                envelopeRecord.Opportunity__c = opportunityId;
                update envelopeRecord;
            }
        }

        if (opportunityId != null) {
            Opportunity patch = new Opportunity(Id = opportunityId);
            patch.Contract_Status__c = mapToContractStatus(normalizedStatus);
            patch.Contract_Error__c = null;

            if (normalizedStatus == 'sent') {
                patch.Contract_Sent_At__c = System.now();
            } else if (normalizedStatus == 'completed') {
                patch.Contract_Signed_At__c = System.now();
            }

            update patch;

            if (normalizedStatus == 'completed') {
                System.enqueueJob(new DocuSignEnvelopeCompletionJob(envelopeId));
            }
        }

        ProcessResult out = new ProcessResult();
        out.opportunityId = opportunityId;
        out.envelopeRecordId = envelopeRecord.Id;
        return out;
    }

    @TestVisible
    private static Map<String, String> extractEvent(String payload) {
        Map<String, String> out = new Map<String, String>{
            'envelopeId' => null,
            'eventType' => null,
            'status' => null
        };

        if (String.isBlank(payload)) {
            return out;
        }

        String p = payload.trim();

        if (p.startsWith('{') || p.startsWith('[')) {
            try {
                Object raw = JSON.deserializeUntyped(p);
                extractFromJson(raw, out);
            } catch (Exception ex) {
                // Fallback to regex parsing below.
            }
        }

        if (String.isBlank(out.get('envelopeId'))) {
            out.put('envelopeId', regexCapture(payload, '(?is)"envelopeId"\\s*:\\s*"([^"]+)"'));
            if (String.isBlank(out.get('envelopeId'))) {
                out.put('envelopeId', regexCapture(payload, '(?is)<(?:envelopeId|envelopeID)>\\s*([^<\\s]+)\\s*</(?:envelopeId|envelopeID)>'));
            }
        }

        if (String.isBlank(out.get('eventType'))) {
            out.put('eventType', regexCapture(payload, '(?is)"event"\\s*:\\s*"([^"]+)"'));
            if (String.isBlank(out.get('eventType'))) {
                out.put('eventType', regexCapture(payload, '(?is)<event>\\s*([^<]+)\\s*</event>'));
            }
        }

        if (String.isBlank(out.get('status'))) {
            out.put('status', regexCapture(payload, '(?is)"status"\\s*:\\s*"([^"]+)"'));
            if (String.isBlank(out.get('status'))) {
                out.put('status', regexCapture(payload, '(?is)<envelopeStatus>.*?<status>\\s*([^<]+)\\s*</status>'));
            }
            if (String.isBlank(out.get('status'))) {
                out.put('status', regexCapture(payload, '(?is)<status>\\s*([^<]+)\\s*</status>'));
            }
        }

        if (String.isBlank(out.get('status')) && String.isNotBlank(out.get('eventType'))) {
            out.put('status', deriveStatusFromEventType(out.get('eventType')));
        }

        return out;
    }

    private static void extractFromJson(Object raw, Map<String, String> out) {
        if (raw == null) return;

        if (raw instanceof Map<String, Object>) {
            Map<String, Object> m = (Map<String, Object>) raw;

            if (String.isBlank(out.get('eventType')) && m.containsKey('event')) {
                out.put('eventType', stringOrNull(m.get('event')));
            }
            if (String.isBlank(out.get('status')) && m.containsKey('status')) {
                out.put('status', stringOrNull(m.get('status')));
            }
            if (String.isBlank(out.get('envelopeId')) && m.containsKey('envelopeId')) {
                out.put('envelopeId', stringOrNull(m.get('envelopeId')));
            }

            if (m.containsKey('data') && m.get('data') != null) {
                extractFromJson(m.get('data'), out);
            }
            if (m.containsKey('envelopeSummary') && m.get('envelopeSummary') != null) {
                extractFromJson(m.get('envelopeSummary'), out);
            }
            if (m.containsKey('envelopeStatus') && m.get('envelopeStatus') != null) {
                extractFromJson(m.get('envelopeStatus'), out);
            }

            for (String key : m.keySet()) {
                if (String.isNotBlank(out.get('envelopeId')) && String.isNotBlank(out.get('status')) && String.isNotBlank(out.get('eventType'))) {
                    break;
                }
                Object child = m.get(key);
                if (child instanceof Map<String, Object> || child instanceof List<Object>) {
                    extractFromJson(child, out);
                }
            }
            return;
        }

        if (raw instanceof List<Object>) {
            for (Object item : (List<Object>) raw) {
                extractFromJson(item, out);
                if (String.isNotBlank(out.get('envelopeId')) && String.isNotBlank(out.get('status')) && String.isNotBlank(out.get('eventType'))) {
                    break;
                }
            }
        }
    }

    private static String inferStatusFromPayload(String payload) {
        Map<String, String> data = extractEvent(payload);
        if (String.isNotBlank(data.get('status'))) {
            return normalizeStatus(data.get('status'));
        }
        if (String.isNotBlank(data.get('eventType'))) {
            return normalizeStatus(deriveStatusFromEventType(data.get('eventType')));
        }
        return null;
    }

    private static String deriveStatusFromEventType(String eventType) {
        if (String.isBlank(eventType)) return null;
        String e = eventType.trim().toLowerCase();
        if (e.contains('completed') || e.contains('signed')) return 'completed';
        if (e.contains('declined')) return 'declined';
        if (e.contains('voided')) return 'voided';
        if (e.contains('sent') || e.contains('created') || e.contains('delivered')) return 'sent';
        return null;
    }

    private static String normalizeStatus(String raw) {
        if (String.isBlank(raw)) return null;
        String s = raw.trim().toLowerCase();
        if (s == 'completed' || s == 'signed') return 'completed';
        if (s == 'declined') return 'declined';
        if (s == 'voided') return 'voided';
        if (s == 'sent' || s == 'created' || s == 'delivered') return 'sent';
        return s;
    }

    private static String mapToContractStatus(String normalizedStatus) {
        String s = normalizedStatus == null ? '' : normalizedStatus.trim().toLowerCase();
        if (s == 'completed') return 'Completed';
        if (s == 'declined') return 'Declined';
        if (s == 'voided') return 'Voided';
        if (s == 'failed') return 'Failed';
        return 'Sent';
    }

    @TestVisible
    private static Boolean verifyHmac(String payload, String signatureHeader, String secret) {
        if (String.isBlank(secret)) return true;
        if (String.isBlank(signatureHeader)) return false;

        Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(payload == null ? '' : payload), Blob.valueOf(secret));
        String expected = EncodingUtil.base64Encode(mac);

        return constantTimeEquals(expected, signatureHeader.trim());
    }

    private static Boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        return a == b;
    }

    private static String stringOrNull(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static String regexCapture(String input, String patternText) {
        if (String.isBlank(input) || String.isBlank(patternText)) return null;
        Pattern p = Pattern.compile(patternText);
        Matcher m = p.matcher(input);
        return m.find() ? m.group(1) : null;
    }

    private static String safeTrim(String input, Integer maxLen) {
        if (input == null) return null;
        if (maxLen == null || maxLen <= 0) return input;
        return input.length() > maxLen ? input.substring(0, maxLen) : input;
    }
}





