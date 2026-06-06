public with sharing class BusinessCardController {

    // ----------------------------------------------------------
    // STEP 1 — Call Einstein prompt template → returns JSON string
    // ----------------------------------------------------------
    @AuraEnabled
    public static String extractFromCard(String contentDocumentId) {
        return AI_businessCardAnalyzer.extractInformation(contentDocumentId);
    }

    // ----------------------------------------------------------
    // STEP 2 — Search for an existing (non-converted) Lead by email
    // ----------------------------------------------------------
    @AuraEnabled
    public static Lead findLead(String email) {
        if (String.isBlank(email)) return null;

        List<Lead> leads = [
            SELECT Id, Name, Company, Email
            FROM Lead
            WHERE Email = :email.trim()
              AND IsConverted = false
            LIMIT 1
        ];
        return leads.isEmpty() ? null : leads[0];
    }

    // ----------------------------------------------------------
    // STEP 3A — Create a new Lead from extracted card JSON
    // ----------------------------------------------------------
    @AuraEnabled
    public static Id createLead(String extractedJson) {
        Lead l = new Lead();
        applyCardData(l, parse(extractedJson));
        insert l;
        return l.Id;
    }

    // ----------------------------------------------------------
    // STEP 3B — Update an existing Lead from extracted card JSON
    // ----------------------------------------------------------
    @AuraEnabled
    public static Id updateLead(String extractedJson, Id existingLeadId) {
        Lead l = new Lead(Id = existingLeadId);
        applyCardData(l, parse(extractedJson));
        update l;
        return l.Id;
    }

    // ----------------------------------------------------------
    // Shared helpers
    // ----------------------------------------------------------

    private static Map<String, Object> parse(String extractedJson) {
        if (String.isBlank(extractedJson)) {
            throw new AuraHandledException('No card data was provided to save.');
        }
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(extractedJson);
        } catch (Exception e) {
            throw new AuraHandledException('Could not read the extracted card data: ' + e.getMessage());
        }
    }

    /**
     * Maps the normalized card JSON onto a Lead. Standard Lead required fields
     * (LastName, Company) are defaulted so the save never fails on missing data.
     */
    private static void applyCardData(Lead l, Map<String, Object> data) {
        String firstName = str(data.get('firstName'));
        String lastName  = str(data.get('lastName'));
        String company   = str(data.get('company'));
        String email     = str(data.get('email'));

        l.FirstName   = firstName;
        l.LastName    = String.isNotBlank(lastName) ? lastName : 'Unknown';
        l.Title       = str(data.get('jobTitle'));
        l.Company     = String.isNotBlank(company) ? company : companyFromEmail(email);
        l.Email       = email;
        l.Phone       = str(data.get('phone'));
        l.MobilePhone = str(data.get('mobile'));
        l.Website     = str(data.get('website'));
        l.Street      = str(data.get('street'));
        l.City        = str(data.get('city'));
        l.State       = str(data.get('state'));
        l.PostalCode  = str(data.get('postalCode'));
        l.Country     = str(data.get('country'));
        l.Description  = buildDescription(data);
    }

    /** Trims a JSON value and converts blanks/"null" to null. */
    private static String str(Object value) {
        if (value == null) return null;
        String s = String.valueOf(value).trim();
        if (String.isBlank(s) || s.equalsIgnoreCase('null')) return null;
        return s;
    }

    /** Company is required on Lead — fall back to the email domain. */
    private static String companyFromEmail(String email) {
        if (String.isBlank(email) || !email.contains('@')) return 'Unknown';
        return email.substringAfter('@');
    }

    /** Captures fields that have no standard Lead home (LinkedIn) plus provenance. */
    private static String buildDescription(Map<String, Object> data) {
        List<String> parts = new List<String>();
        String linkedin = str(data.get('linkedin'));
        if (String.isNotBlank(linkedin)) {
            parts.add('LinkedIn: ' + linkedin);
        }
        parts.add('Lead created from a business card scan (AI extraction).');
        return String.join(parts, '\n');
    }
}
