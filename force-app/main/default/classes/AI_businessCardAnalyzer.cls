public without sharing class AI_businessCardAnalyzer {
    
    
    public static String extractInformation(String fileId) {
        try {
            // Prepare input for the Einstein Prompt Template
            ConnectApi.EinsteinPromptTemplateGenerationsInput promptInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            promptInput.isPreview = false;

            // Wrap sales alert input
            Map<String, String> cMap = new Map<String, String>();
            cMap.put('id', fileId);

            ConnectApi.WrappedValue cWrapped = new ConnectApi.WrappedValue();
            cWrapped.value = cMap;

            // Input values for the prompt
            Map<String, ConnectApi.WrappedValue> inputValues = new Map<String, ConnectApi.WrappedValue>();
            inputValues.put('Input:Image', cWrapped);

            promptInput.inputParams = inputValues;

            // Set the application context
            promptInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            promptInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

            // Call Einstein LLM with the prompt template
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result = 
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Business_Card_Scanner_Prompt', promptInput);

            System.debug(result.generations[0].text);
            
            return result.generations[0].text;

        } catch (Exception e) {
            System.debug('Error calling Einstein: ' + e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }
}