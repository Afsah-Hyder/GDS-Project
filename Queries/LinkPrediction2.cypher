// Step 1. Creating Graph Projection
CALL gds.graph.project(
  'CitationProjection',
  ['Paper', 'Author', 'Topic', 'Field', 'Year'],
  {
    REFERENCES: {
      orientation: 'UNDIRECTED',
      properties: ['citationCount']  // Use citationCount property on the REFERENCES relationship
    },
    COAUTHOR: {
      orientation: 'UNDIRECTED',
      properties: ['paperCount']  // Use paperCount property on the COAUTHOR relationship
    },
    HAS_TOPIC: {
      orientation: 'UNDIRECTED'
    },
    HAS_FIELD: {
      orientation: 'UNDIRECTED'
    },
    WRITTEN_IN: {
      orientation: 'UNDIRECTED'
    }
  }
)

// Step 2. Configure Pipeline
CALL gds.beta.pipeline.linkPrediction.create('citationLinkPredictionPipeline')

// Step 3. Adding Node Properties