// Creating Indices for faster loading
CREATE CONSTRAINT author_id_unique IF NOT EXISTS FOR (a:Author) REQUIRE a.authorId IS UNIQUE;
CREATE CONSTRAINT paper_id_unique IF NOT EXISTS FOR (p:Paper) REQUIRE p.paperId IS UNIQUE;
CREATE CONSTRAINT topic_id_unique IF NOT EXISTS FOR (t:Topic) REQUIRE t.topicId IS UNIQUE;
CREATE CONSTRAINT journal_unique IF NOT EXISTS FOR (j:Journal) REQUIRE (j.name, j.publisher) IS NODE KEY;
CREATE CONSTRAINT publisher_name_unique IF NOT EXISTS FOR (p:Publisher) REQUIRE p.name IS UNIQUE;

CREATE INDEX author_name_index IF NOT EXISTS FOR (a:Author) ON (a.name);
CREATE INDEX paper_title_index IF NOT EXISTS FOR (p:Paper) ON (p.title);
CREATE INDEX topic_name_index IF NOT EXISTS FOR (t:Topic) ON (t.name);
CREATE INDEX field_name_index IF NOT EXISTS FOR (f:Field) ON (f.name);
CREATE INDEX year_value_index IF NOT EXISTS FOR (y:Year) ON (y.value);

// Creating Nodes
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_author.csv' AS row
CALL {
    WITH row
    MERGE (a:Author {authorId: row.`Author.ID`})
    SET a.name = row.`Author.Name`,
        a.url = row.`Author.URL`
} IN TRANSACTIONS;

:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_journal.csv' AS row
CALL {
    WITH row
    MERGE (j:Journal {name: row.`Journal.Name`, publisher: row.`Journal.Publisher`, email: row.`Publisher.Email`})
} IN TRANSACTIONS;

:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_topic.csv' AS row
CALL {
    WITH row
    MERGE (t:Topic {topicId: row.`Topic.ID`})
    SET t.name = row.`Topic.Name`,
        t.url = row.`Topic.URL`
} IN TRANSACTIONS;

:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper.csv' AS row
CALL {
    WITH row
    MERGE (p:Paper {paperId: row.`Paper ID`})
    SET p.doi = row.`Paper DOI`,
        p.title = row.`Paper Title`,
        p.url = row.`Paper URL`,
        p.citationCount = toInteger(row.`Paper Citation Count`),
        p.volume = row.`Journal Volume`,
        p.date = row.`Journal Date`
    
    WITH p, row
    WHERE row.`Fields of Study` IS NOT NULL
    MERGE (f:Field {name: row.`Fields of Study`})
    MERGE (p)-[:HAS_FIELD]->(f)
    
    WITH p, row
    WHERE row.`Paper Year` IS NOT NULL
    MERGE (y:Year {value: row.`Paper Year`})
    MERGE (p)-[:WRITTEN_IN]->(y)
} IN TRANSACTIONS;

// Edge Properties
:auto MATCH (j:Journal)-[r:HAS]->(p:Paper)
WHERE p.date IS NOT NULL OR p.volume IS NOT NULL
SET r.date = p.date,
    r.volume = p.volume;

// Remove volume and date from Paper node
MATCH (p:Paper)
REMOVE p.volume, p.date;

// Creating Relationships
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_author_paper.csv' AS row
CALL {
    WITH row
    MATCH (a:Author {authorId: row.`Author.ID`})
    MATCH (p:Paper {paperId: row.`Paper.ID`})
    MERGE (a)-[:WROTE]->(p)
} IN TRANSACTIONS;

:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper_journal.csv' AS row
CALL {
    WITH row
    MATCH (p:Paper {paperId: row.`Paper ID`})
    MATCH (j:Journal {name: row.`Journal Name`, publisher: row.`Journal Publisher`})
    MERGE (j)-[:HAS]->(p)
} IN TRANSACTIONS;

:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper_topic.csv' AS row
CALL {
    WITH row
    MATCH (p:Paper {paperId: row.`Paper ID`})
    MATCH (t:Topic {topicId: row.`Topic ID`})
    MERGE (p)-[:HAS_TOPIC]->(t)
} IN TRANSACTIONS;

:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper_reference.csv' AS row
CALL {
    WITH row
    MATCH (citing:Paper {paperId: row.`Paper ID`})
    MATCH (cited:Paper {paperId: row.`Referenced Paper ID`})
    MERGE (citing)-[:REFERENCES]->(cited)
} IN TRANSACTIONS;

:auto MATCH (a:Author)-[:WROTE]->(p:Paper)<-[:WROTE]-(b:Author)
WHERE id(a) < id(b)  
WITH a, b, count(p) AS collaborationCount
MERGE (a)-[r:COAUTHOR]->(b)
SET r.paperCount = collaborationCount;
