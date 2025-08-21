
## This script combines the raw text of the UNGA corpus 
## that was downloaded at the following link in the raw_data/unga_raw_text folder : 
## https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/0TJX8Y

# Import packages 

## install.packages("pacman")

pacman::p_load(tidyverse, fs, readtext, janitor)

# Import files that are stored in a given path

files <- dir_ls("raw_data/unga_raw_text", recurse = T, regexp = ".txt")

# Import speakers

speakers <- readxl::read_excel("data/Speakers_by_session.xlsx") |> 
  clean_names() |> 
  select(1:6)

# Extract speeches

extract_speeches <- function(x) {
  speech <- readtext(x) |> 
    mutate(year = str_extract(doc_id, "\\d{4}") |> as.double(),
           iso_code = str_extract(doc_id, "[A-Z]{3}"))
}

speeches <- map_df(files, extract_speeches, .progress = TRUE) |> 
  left_join(speakers) |> 
  filter(year >= 1975)

# Save speeches

arrow::write_parquet(speeches, "data/un_speeches.parquet")

