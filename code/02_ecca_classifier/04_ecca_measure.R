
# Import packages

pacman::p_load(tidyverse, arrow, countrycode, janitor)

# Import climate predictions

un_speeches <- read_parquet("data/un_speeches.parquet")

un_speeches |> 
  filter(year == 2024) |> 
  count(year)

climate_text <- read_parquet("data/un_predictions_all.parquet")

climate_text <- climate_text |> 
  mutate(
    iso_code = case_when(
      str_detect(doc_id, "^EU") ~ "EU",
      .default = iso_code
    ))

# Import speakers

un_meta <- readxl::read_excel("data/Speakers_by_session.xlsx") |>
  clean_names() |>
  select(1:6) |>
  mutate(
    country_to_remove = case_when(
      iso_code %in% c("EU", "EC") ~ TRUE,
      country == "Leage of Arab States" ~ TRUE,
      .default = FALSE
    ),
    # Fix countrycode errors, 
    iso_code = case_when(
      iso_code == "POR" ~ "PRT",
      .default = iso_code
    ),
    region = countrycode(iso_code, "iso3c", "region"),
    continent = countrycode(iso_code, "iso3c", "continent"),
    # Fix region and continent errors
    region = case_when(
      # Czeckoslovakia
      iso_code == "CSK" ~ "Europe & Central Asia",
      iso_code == "DDR" ~ "Europe & Central Asia",
      iso_code %in% c("EC", "EU") ~ "Europe & Central Asia",
      iso_code == "YUG" ~ "Europe & Central Asia",
      iso_code == "YDYE" ~ "Middle East & North Africa",
      country == "Leage of Arab States" ~ "Middle East & North Africa",
      country == "South Africa" ~ "Sub-Saharan Africa",
      iso_code == "PKR" ~ "South Asia",
      .default = region
    ),
    continent = case_when(
      # Czeckoslovakia
      iso_code == "CSK" ~ "Europe",
      iso_code == "DDR" ~ "Europe",
      iso_code %in% c("EC", "EU") ~ "Europe",
      iso_code == "YUG" ~ "Europe",
      iso_code == "YDYE" ~ "Africa",
      country == "Leage of Arab States" ~ "Asia", # ? 
      country == "South Africa" ~ "Africa",
      iso_code == "PKR" ~ "Asia",
      .default = continent
    ),
    year = as.numeric(year)
  ) |> 
  filter(year >= 1985) |> 
  mutate(doc_id = str_c(iso_code, "_", session, "_", year, ".txt"))


# Merge data

climate_text <- left_join(climate_text, un_meta)

# Group by year

speeches_climate <- climate_text |> 
  filter(
    iso_code != country_to_remove
  ) |> 
  mutate(speaker = name_of_person_speaking, 
         speaker_position = post) |> 
  group_by(doc_id, region, continent, iso_code, year,  session, speaker, speaker_position) |> 
  count(prediction) |> 
  mutate(share = n/sum(n)*100) |> 
  ungroup()

speeches_climate_meta <- speeches_climate |> 
  select(doc_id, region, continent, iso_code, year, session, speaker, speaker_position) |> 
  unique()

speeches_climate <- speeches_climate |> 
  select(doc_id, prediction, share, n) |> 
  complete(doc_id, prediction, fill = list(share = 0, n = 0)) |> 
  filter(prediction == 1) |> 
  left_join(speeches_climate_meta)

speeches_climate <- speeches_climate |> 
  select(doc_id, 
         region, 
         continent, 
         iso_code, 
         year, 
         session, 
         speaker, 
         speaker_position, 
         ecca_n = n,
         ecca_share = share) 


write_csv(speeches_climate, "data/ecca_19852024.csv")

climate_texts <- climate_text |> 
  filter(country != country_to_remove) |>
  select(
    doc_id, 
    sentence_id = id,
    year,
    country,
    iso_code,
    session,
    speaker = name_of_person_speaking,
    speaker_position = post,
    text,
    ecca_prediction = prediction,
    ecca_probability = probability
  )

write_rds(climate_texts, "data/unga_texts_with_ecca.rds")

speeches_climate |> 
  filter(!is.na(region)) |> 
  group_by(year, region) |>
  summarise(ecca_share = mean(ecca_share, na.rm = TRUE)) |>
  ggplot(aes(x = year, y = ecca_share, color = region)) +
  geom_line() +
  geom_point() +
  theme_light() +
  facet_wrap(~region)

