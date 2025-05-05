CALL gds.graph.project(
  'authorGraph',
  'Author',
  {
    COAUTHOR: {
      type: 'COAUTHOR',
      orientation: 'UNDIRECTED'
    }
  }
)

CALL gds.node2vec.write('authorGraph', {
  writeProperty: 'n2vEmbedding'
})
YIELD nodePropertiesWritten;

MATCH (a:Author)
RETURN a.name, a.n2vEmbedding
LIMIT 10;

MATCH (a:Author)-[:WROTE]->(:Paper)-[:HAS_FIELD]->(f:Field)
WHERE f.name IS NOT NULL AND f.name <> "NA"
WITH a, f.name AS fieldName, count(*) AS freq
ORDER BY freq DESC
WITH a, collect(fieldName)[0] AS topField
SET a.domain = topField

// IN VS Code




















