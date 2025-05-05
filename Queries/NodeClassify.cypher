CALL gds.graph.project(
  'authorGraph',
  'Author',
  {
    COAUTHOR: {
      orientation: 'UNDIRECTED'
    }
  }
)

CALL gds.louvain.write('authorGraph', {
  writeProperty: 'communityId'
})

MATCH (a:Author)
WHERE a.domain IS NOT NULL
WITH DISTINCT a.domain AS domain
ORDER BY domain
WITH collect(domain) AS domainList

UNWIND range(0, size(domainList)-1) AS idx
WITH idx, domainList[idx] AS domain

MATCH (a:Author)
WHERE a.domain = domain
SET a.domainId = idx;

MATCH (a:Author)
WHERE a.domainId IS NOT NULL
SET a:TrainAuthor;

CALL gds.graph.project(
  'authorTrainGraph',
  {
    TrainAuthor: {
      properties: ['domainId', 'communityId']
    }
  },
  {
    COAUTHOR: {
      orientation: 'UNDIRECTED'
    }
  }
)

CALL gds.beta.pipeline.nodeClassification.create("authorClassification")

CALL gds.beta.pipeline.nodeClassification.addNodeProperty('authorClassification', 'fastRP', {
  embeddingDimension: 64,
  mutateProperty: 'embedding'
})

CALL gds.beta.pipeline.nodeClassification.selectFeatures('authorClassification', ['embedding', 'domainId', 'communityId'])

CALL gds.beta.pipeline.nodeClassification.addRandomForest("authorClassification", {
  numberOfDecisionTrees: 20
})

CALL gds.beta.pipeline.nodeClassification.configureSplit('authorClassification', {
  validationFolds: 5,
  testFraction: 0.2,
});

CALL gds.beta.pipeline.nodeClassification.train('authorTrainGraph', {
  pipeline: 'authorClassification',
  targetNodeLabels: ['TrainAuthor'],
  modelName: 'authorClassifier',
  targetProperty: 'domainId',
  randomSeed: 42,
  metrics: ['ACCURACY', 'F1_WEIGHTED']
})
YIELD modelInfo, modelSelectionStats
RETURN
  modelInfo.bestParameters AS bestParams,
  modelInfo.metrics.ACCURACY.train.avg AS trainAcc,
  modelInfo.metrics.ACCURACY.test AS testAcc,
  modelInfo.metrics.F1_WEIGHTED.test AS testF1;

CALL gds.beta.pipeline.nodeClassification.predict.stream('authorTrainGraph', {
  modelName: 'authorClassifier',
  targetNodeLabels: ['TrainAuthor'],
  includePredictedProbabilities: true
})
YIELD nodeId, predictedClass, predictedProbabilities
WITH gds.util.asNode(nodeId) AS author, predictedClass, predictedProbabilities
RETURN
  author.name AS authorName,
  predictedClass,
  predictedProbabilities[predictedClass] AS confidence
ORDER BY confidence DESC;



