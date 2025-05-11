// Step 1. Creating Graph Projection
CALL gds.graph.project(
  'NewCitationProjection',  // Name of the projection
  ['Paper'],  // Include only the Paper node
  {
    REFERENCES: {
      orientation: 'UNDIRECTED',  // Reference relationships will be undirected
      properties: ['citationCount']  // Only include citationCount as an edge property
    }
  }
)


// Step 2. Configure Pipeline
CALL gds.beta.pipeline.linkPrediction.create('citationPipeline')


// Step 3. Adding Node Properties
CALL gds.beta.pipeline.linkPrediction.addNodeProperty('citationPipeline', 'fastRP', {
  mutateProperty: 'embedding',  // The property that will store the embeddings
  embeddingDimension: 64,  // The dimension of the embedding vector
  randomSeed: 42  // A random seed for reproducibility
})


// Step 4. Adding Link Features

// L2 Feature (Including CitationCount)
CALL gds.beta.pipeline.linkPrediction.addFeature('citationPipeline', 'l2', {
  nodeProperties: ['embedding'],  // Using node embeddings
  edgeProperties: ['citationCount']  // Include citationCount as an edge property for L2 distance calculation
}) YIELD featureSteps

// Hadamard Feature (Including CitationCount):
CALL gds.beta.pipeline.linkPrediction.addFeature('citationPipeline', 'hadamard', {
  nodeProperties: ['embedding'],  // Using node embeddings
  edgeProperties: ['citationCount']  // Include citationCount as an edge property for Hadamard product calculation
}) YIELD featureSteps

CALL gds.beta.pipeline.linkPrediction.addFeature('citationPipeline', 'cosine', {
  nodeProperties: ['embedding'],  // Using node embeddings
  edgeProperties: ['citationCount']  // Include citationCount as an edge property for Cosine similarity calculation
}) YIELD featureSteps;


// Step 5. Configuring the relationship splits
CALL gds.beta.pipeline.linkPrediction.configureSplit('citationPipeline', {
  testFraction: 0.25,  // 25% for testing
  trainFraction: 0.6,  // 60% for training
  validationFolds: 3   // Optional: if you need cross-validation
})
YIELD splitConfig


// Step 6. Adding model candidates
CALL gds.beta.pipeline.linkPrediction.addLogisticRegression('citationPipeline')
CALL gds.beta.pipeline.linkPrediction.addRandomForest('citationPipeline', {numberOfDecisionTrees: 20}) // can change the number of tree


// Step 7. Training
CALL gds.beta.pipeline.linkPrediction.train('NewCitationProjection', {
  pipeline: 'citationPipeline',  // Your pipeline name
  modelName: 'lp-pipeline-model',  // Name of the model
  metrics: ['AUCPR', 'OUT_OF_BAG_ERROR'],  // Only valid metrics
  targetRelationshipType: 'REFERENCES',   // Relationship type in your graph
  randomSeed: 18  // Random seed for reproducibility
}) YIELD modelInfo, modelSelectionStats
RETURN
  modelInfo.bestParameters AS winningModel,
  modelInfo.metrics.AUCPR.train.avg AS avgTrainScore,
  modelInfo.metrics.AUCPR.outerTrain AS outerTrainScore,
  modelInfo.metrics.AUCPR.test AS testScore,
  [cand IN modelSelectionStats.modelCandidates | cand.metrics.AUCPR.validation.avg] AS validationScores


// Step 8. Prediction 
CALL gds.beta.pipeline.linkPrediction.predict.mutate('NewCitationProjection', {
  modelName: 'lp-pipeline-model',
  relationshipTypes: ['REFERENCES'],
  mutateRelationshipType: 'PREDICTED_CITATION',
  sampleRate: 0.5,
  topK: 2,
  randomJoins: 2,
  maxIterations: 10,
  concurrency: 1,
  randomSeed: 42
})
YIELD relationshipsWritten, samplingStats

-----------------------------------------------------------------------------------------------------------

