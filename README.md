# Graph-Based Machine Learning for Bibliographic Data

This repository implements a graph-based machine learning project to analyze a scholarly bibliographic dataset, focusing on **author classification** and **citation recommendation**. Using Neo4j's Graph Data Science (GDS) library and Python, we model academic entities as a property graph to uncover research patterns. The dataset, sourced from Rothenberger et al. (2021), is processed to support advanced bibliometric analysis.


## Project Overview
The project applies graph-based techniques to study academic networks:
- **Author Classification**: Predicts an author’s research domain using co-authorship network features.
- **Citation Recommendation**: Identifies potential citation links between papers via supervised link prediction.
- **Dataset**: Includes  papers, authors, topics, and  journals, with  citations and  authorship relationships.
- **Technologies**:
  - **Neo4j**: Graph database for modeling and feature engineering (FastRP embeddings, Louvain community detection, PageRank).[](https://github.com/neo4j/graph-data-science/releases)
  - **Python**: Model training/evaluation (Random Forest, XGBoost, Logistic Regression) with `scikit-learn`, `pandas`.
  - **R**: Data cleaning and preprocessing.
  - **Libraries**: `neo4j`, `matplotlib`, `seaborn` for visualization.

## Data Model

The dataset is structured as a Neo4j property graph:

### Nodes
- `Author` {`authorID: String`, `name: String`, `url: String`}
- `Paper` {`paperID: String`, `DOI: String`, `title: String`, `url: String`}
- `Journal` {`name: String`}
- `Topic` {`topicID: String`, `name: String`, `url: String`}
- `Field` {`name: String`}
- `Year` {`value: String`}
- `Publisher` {`name: String`}

### Relationships
- `(:Author)-[:WROTE]->(:Paper)`
- `(:Author)-[:COAUTHOR {paperCount: Integer}]->(:Author)`
- `(:Journal)-[:HAS {volume: String, date: String}]->(:Paper)`
- `(:Paper)-[:REFERENCES {citationCount: Integer}]->(:Paper)`
- `(:Paper)-[:HAS_TOPIC]->(:Topic)`
- `(:Paper)-[:HAS_FIELD]->(:Field)`
- `(:Paper)-[:WRITTEN_IN]->(:Year)`
- `(:Journal)-[:PUBLISHED_BY]->(:Publisher)`

This normalized model supports temporal queries and machine learning tasks.

## Data Cleaning and Preprocessing

Data preprocessing ensures quality using R scripts in `Data cleaning script.R`

## Setup
1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/your-repo.git
   cd your-repo

   pip install -r requirements.txt

## References
- Azfar, I., Munawar, T., & Pasta, Q. (2023). *Graph Data Science for Bibliographic Data: A Case of Migration Studies Data*. Habib University.
- Neo4j Graph Data Science Library Manual, Version 2.17. Available at: [Neo4j Documentation](https://neo4j.com/docs/graph-data-science/current/).
