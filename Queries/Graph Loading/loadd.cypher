// Creating Constraints and Indexes
CREATE CONSTRAINT author_id_unique IF NOT EXISTS FOR (a:Author) REQUIRE a.authorId IS UNIQUE;
CREATE CONSTRAINT paper_id_unique IF NOT EXISTS FOR (p:Paper) REQUIRE p.paperId IS UNIQUE;
CREATE CONSTRAINT topic_id_unique IF NOT EXISTS FOR (t:Topic) REQUIRE t.topicId IS UNIQUE;
CREATE CONSTRAINT journal_name_unique IF NOT EXISTS FOR (j:Journal) REQUIRE j.name IS UNIQUE;
CREATE CONSTRAINT publisher_name_unique IF NOT EXISTS FOR (p:Publisher) REQUIRE p.name IS UNIQUE;

CREATE INDEX author_name_index IF NOT EXISTS FOR (a:Author) ON (a.name);
CREATE INDEX paper_title_index IF NOT EXISTS FOR (p:Paper) ON (p.title);
CREATE INDEX topic_name_index IF NOT EXISTS FOR (t:Topic) ON (t.name);
CREATE INDEX field_name_index IF NOT EXISTS FOR (f:Field) ON (f.name);
CREATE INDEX year_value_index IF NOT EXISTS FOR (y:Year) ON (y.value);

// Load authors from CSV and create or update Author nodes
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_author.csv' AS row
CALL {
    WITH row
    MERGE (a:Author {authorId: row.`Author.ID`})
    SET a.name = row.`Author.Name`,
        a.url = row.`Author.URL`
} IN TRANSACTIONS;

// Load journal data from CSV and merge Journal nodes
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_journal.csv' AS row
CALL {
    WITH row
    MERGE (j:Journal {name: row.`Journal.Name`}) 
    ON MATCH SET j.publisher = row.`Journal.Publisher`,
                j.email = row.`Publisher.Email`
    ON CREATE SET j.publisher = row.`Journal.Publisher`,
                 j.email = row.`Publisher.Email`
} IN TRANSACTIONS;

// Load topic data from CSV and create or update Topic nodes
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_topic.csv' AS row
CALL {
    WITH row
    MERGE (t:Topic {topicId: row.`Topic.ID`})
    SET t.name = row.`Topic.Name`,
        t.url = row.`Topic.URL`
} IN TRANSACTIONS;

// Load paper data from CSV and create or update Paper nodes
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper.csv' AS row
CALL {
    WITH row
    MERGE (p:Paper {paperId: row.`Paper ID`})
    SET p.doi = row.`Paper DOI`,
        p.title = row.`Paper Title`,
        p.url = row.`Paper URL`,
        p.citationCount = toInteger(row.`Paper Citation Count`),  // Citation count as a node property (updated later)
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

// Extract and create Publisher nodes
:auto MATCH (j:Journal)
WHERE j.publisher IS NOT NULL AND j.publisher <> "NA"
WITH DISTINCT j.publisher AS publisherName, j.email AS publisherEmail
CALL {
    WITH publisherName, publisherEmail
    MERGE (p:Publisher {name: publisherName})
    SET p.email = CASE WHEN publisherEmail IS NOT NULL AND publisherEmail <> "NA" THEN publisherEmail ELSE null END
} IN TRANSACTIONS;

// Link Journals to Publishers and clean up publisher information
:auto MATCH (j:Journal)
WHERE j.publisher IS NOT NULL
MATCH (p:Publisher {name: j.publisher})
MERGE (j)-[:PUBLISHED_BY]->(p)
REMOVE j.publisher, j.email;

// Update HAS relationships between Paper and Journal with volume and date properties
:auto MATCH (j:Journal)-[r:HAS]->(p:Paper)
WHERE p.date IS NOT NULL OR p.volume IS NOT NULL
SET r.date = p.date,
    r.volume = p.volume;

// Remove volume and date properties from Paper nodes
MATCH (p:Paper)
REMOVE p.volume, p.date;

// Create relationships between Author and Paper (WROTE)
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_author_paper.csv' AS row
CALL {
    WITH row
    MATCH (a:Author {authorId: row.`Author.ID`})
    MATCH (p:Paper {paperId: row.`Paper.ID`})
    MERGE (a)-[:WROTE]->(p)
} IN TRANSACTIONS;

// Create relationships between Paper and Journal (HAS)
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper_journal.csv' AS row
CALL {
    WITH row
    MATCH (p:Paper {paperId: row.`Paper ID`})
    MATCH (j:Journal {name: row.`Journal Name`})
    MERGE (j)-[:HAS]->(p)
} IN TRANSACTIONS;

// Create relationships between Paper and Topic (HAS_TOPIC)
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper_topic.csv' AS row
CALL {
    WITH row
    MATCH (p:Paper {paperId: row.`Paper ID`})
    MATCH (t:Topic {topicId: row.`Topic ID`})
    MERGE (p)-[:HAS_TOPIC]->(t)
} IN TRANSACTIONS;

// Create relationships between Paper and Paper (REFERENCES)
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper_reference.csv' AS row
CALL {
    WITH row
    MATCH (citing:Paper {paperId: row.`Paper ID`})
    MATCH (cited:Paper {paperId: row.`Referenced Paper ID`})
    MERGE (citing)-[r:REFERENCES]->(cited)
    SET r.citationCount = toInteger(row.`Citation Count`)  // Setting citationCount as a relationship property
} IN TRANSACTIONS;

// Create COAUTHOR relationships between authors
:auto MATCH (a:Author)-[:WROTE]->(p:Paper)<-[:WROTE]-(b:Author)
WHERE id(a) < id(b)
WITH a, b, count(p) AS collaborationCount
MERGE (a)-[r:COAUTHOR]->(b)
SET r.paperCount = collaborationCount;

// Visualize the schema
CALL db.schema.visualization();
