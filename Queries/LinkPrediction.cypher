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
  embeddingDimension: 128,  // The dimension of the embedding vector
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


// Step 5. Configuring the relationship splits
CALL gds.beta.pipeline.linkPrediction.configureSplit('citationPipeline', {
  testFraction: 0.25,  // 25% for testing
  trainFraction: 0.6,  // 60% for training
  validationFolds: 3   // Optional: if you need cross-validation
})
YIELD splitConfig


// Step 6. Adding model candidates
CALL gds.beta.pipeline.linkPrediction.addLogisticRegression('citationPipeline')

CALL gds.beta.pipeline.linkPrediction.addRandomForest('citationPipeline', {numberOfDecisionTrees: 10}) // can change the number of trees


// Step 7. AutoTuning
CALL gds.alpha.pipeline.linkPrediction.configureAutoTuning('citationPipeline', {
  maxTrials: 10
})
YIELD autoTuningConfig;


// Step 8. Memory Estimation required for Training - Optional
CALL gds.beta.pipeline.linkPrediction.train.estimate('NewCitationProjection', {
  pipeline: 'citationPipeline',
  modelName: 'lp-pipeline-model',
  targetRelationshipType: 'REFERENCES'
})
YIELD requiredMemory;


// Step 9. Training
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


  
// Step 10. Memory Estimation required for Prediction - Optional: skipping for now


// Step 11. Prediction (With write command)
CALL gds.beta.pipeline.linkPrediction.predict.stream('NewCitationProjection', {
  modelName: 'lp-pipeline-model',
  topN: 2,  // Only top 2 predicted links will be written
  threshold: 0.5,  // Only predictions with a probability above 0.5 will be written
  writeRelationshipType: 'PREDICTED_CITATION'  // Writing predicted links as 'PREDICTED_CITATION'
})
YIELD node1, node2, probability
WITH gds.util.asNode(node1) AS n1, gds.util.asNode(node2) AS n2, probability
RETURN n1.title AS paper1, n2.title AS paper2, probability
ORDER BY probability DESC, paper1


