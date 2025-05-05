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

from neo4j import GraphDatabase
import pandas as pd
import numpy as np

uri = "bolt://localhost:7687"
user = "neo4j"
password = "12345678"

driver = GraphDatabase.driver(uri, auth=(user, password))

query = """
MATCH (a:Author)
WHERE a.n2vEmbedding is not null AND a.domain is not null
RETURN id(a) AS id, a.n2vEmbedding AS features, a.domain AS label
"""

with driver.session() as session:
    results = session.run(query)
    records = [(r["id"], r["features"], r["label"]) for r in results]

driver.close()

# Convert to DataFrame
df = pd.DataFrame(records, columns=["id", "features", "label"])
df["features"] = df["features"].apply(np.array)

# Expand features to separate columns
features_df = pd.DataFrame(df["features"].tolist())
full_df = pd.concat([df[["id", "label"]], features_df], axis=1)

print(full_df.head())


X = full_df.drop(columns=["id", "label"])
y = full_df["label"]

print("Labels (y):")
print(y.value_counts())  # <--- This is what you asked

X_train, X_test, y_train, y_test = train_test_split(X, y, stratify=y, test_size=0.2, random_state=42)

clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train, y_train)

y_pred = clf.predict(X_test)
print(classification_report(y_test, y_pred))



















