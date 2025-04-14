# GDS-Project

# Graph-Based Machine Learning for Bibliographic Data

This project applies graph-based machine learning techniques to a bibliographic dataset for **node classification** and **link prediction** tasks. The dataset includes information about authors, papers, journals, and topics, which we model as a graph using Neo4j and Python-based frameworks.

## 📌 Project Overview
- **Tasks**: 
  - **Node Classification**: Predict labels for nodes (e.g., author research domains, paper topics).
  - **Link Prediction**: Predict missing/future links (e.g., collaborations, citations).
- **Tools**: Neo4j (graph construction), Python (preprocessing, ML models), and libraries like `py2neo`, `scikit-learn`, or `GNN frameworks`.
- **Dataset**: [Migration Research Bibliographic Data](https://github.com/your-repo-link) from Rothenberger et al. (2021).


## 🛠️ Setup
1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/your-repo.git
   cd your-repo

   pip install -r requirements.txt


   If you use this dataset or code, cite the original paper:

## Citation
If you use this dataset or code, cite the original paper:
@article{10.1162/qss_a_00163,
    author = {Rothenberger, Liane and Pasta, Muhammad Qasim and Mayerhoffer, Daniel},
    title = "{Mapping and impact assessment of phenomenon-oriented research fields}",
    journal = {Quantitative Science Studies},
    volume = {2},
    number = {4},
    pages = {1466-1485},
    year = {2021}
}
