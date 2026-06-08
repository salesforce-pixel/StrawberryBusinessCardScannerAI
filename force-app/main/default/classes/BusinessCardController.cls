/**
 * Business Card Scanner — Lead controller.
 *
 * Aura endpoints for the businessCardScanner LWC: extract card data via the
 * Einstein prompt template, find a matching Lead, and create/update Leads.
 *
 * @author Rajeev Shekhar
 */
public with sharing class BusinessCardController {

    // ----------------------------------------------------------
    // STEP 1 — Call Einstein prompt template → returns JSON string
    // ----------------------------------------------------------
    /**
     * Extracts structured contact data from an uploaded business card image.
     *
     * @param contentDocumentId ContentDocumentId of the uploaded card image
     * @return Raw extraction output (JSON string) from the prompt template
     */
    @AuraEnabled
    public static String extractFromCard(String contentDocumentId) {
        return AI_businessCardAnalyzer.extractInformation(contentDocumentId);
    }

    // ----------------------------------------------------------
    // STEP 2 — Search for an existing (non-converted) Lead by email
    // ----------------------------------------------------------
    /**
     * Finds an open (non-converted) Lead matching the given email.
     *
     * @param email Email address to match
     * @return The matching Lead, or null if none / no email supplied
     */
    @AuraEnabled
    public static Lead findLead(String email) {
        if (String.isBlank(email)) {
            return null;
        }

        List<Lead> leads = [
            SELECT Id, Name, Company, Email
            FROM Lead
            WHERE Email = :email.trim()
              AND IsConverted = false
            WITH USER_MODE
            LIMIT 1
        ];
        return leads.isEmpty() ? null : leads[0];
    }

    // ----------------------------------------------------------
    // STEP 3A — Create a new Lead from extracted card JSON
    // ----------------------------------------------------------
    /**
     * Creates a new Lead from extracted card JSON.
     *
     * @param extractedJson Normalized card data as a JSON string
     * @return The Id of the newly created Lead
     * @throws AuraHandledException if the data is unreadable or the save fails
     */
    @AuraEnabled
    public static Id createLead(String extractedJson) {
        Lead l = new Lead();
        applyCardData(l, parse(extractedJson));
        try {
            Database.insert(l, AccessLevel.USER_MODE);
        } catch (DmlException e) {
            throw new AuraHandledException('Could not create the lead: ' + e.getDmlMessage(0));
        }
        return l.Id;
    }

    // ----------------------------------------------------------
    // STEP 3B — Update an existing Lead from extracted card JSON
    // ----------------------------------------------------------
    /**
     * Updates an existing Lead from extracted card JSON.
     *
     * @param extractedJson Normalized card data as a JSON string
     * @param existingLeadId Id of the Lead to update
     * @return The Id of the updated Lead
     * @throws AuraHandledException if the data is unreadable or the save fails
     */
    @AuraEnabled
    public static Id updateLead(String extractedJson, Id existingLeadId) {
        Lead l = new Lead(Id = existingLeadId);
        applyCardData(l, parse(extractedJson));
        try {
            Database.update(l, AccessLevel.USER_MODE);
        } catch (DmlException e) {
            throw new AuraHandledException('Could not update the lead: ' + e.getDmlMessage(0));
        }
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
     *
     * @param l Lead record to populate
     * @param data Normalized card data keyed by field name
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

    /**
     * Trims a JSON value and converts blanks/"null" to null.
     *
     * @param value Raw value from the parsed JSON map
     * @return The trimmed string, or null if blank or literally "null"
     */
    private static String str(Object value) {
        if (value == null) {
            return null;
        }
        String s = String.valueOf(value).trim();
        if (String.isBlank(s) || s.equalsIgnoreCase('null')) {
            return null;
        }
        return s;
    }

    /**
     * Company is required on Lead — fall back to the email domain.
     *
     * @param email Email address to derive a company name from
     * @return The email domain, or 'Unknown' if no usable email
     */
    private static String companyFromEmail(String email) {
        if (String.isBlank(email) || !email.contains('@')) {
            return 'Unknown';
        }
        return email.substringAfter('@');
    }

    /**
     * Captures fields that have no standard Lead home (LinkedIn) plus provenance.
     *
     * @param data Normalized card data keyed by field name
     * @return A multi-line description string for the Lead
     */
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