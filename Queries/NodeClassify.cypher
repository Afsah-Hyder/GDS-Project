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

