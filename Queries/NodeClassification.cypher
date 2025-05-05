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

--------------------------------------------------------------------------------------------------

from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

# Drop id and keep features + label
X = full_df.drop(columns=["id", "label"])
y = full_df["label"]

# Count label frequencies
label_counts = y.value_counts()

# Keep only labels with at least 2 samples (or choose a higher threshold like 5 or 10)
valid_labels = label_counts[label_counts >= 2].index

# Filter the dataset
filtered_df = full_df[full_df["label"].isin(valid_labels)]
X = filtered_df.drop(columns=["id", "label"])
y = filtered_df["label"]

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(X, y, stratify=y, test_size=0.2, random_state=42)

# Train classifier
clf = RandomForestClassifier(n_estimators=100, random_state=42)
clf.fit(X_train, y_train)

# Evaluate
y_pred = clf.predict(X_test)
print(classification_report(y_test, y_pred))

Key Observations:
High accuracy (80%) is mostly driven by dominant classes like "Sociology" and "Medicine" which have a lot of support (samples).
Low precision/recall for many small classes like "Engineering", "Philosophy", or "Art" is due to:
Too few examples to learn meaningful patterns.
Random Forests favoring frequent classes unless balanced.
Warnings are due to no predictions being made for some classes — e.g., the model never predicted "Engineering", so precision is undefined.


Then changed it to: 'clf = RandomForestClassifier(n_estimators=100, random_state=42, class_weight="balanced")'
-----------------------------------------------------------------------------------------------------------------------------------
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

# Drop unwanted columns and define X and y using grouped labels
X = full_df.drop(columns=["id", "label", "label_grouped"])
y = full_df["label_grouped"]

label_counts = y.value_counts()
valid_labels = label_counts[label_counts >= 2].index

filtered_df = full_df[full_df["label_grouped"].isin(valid_labels)]
X = filtered_df.drop(columns=["id", "label", "label_grouped"])
y = filtered_df["label_grouped"]

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(X, y, stratify=y, test_size=0.2, random_state=42)

# Train classifier
clf = RandomForestClassifier(n_estimators=100, random_state=42, class_weight="balanced")
clf.fit(X_train, y_train)

# Evaluate
y_pred = clf.predict(X_test)
print(classification_report(y_test, y_pred))

-----------------------------------------------------------------------------------------------------------------------------------------------

from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

# Train-test split (after resampling)
X_train, X_test, y_train, y_test = train_test_split(
    X_resampled, y_resampled, stratify=y_resampled, test_size=0.2, random_state=42
)

# Train Logistic Regression
log_reg = LogisticRegression(
    multi_class="multinomial",  # for softmax behavior
    solver="lbfgs",             # efficient for multinomial
    max_iter=1000,
    class_weight="balanced"     # helps with any residual imbalance
)
log_reg.fit(X_train, y_train)

# Evaluate
y_pred = log_reg.predict(X_test)
print(classification_report(y_test, y_pred))

--------------------------------------------------------------------------------------------------------------------------------------------
from xgboost import XGBClassifier
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report

# Encode string labels to integers
le = LabelEncoder()
y_encoded = le.fit_transform(y_resampled)

# Train-test split
X_train, X_test, y_train, y_test = train_test_split(
    X_resampled, y_encoded, stratify=y_encoded, test_size=0.2, random_state=42
)

# Train XGBoost
xgb_clf = XGBClassifier(
    objective="multi:softmax",
    num_class=len(le.classes_),
    eval_metric="mlogloss",
    use_label_encoder=False,
    random_state=42,
    n_jobs=-1
)
xgb_clf.fit(X_train, y_train)

# Predict and decode labels back to original strings
y_pred_encoded = xgb_clf.predict(X_test)
y_pred = le.inverse_transform(y_pred_encoded)
y_test_str = le.inverse_transform(y_test)

# Evaluate
print(classification_report(y_test_str, y_pred))











