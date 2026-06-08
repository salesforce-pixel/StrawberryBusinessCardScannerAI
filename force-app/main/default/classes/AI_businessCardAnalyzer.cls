/**
 * Business Card Scanner — Einstein extraction.
 *
 * Calls the "Business_Card_Scanner_Prompt" Einstein prompt template to extract
 * structured contact details from a business card image.
 *
 * @author Rajeev Shekhar
 */
public with sharing class AI_businessCardAnalyzer {

    private static final String PROMPT_TEMPLATE = 'Business_Card_Scanner_Prompt';
    private static final String APPLICATION_NAME = 'PromptTemplateGenerationsInvocable';

    /**
     * Runs the business card prompt template against an uploaded image and
     * returns the raw model output (expected to be a JSON string).
     *
     * @param fileId ContentDocumentId of the uploaded business card image
     * @return The model-generated text for the first generation
     * @throws AuraHandledException if no file is provided or the LLM call fails
     */
    public static String extractInformation(String fileId) {
        if (String.isBlank(fileId)) {
            throw new AuraHandledException('No business card image was provided to scan.');
        }

        try {
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(PROMPT_TEMPLATE, buildInput(fileId));

            if (isEmptyResult(result)) {
                throw new AuraHandledException('The AI did not return any data for this business card.');
            }

            return result.generations[0].text;

        } catch (AuraHandledException e) {
            // Already user-facing — preserve as-is.
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Could not analyze the business card: ' + e.getMessage());
        }
    }

    /**
     * Checks whether a prompt template result contains any usable generations.
     *
     * @param result Representation returned by the prompt template call
     * @return true if the result carries no usable generations
     */
    private static Boolean isEmptyResult(ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result) {
        return result == null || result.generations == null || result.generations.isEmpty();
    }

    /**
     * Builds the prompt template input wrapping the uploaded image reference.
     *
     * @param fileId ContentDocumentId of the uploaded business card image
     * @return A populated generations input for the prompt template call
     */
    private static ConnectApi.EinsteinPromptTemplateGenerationsInput buildInput(String fileId) {
        ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        promptInput.isPreview = false;

        // Wrap the image reference as the prompt input
        Map<String, String> imageMap = new Map<String, String>();
        imageMap.put('id', fileId);

        ConnectApi.WrappedValue wrappedImage = new ConnectApi.WrappedValue();
        wrappedImage.value = imageMap;

        Map<String, ConnectApi.WrappedValue> inputValues = new Map<String, ConnectApi.WrappedValue>();
        inputValues.put('Input:Image', wrappedImage);

        promptInput.inputParams = inputValues;

        // Set the application context
        promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        promptInput.additionalConfig.applicationName = APPLICATION_NAME;

        return promptInput;
    }
}
