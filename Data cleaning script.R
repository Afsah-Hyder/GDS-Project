# Install and load necessary packages if not already installed
required_packages <- c("rvest", "dplyr", "stringr", "tidyverse", "tidytext", "textstem")

# Check and install missing packages
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}

# Load the libraries
library(rvest)       # For web scraping: reading HTML pages and extracting content
library(dplyr)       # For data manipulation: useful for handling and cleaning data frames
library(stringr)     # For string manipulation: used for cleaning text (like removing extra whitespace)
library(tidyverse)   # For data wrangling (contains dplyr, tidyr, ggplot2, etc.); used for general data manipulation
library(tidytext)    # For text processing: provides stop word lists and tools for text tokenization
library(textstem)    # For lemmatization: reduces words to their root form (e.g., "running" -> "run")
#---------------------------------------------------------------------------
#CLEANING FOR AUTHOR.CSV

# Step 1: Read the CSV file containing author metadata
file_path <- "author.csv"  
author_df <- read.csv(file_path, stringsAsFactors = FALSE)

# Step 2: Clean the author data

# Convert Author ID to numeric and remove invalid rows
author_df$Author.ID <- as.numeric(author_df$Author.ID)
author_df <- author_df[!is.na(author_df$Author.ID), ]

# Ensure Author Name is character
author_df$Author.Name <- as.character(author_df$Author.Name)

# Convert author name to lowercase
author_df$Author.Name <- tolower(author_df$Author.Name)

# Trim leading/trailing whitespace
author_df$Author.Name <- trimws(author_df$Author.Name)

# Keep only letters, spaces, periods, hyphens, apostrophes
author_df$Author.Name <- gsub("[^a-z\\.\\-\\'\\s]", " ", author_df$Author.Name)

# Replace multiple spaces with a single space
author_df$Author.Name <- gsub("\\s+", " ", author_df$Author.Name)

# Ensure Author URL is a valid URL using regex
valid_url_pattern <- "^https?://.+"
author_df <- author_df %>%
  filter(str_detect(Author.URL, valid_url_pattern))

# Remove rows with any missing or empty fields
author_df <- author_df %>%
  filter_all(all_vars(!is.na(.) & . != ""))

# Remove duplicate rows
author_df <- author_df %>%
  distinct()

# Save the cleaned data to a new CSV file
write.csv(author_df, "cleaned_author.csv", row.names = FALSE)
#---------------------------------------------------------------------
# CLEANING FOR AUTHOR_PAPER.CSV

# Step 1: Read the CSV file containing author-paper relationships
file_path <- "author_paper.csv"  
author_paper_df <- read.csv(file_path, stringsAsFactors = FALSE)

# Step 2: Clean Author ID
author_paper_df$Author.ID <- as.numeric(author_paper_df$Author.ID)
author_paper_df <- author_paper_df[!is.na(author_paper_df$Author.ID), ]

# Step 3: Validate Paper ID, must be lowercase letters and/or digits only 
valid_paper_id_pattern <- "^[a-z0-9]+$"
author_paper_df <- author_paper_df %>%
  filter(str_detect(Paper.ID, valid_paper_id_pattern))

# Step 4: Remove rows with any missing or empty fields
author_paper_df <- author_paper_df %>%
  filter_all(all_vars(!is.na(.) & . != ""))

# Step 5: Remove duplicate Author-Paper pairs
author_paper_df <- author_paper_df %>%
  distinct(Author.ID, Paper.ID, .keep_all = TRUE)

# Step 6: Save cleaned data
write.csv(author_paper_df, "cleaned_author_paper.csv", row.names = FALSE)

#---------------------------------------------------------------------
# CLEANING FOR TOPIC.CSV

# Step 1: Read the CSV file
file_path <- "topic.csv"
topic_df <- read.csv(file_path, stringsAsFactors = FALSE)

# Step 2: Ensure Topic ID is numeric
topic_df$Topic.ID <- as.numeric(topic_df$Topic.ID)
topic_df <- topic_df[!is.na(topic_df$Topic.ID), ]

# Step 3: Clean and standardize Topic Name, convert to lowercase
topic_df$Topic.Name <- tolower(topic_df$Topic.Name)

# Replace disallowed characters with a space, allowed: a-z, 0-9, space, (, ), ., ,, -
topic_df$Topic.Name <- gsub("[^a-z0-9\\s\\(\\)\\.,-]", " ", topic_df$Topic.Name)

# Replace multiple spaces with a single space
topic_df$Topic.Name <- gsub("\\s+", " ", topic_df$Topic.Name)

# trim leading/trailing spaces
topic_df$Topic.Name <- trimws(topic_df$Topic.Name)

# Step 4: Validate Topic URL
valid_url_pattern <- "^https?://.+"
topic_df <- topic_df %>%
  filter(str_detect(Topic.URL, valid_url_pattern))

# Step 5: Remove rows with any missing or empty values
topic_df <- topic_df %>%
  filter_all(all_vars(!is.na(.) & . != ""))

# Step 6: Remove duplicate rows
topic_df <- topic_df %>%
  distinct()

# Step 7: Save cleaned data
write.csv(topic_df, "cleaned_topic.csv", row.names = FALSE)

#---------------------------------------------------------------------
# CLEANING FOR JOURNAL.CSV
# Step 1: Read the CSV file
file_path <- "journal.csv"
journal_df <- read.csv(file_path, stringsAsFactors = FALSE)

# Step 2: Normalize Journal Name (convert to lowercase and unify 'and'/'&')
journal_df$Journal.Name <- tolower(journal_df$Journal.Name)
journal_df$Journal.Name <- str_replace_all(journal_df$Journal.Name, "\\s*&\\s*|\\s+and\\s+", " and ")
journal_df$Journal.Name <- str_squish(journal_df$Journal.Name)

# Step 3: Extract emails using regex
journal_df$Publisher.Email <- str_extract_all(
  journal_df$Journal.Publisher,
  "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
)

# Flatten emails list to strings, use "" for no emails
journal_df$Publisher.Email <- sapply(journal_df$Publisher.Email, function(emails) {
  emails <- unique(emails)
  if (length(emails) == 0 || all(is.na(emails))) return("")
  paste(emails, collapse = ", ")
})

# Step 4: Remove emails from Journal.Publisher
journal_df$Journal.Publisher <- str_remove_all(
  journal_df$Journal.Publisher,
  "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
)

# Step 5: Remove addresses from Journal.Publisher (common address patterns)
journal_df$Journal.Publisher <- str_remove_all(
  journal_df$Journal.Publisher,
  "\\d+\\s+[A-Za-z]+\\s*(?:Street|St\\.|Road|Rd\\.|Avenue|Ave\\.|Lane|Ln\\.|Boulevard|Blvd\\.|Place|Pl\\.|City|Quezon|Washington|Chichester|Basingstoke|Hants\\.|Wagon|First|Thousand|Oaks|Bay|New|York).*?(?=(,|$))"
)

# Clean up unwanted characters and extra spaces
journal_df$Journal.Publisher <- str_replace_all(journal_df$Journal.Publisher, "[^a-zA-Z0-9\\s\\.,&\\-]", " ")
journal_df$Journal.Publisher <- str_squish(journal_df$Journal.Publisher)

# Step 6: Replace blank publishers with "Unknown" to preserve rows
journal_df$Journal.Publisher[journal_df$Journal.Publisher == ""] <- "Unknown"

# Step 7: Group by Journal.Name and Journal.Publisher to preserve distinct publishers
cleaned_journal_df <- journal_df %>%
  group_by(Journal.Name, Journal.Publisher) %>%
  summarise(
    Publisher.Email = {
      emails <- unique(unlist(strsplit(Publisher.Email, ",\\s*")))
      emails <- emails[emails != "" & !is.na(emails)]
      if (length(emails) == 0) "" else paste(emails, collapse = ", ")
    },
    .groups = "drop"
  ) %>%
  ungroup()

# Step 8: Replace "Unknown" back to "" in Journal.Publisher
cleaned_journal_df$Journal.Publisher[cleaned_journal_df$Journal.Publisher == "Unknown"] <- ""

# Step 9: Replace empty strings with NA in Publisher.Email and Journal.Publisher
cleaned_journal_df$Publisher.Email[cleaned_journal_df$Publisher.Email == ""] <- NA
cleaned_journal_df$Journal.Publisher[cleaned_journal_df$Journal.Publisher == ""] <- NA

# Step 10: Save cleaned file
write.csv(cleaned_journal_df, "cleaned_journal.csv", row.names = FALSE)
#---------------------------------------------------------------------
# CLEANING FOR PAPER.CSV
# Step 1: Read the CSV file without modifying header names
file_path <- "paper.csv"
paper_df <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)

# Step 2: Remove rows with missing or empty Paper ID or Paper Title
paper_df <- paper_df %>%
  filter(!is.na(`Paper ID`) & `Paper ID` != "" & !is.na(`Paper Title`) & `Paper Title` != "")

# Step 3: Clean and normalize Paper Title
paper_df$`Paper Title` <- tolower(paper_df$`Paper Title`)
paper_df$`Paper Title` <- str_replace_all(paper_df$`Paper Title`, "[^a-z0-9\\s\\.,\\-:;']", " ")
paper_df$`Paper Title` <- str_squish(paper_df$`Paper Title`)

# Step 4: Ensure Paper Citation Count is numeric, fill missing with 0
paper_df <- paper_df %>%
  mutate(
    `Paper Citation Count` = ifelse(
      is.na(`Paper Citation Count`) | `Paper Citation Count` == "", 
      0, 
      as.numeric(`Paper Citation Count`)
    )
  )

# Step 5: Fill missing or empty values in certain fields with NA
fields_to_na <- c("Paper DOI", "Fields of Study", "Journal Volume", "Journal Date", "Paper URL")
for (field in fields_to_na) {
  paper_df[[field]] <- ifelse(
    is.na(paper_df[[field]]) | paper_df[[field]] == "", 
    NA, 
    paper_df[[field]]
  )
}

# Step 6: Save cleaned data with original headers preserved
write.csv(paper_df, "cleaned_paper.csv", row.names = FALSE, quote = TRUE)
#------------------------------------------------------------
# CLEANING FOR PAPER_TOPIC.CSV --NO CLEANING REQUIRED THOUGH

# Step 1: Read CSV with check.names = FALSE to preserve original column names
file_path <- "paper_topic.csv"
paper_topic_df <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)

# Step 2: Clean rows with missing or blank IDs
paper_topic_df <- paper_topic_df %>%
  filter(!is.na(`Paper ID`) & `Paper ID` != "" & !is.na(`Topic ID`) & `Topic ID` != "")

# Step 3: Convert Topic ID to numeric and drop conversion errors
paper_topic_df$`Topic ID` <- as.numeric(paper_topic_df$`Topic ID`)
paper_topic_df <- paper_topic_df %>% filter(!is.na(`Topic ID`))

# Step 4: Remove duplicates
paper_topic_df <- distinct(paper_topic_df)

# Step 5: Save cleaned CSV with original headers intact
write.csv(paper_topic_df, "cleaned_paper_topic.csv", row.names = FALSE, quote = TRUE)
#------------------------------------------------------------
# CLEANING FOR PAPER_REFERENCE.CSV --NO CLEANING REQUIRED THOUGH

# Step 1: Read CSV with original headers intact
file_path <- "paper_reference.csv"
paper_ref_df <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)

# Step 2: Remove rows with missing or blank Paper IDs or Referenced Paper IDs
paper_ref_df <- paper_ref_df %>%
  filter(!is.na(`Paper ID`) & `Paper ID` != "" &
           !is.na(`Referenced Paper ID`) & `Referenced Paper ID` != "")

# Step 3: Remove duplicates
paper_ref_df <- distinct(paper_ref_df)

# Step 4: Save cleaned CSV with original headers
write.csv(paper_ref_df, "cleaned_paper_reference.csv", row.names = FALSE, quote = TRUE)
#------------------------------------------------------------
# Step 1: Load CSV with original headers preserved
# CLEANING FOR PAPER_JOURNAL.CSV 

file_path <- "paper_journal.csv"
paper_journal_df <- read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE)

# Step 2: Remove rows with missing or empty Paper ID or Journal Name
paper_journal_df <- paper_journal_df %>%
  filter(!is.na(`Paper ID`) & `Paper ID` != "",
         !is.na(`Journal Name`) & `Journal Name` != "")

# Step 3: Clean Journal Name (optional normalization)
paper_journal_df$`Journal Name` <- tolower(paper_journal_df$`Journal Name`)
paper_journal_df$`Journal Name` <- str_squish(paper_journal_df$`Journal Name`)

# Step 4: Fill missing Journal Publisher with "NA" 
paper_journal_df$`Journal Publisher`[is.na(paper_journal_df$`Journal Publisher`) | paper_journal_df$`Journal Publisher` == ""] <- "NA"

# Step 5: Remove duplicates
paper_journal_df <- distinct(paper_journal_df)

# Step 6: Save cleaned file
write.csv(paper_journal_df, "cleaned_paper_journal.csv", row.names = FALSE, quote = TRUE)
