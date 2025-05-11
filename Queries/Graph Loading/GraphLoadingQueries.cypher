\\This script is designed to load and transform data from CSV files into a Neo4j graph database.
\\ It creates nodes and relationships for authors, papers, journals, topics, fields, years, and publishers.
\\ The script also includes constraints and indexes to ensure data integrity and improve query performance.

\\ LODAING DATA INTO NEO4J GRAPH DATABASE
\\ Defines constraints and indexes to ensure data integrity and improve query performance
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

\\ Loads authors from CSV and creates or updates Author nodes with ID, name, and URL in batches for efficient import
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_author.csv' AS row
CALL {
    WITH row
    MERGE (a:Author {authorId: row.`Author.ID`})
    SET a.name = row.`Author.Name`,
        a.url = row.`Author.URL`
} IN TRANSACTIONS;

\\ Loads journal data from CSV and merges Journal nodes using name, publisher, and email as identifiers in transactional batches
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_journal.csv' AS row
CALL {
    WITH row
    MERGE (j:Journal {name: row.`Journal.Name`})  // Match Journal by unique name
    ON MATCH SET j.publisher = row.`Journal.Publisher`,
                j.email = row.`Publisher.Email`
    ON CREATE SET j.publisher = row.`Journal.Publisher`,
                 j.email = row.`Publisher.Email`
} IN TRANSACTIONS;


\\ Loads topic data from CSV and creates or updates Topic nodes with ID, name, and URL in transactional batches
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_topic.csv' AS row
CALL {
    WITH row
    MERGE (t:Topic {topicId: row.`Topic.ID`})
    SET t.name = row.`Topic.Name`,
        t.url = row.`Topic.URL`
} IN TRANSACTIONS;

\\ Loads paper data from CSV, creates or updates Paper nodes with metadata, and links them to Field and Year nodes in transactional batches
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

\\ Extracts unique publishers from Journal nodes and creates or updates corresponding Publisher nodes with email if valid, in transactional batches
:auto MATCH (j:Journal)
WHERE j.publisher IS NOT NULL AND j.publisher <> "NA"
WITH DISTINCT j.publisher AS publisherName, j.email AS publisherEmail
CALL {
    WITH publisherName, publisherEmail
    MERGE (p:Publisher {name: publisherName})
    SET p.email = CASE WHEN publisherEmail IS NOT NULL AND publisherEmail <> "NA" THEN publisherEmail ELSE null END
} IN TRANSACTIONS;

\\ Links each Journal to its corresponding Publisher node and removes embedded publisher and email properties from the Journal node
:auto MATCH (j:Journal)
WHERE j.publisher IS NOT NULL
MATCH (p:Publisher {name: j.publisher})
MERGE (j)-[:PUBLISHED_BY]->(p)
REMOVE j.publisher, j.email;

\\ Removes the 'publisher' and 'email' properties from 'Journal' nodes after linking to 'Publisher' nodes
MATCH (j:Journal)
REMOVE j.publisher, j.email;

\\ Updates the 'HAS' relationship between 'Journal' and 'Paper' nodes with the 'date' and 'volume' properties from the related 'Paper' nodes, where these properties are not null.
:auto MATCH (j:Journal)-[r:HAS]->(p:Paper)
WHERE p.date IS NOT NULL OR p.volume IS NOT NULL
SET r.date = p.date,
    r.volume = p.volume;

\\ Removes the 'volume' and 'date' properties from all 'Paper' nodes.
match (p:Paper)
remove p.volume, p.date;

\\ CREATING RELATIONSHIPS BETWEEN NODES
\\ Loads author-paper relationships from CSV and creates 'WROTE' relationships between Author and Paper nodes.
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_author_paper.csv' AS row
CALL {
    WITH row
    MATCH (a:Author {authorId: row.`Author.ID`})
    MATCH (p:Paper {paperId: row.`Paper.ID`})
    MERGE (a)-[:WROTE]->(p)
} IN TRANSACTIONS;

\\ Loads paper-journal relationships from CSV and creates 'HAS' relationships between Paper and Journal nodes.
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper_journal.csv' AS row
CALL {
    WITH row
    MATCH (p:Paper {paperId: row.`Paper ID`})
    MATCH (j:Journal {name: row.`Journal Name`})
    MERGE (j)-[:HAS]->(p)
} IN TRANSACTIONS;

\\ Loads paper-topic relationships from CSV and creates 'HAS_TOPIC' relationships between Paper and Topic nodes.
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper_topic.csv' AS row
CALL {
    WITH row
    MATCH (p:Paper {paperId: row.`Paper ID`})
    MATCH (t:Topic {topicId: row.`Topic ID`})
    MERGE (p)-[:HAS_TOPIC]->(t)
} IN TRANSACTIONS;

\\ Loads paper reference relationships from CSV and creates 'REFERENCES' relationships between citing and cited Paper nodes.
:auto LOAD CSV WITH HEADERS FROM 'file:///cleaned_paper_reference.csv' AS row
CALL {
    WITH row
    MATCH (citing:Paper {paperId: row.`Paper ID`})
    MATCH (cited:Paper {paperId: row.`Referenced Paper ID`})
    MERGE (citing)-[r:REFERENCES]->(cited)
    SET r.citationCount = toInteger(row.`Citation Count`)  // Setting citationCount as a relationship property
} IN TRANSACTIONS;

\\ Matches Author nodes that co-authored papers, counts the number of collaborations, and creates 'COAUTHOR' relationships between authors with the paper count as a property.
:auto MATCH (a:Author)-[:WROTE]->(p:Paper)<-[:WROTE]-(b:Author)
WHERE id(a) < id(b)  
WITH a, b, count(p) AS collaborationCount
MERGE (a)-[r:COAUTHOR]->(b)
SET r.paperCount = collaborationCount;

\\ This command will visualize the schema of the database, showing the nodes and relationships created.
CALL db.schema.visualization() 