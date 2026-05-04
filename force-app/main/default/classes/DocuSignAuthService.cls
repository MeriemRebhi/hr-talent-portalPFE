public with sharing class DocuSignAuthService {

    public class AuthResult {
        public String accessToken;
        public String tokenType;
        public Integer expiresIn;
        public String accountId;
        public String baseUri;
    }

    public class DocuSignAuthException extends Exception {}

    @TestVisible
    private static AuthResult testAuthResult;

    public static AuthResult authenticate() {
        if (Test.isRunningTest() && testAuthResult != null) {
            return testAuthResult;
        }
        DocuSignConfigService.Config cfg = DocuSignConfigService.getConfigOrThrow();

        String assertion = buildJwtAssertion(cfg);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(normalizeHost(cfg.oauthBaseUri) + '/oauth/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setTimeout(120000);
        req.setBody(
            'grant_type=' + EncodingUtil.urlEncode('urn:ietf:params:oauth:grant-type:jwt-bearer', 'UTF-8')
            + '&assertion=' + EncodingUtil.urlEncode(assertion, 'UTF-8')
        );

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new DocuSignAuthException(
                'DocuSign token error (' + res.getStatusCode() + '): ' + safeBody(res.getBody())
            );
        }

        Map<String, Object> tokenResp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String accessToken = (String) tokenResp.get('access_token');
        if (String.isBlank(accessToken)) {
            throw new DocuSignAuthException('DocuSign token response did not include access_token.');
        }

        AuthResult out = new AuthResult();
        out.accessToken = accessToken;
        out.tokenType = (String) tokenResp.get('token_type');
        out.expiresIn = tokenResp.containsKey('expires_in') ? Integer.valueOf(String.valueOf(tokenResp.get('expires_in'))) : 0;

        Map<String, String> accountInfo = fetchAccountInfo(cfg, accessToken);
        out.accountId = accountInfo.get('accountId');
        out.baseUri = accountInfo.get('baseUri');

        if (String.isBlank(out.accountId)) {
            out.accountId = cfg.accountId;
        }
        if (String.isBlank(out.baseUri)) {
            out.baseUri = cfg.baseUri;
        }

        out.baseUri = normalizeHost(out.baseUri);

        return out;
    }

    @TestVisible
    static void setTestAuthResult(AuthResult authResult) {
        testAuthResult = authResult;
    }

    private static Map<String, String> fetchAccountInfo(DocuSignConfigService.Config cfg, String token) {
        Map<String, String> out = new Map<String, String>{
            'accountId' => cfg.accountId,
            'baseUri' => cfg.baseUri
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(normalizeHost(cfg.oauthBaseUri) + '/oauth/userinfo');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setTimeout(120000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            return out;
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (payload == null || !payload.containsKey('accounts')) {
            return out;
        }

        List<Object> accounts = (List<Object>) payload.get('accounts');
        if (accounts == null || accounts.isEmpty()) {
            return out;
        }

        Map<String, Object> selected = null;

        if (String.isNotBlank(cfg.accountId)) {
            for (Object o : accounts) {
                Map<String, Object> a = (Map<String, Object>) o;
                String accountId = a.containsKey('account_id') ? String.valueOf(a.get('account_id')) : null;
                if (accountId == cfg.accountId) {
                    selected = a;
                    break;
                }
            }
        }

        if (selected == null) {
            for (Object o : accounts) {
                Map<String, Object> a = (Map<String, Object>) o;
                if (a.containsKey('is_default') && (Boolean) a.get('is_default') == true) {
                    selected = a;
                    break;
                }
            }
        }

        if (selected == null) {
            selected = (Map<String, Object>) accounts[0];
        }

        if (selected.containsKey('account_id')) {
            out.put('accountId', String.valueOf(selected.get('account_id')));
        }
        if (selected.containsKey('base_uri')) {
            out.put('baseUri', String.valueOf(selected.get('base_uri')));
        }

        return out;
    }

    private static String buildJwtAssertion(DocuSignConfigService.Config cfg) {
        Long now = DateTime.now().getTime() / 1000;

        Map<String, Object> header = new Map<String, Object>{
            'alg' => 'RS256',
            'typ' => 'JWT'
        };
        Map<String, Object> payload = new Map<String, Object>{
            'iss' => cfg.integrationKey,
            'sub' => cfg.userId,
            'aud' => oauthAudience(cfg.oauthBaseUri),
            'scope' => 'signature impersonation',
            'iat' => now,
            'exp' => now + 3600
        };

        String encodedHeader = toBase64Url(Blob.valueOf(JSON.serialize(header)));
        String encodedPayload = toBase64Url(Blob.valueOf(JSON.serialize(payload)));
        String unsignedToken = encodedHeader + '.' + encodedPayload;

        Blob keyBlob = pemToBlob(cfg.privateKeyPem);
        Blob signature = Crypto.sign('RSA-SHA256', Blob.valueOf(unsignedToken), keyBlob);

        return unsignedToken + '.' + toBase64Url(signature);
    }

    private static Blob pemToBlob(String pem) {
        if (String.isBlank(pem)) {
            throw new DocuSignAuthException('Private key is empty.');
        }

        String cleaned = pem
            .replace('-----BEGIN RSA PRIVATE KEY-----', '')
            .replace('-----END RSA PRIVATE KEY-----', '')
            .replace('-----BEGIN PRIVATE KEY-----', '')
            .replace('-----END PRIVATE KEY-----', '')
            .replace('\n', '')
            .replace('\r', '')
            .replace(' ', '');

        try {
            return EncodingUtil.base64Decode(cleaned);
        } catch (Exception ex) {
            throw new DocuSignAuthException('Private key format is invalid: ' + ex.getMessage());
        }
    }
    private static String oauthAudience(String oauthBaseUri) {
        String host = normalizeHost(oauthBaseUri);
        if (String.isBlank(host)) return null;

        if (host.startsWith('https://')) {
            host = host.substring(8);
        } else if (host.startsWith('http://')) {
            host = host.substring(7);
        }

        Integer slashPos = host.indexOf('/');
        if (slashPos > -1) {
            host = host.substring(0, slashPos);
        }

        return host;
    }
    private static String toBase64Url(Blob input) {
        return EncodingUtil.base64Encode(input)
            .replace('+', '-')
            .replace('/', '_')
            .replace('=', '');
    }

    private static String normalizeHost(String host) {
        if (String.isBlank(host)) return null;
        String out = host.trim();
        while (out.endsWith('/')) {
            out = out.substring(0, out.length() - 1);
        }
        return out;
    }

    private static String safeBody(String body) {
        if (body == null) return '';
        return body.length() > 900 ? body.substring(0, 900) : body;
    }
}




