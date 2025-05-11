step 1:
CALL gds.graph.project(
  'TempProjection',
  ['Paper'],
  {
    REFERENCES: {
      orientation: 'UNDIRECTED',
      properties: ['citationCount']
    }
  }
);

CALL gds.louvain.write('TempProjection', {
  writeProperty: 'community'
})
YIELD communityCount, modularity;

CALL gds.graph.drop('TempProjection');

step 2:
// Label training papers
MATCH (p:Paper)-[:WRITTEN_IN]->(y:Year)
WHERE y.value IS NOT NULL AND y.value <> 'NA' AND toInteger(y.value) >= 2014 AND toInteger(y.value) <= 2017
SET p:TrainPaper;

// Label test papers
MATCH (p:Paper)-[:WRITTEN_IN]->(y:Year)
WHERE y.value IS NOT NULL AND y.value <> 'NA' AND toInteger(y.value) > 2017
SET p:TestPaper;

step 3:
// Step 1: Remove old non-numeric 'split' properties (if any)
MATCH (:Paper)-[r:REFERENCES]->(:Paper)
REMOVE r.split;

// Step 2: Set training split (2016–2018)
MATCH (p1:Paper)-[:WRITTEN_IN]->(y:Year), 
      (p1)-[r:REFERENCES]->(p2:Paper)
WHERE y.value >= 2014 AND y.value <= 2017
SET r.split = 0.0;

// Step 3: Set test split (post-2018)
MATCH (p1:Paper)-[:WRITTEN_IN]->(y:Year), 
      (p1)-[r:REFERENCES]->(p2:Paper)
WHERE y.value > 2017
SET r.split = 1.0;

step 4:
CALL gds.graph.project(
  'CitationProjection',
  ['Paper'],
  {
    REFERENCES: {
      orientation: 'UNDIRECTED',
      properties: ['split']
    }
  },
  {
    nodeProperties: ['community']
  }
);

step 5: 
// Step 1: Create a Link Prediction Pipeline
CALL gds.beta.pipeline.linkPrediction.create('citationPipeline')

step 6:
CALL gds.beta.pipeline.linkPrediction.addNodeProperty('citationPipeline', 'fastRP', {
  mutateProperty: 'embedding',  // Store embeddings in 'embedding' property
  embeddingDimension: 64,  // Set embedding dimension size
  randomSeed: 42  // Set random seed for reproducibility
})

step 7:
// L2 Feature (Including Embedding, Community, and CitationCount)
CALL gds.beta.pipeline.linkPrediction.addFeature('citationPipeline', 'l2', {
  nodeProperties: ['embedding', 'community'],  // Including both embedding and community as node properties
  edgeProperties: ['citationCount']  // Using citationCount as edge property for L2 distance calculation
}) YIELD featureSteps;

// Hadamard Feature (Including Embedding, Community, and CitationCount)
CALL gds.beta.pipeline.linkPrediction.addFeature('citationPipeline', 'hadamard', {
  nodeProperties: ['embedding', 'community'],  // Including both embedding and community as node properties
  edgeProperties: ['citationCount']  // Using citationCount as edge property for Hadamard product calculation
}) YIELD featureSteps;

// Cosine Similarity Feature (Including Embedding, Community, and CitationCount)
CALL gds.beta.pipeline.linkPrediction.addFeature('citationPipeline', 'cosine', {
  nodeProperties: ['embedding', 'community'],  // Including both embedding and community as node properties
  edgeProperties: ['citationCount']  // Using citationCount as edge property for Cosine similarity calculation
}) YIELD featureSteps;


step 8:
// Logistic Regression Model
CALL gds.beta.pipeline.linkPrediction.addLogisticRegression('citationPipeline');

// Random Forest Model
CALL gds.beta.pipeline.linkPrediction.addRandomForest('citationPipeline', {numberOfDecisionTrees: 50});  // Adjust tree count


step 9:
CALL gds.alpha.pipeline.linkPrediction.configureAutoTuning('citationPipeline', {
  maxTrials: 20  // Max number of hyperparameter tuning trials
}) YIELD autoTuningConfig;

step 10:
CALL gds.beta.pipeline.linkPrediction.train('CitationProjection', {
  pipeline: 'citationPipeline',  // Your pipeline name
  modelName: 'lp-pipeline-model',  // Model name
  metrics: ['AUCPR', 'OUT_OF_BAG_ERROR'],  // Metrics for evaluation
  targetRelationshipType: 'REFERENCES',  // The target relationship type
  randomSeed: 18  // Set random seed for reproducibility
}) YIELD modelInfo, modelSelectionStats;
