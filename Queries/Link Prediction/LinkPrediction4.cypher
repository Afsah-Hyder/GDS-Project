// 4TH ITERATION
// DATASET RANGE: 2014 - 2020
// ADDITIONAL STEPS FOR COMMUNITY DETECTION + PAGERANK CENTRALITY


// Step 1. Creating a projection 
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

// Step 2: Community detection
CALL gds.louvain.write('NewCitationProjection', { writeProperty: 'community' })
YIELD communityCount, modularity, modularities;

// Step 3: PageRank centrality
CALL gds.pageRank.write('NewCitationProjection', { writeProperty: 'pagerank' })
YIELD nodePropertiesWritten, ranIterations;

// x-------------------------------------------------------------------------------------x

// Step 1. Creating Graph Projection with community as a node feature
CALL gds.graph.project(
  'CitationProjection',  // Name of the projection
  ['Paper'],  // Include only Paper nodes
  {
    REFERENCES: {
      orientation: 'UNDIRECTED',  // Reference relationships will be undirected
      properties: ['citationCount']  // Include citationCount as edge property
    }
  },
  {
    nodeProperties: ['community', 'pagerank']  // Include community & pagerank as node property
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

// L2 Feature (Including CitationCount and Community)
CALL gds.beta.pipeline.linkPrediction.addFeature('citationPipeline', 'l2', {
  nodeProperties: ['embedding', 'community', 'pagerank'],  // Including both embedding and community as node properties
  edgeProperties: ['citationCount']  // Including citationCount as edge property for L2 distance calculation
}) YIELD featureSteps;

// Hadamard Feature (Including CitationCount and Community)
CALL gds.beta.pipeline.linkPrediction.addFeature('citationPipeline', 'hadamard', {
  nodeProperties: ['embedding', 'community', 'pagerank'],  // Including both embedding and community as node properties
  edgeProperties: ['citationCount']  // Including citationCount as edge property for Hadamard product calculation
}) YIELD featureSteps;

// Cosine Similarity Feature (Including CitationCount and Community)
CALL gds.beta.pipeline.linkPrediction.addFeature('citationPipeline', 'cosine', {
  nodeProperties: ['embedding', 'community', 'pagerank'],  // Including both embedding and community as node properties
  edgeProperties: ['citationCount']  // Including citationCount as edge property for Cosine similarity calculation
}) YIELD featureSteps;

// Step 5. Configuring the relationship splits
CALL gds.beta.pipeline.linkPrediction.configureSplit('citationPipeline', {
  testFraction: 0.2,  // Reduce to 20% for testing 
  trainFraction: 0.6,  // Use 60% for training 
  validationFolds: 2   // Set to 2-fold cross-validation
})
YIELD splitConfig;


// Step 6. Adding model candidates
CALL gds.beta.pipeline.linkPrediction.addLogisticRegression('citationPipeline')
CALL gds.beta.pipeline.linkPrediction.addRandomForest('citationPipeline', {numberOfDecisionTrees: 10}) // can change the number of trees


// Step 7. Training
CALL gds.beta.pipeline.linkPrediction.train('CitationProjection', {
  pipeline: 'citationPipeline',
  modelName: 'lp-pipeline-model',
  metrics: ['AUCPR', 'OUT_OF_BAG_ERROR'],
  targetRelationshipType: 'REFERENCES',
  randomSeed: 18
}) 
YIELD modelInfo, modelSelectionStats
RETURN
  modelInfo.bestParameters AS winningModel,
  modelInfo.metrics.AUCPR.train.avg AS avgTrainAUCPR,
  modelInfo.metrics.AUCPR.test AS testAUCPR,
  modelInfo.metrics.AUCPR.outerTrain AS outerTrainAUCPR,  // Outer training for AUCPR
  modelInfo.metrics.OUT_OF_BAG_ERROR.train.avg AS avgTrainOOBError,
  modelInfo.metrics.OUT_OF_BAG_ERROR.test AS testOOBError,
  modelInfo.metrics.OUT_OF_BAG_ERROR.outerTrain AS outerTrainOOBError,  // Outer training for Out of Bag Error
  [cand IN modelSelectionStats.modelCandidates | cand.metrics.AUCPR.validation.avg] AS validationScores
