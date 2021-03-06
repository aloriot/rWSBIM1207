library("curatedTCGAData")
library("MultiAssayExperiment")
library("dplyr")
library("tidyr")

## Select RNAseq data of LUAD samples from TCGA
LUAD <- curatedTCGAData("LUAD", "RNA*", FALSE)

## Extract clinical data from the csv file, selecting only interesting variables
clinical <- colData(LUAD)[, c(1, 6, 11, 50, 3:5, 7:10, 12, 17, 18, 477, 482)]

## rename certain columns in a more comprehensive manner
clinical$age_at_diagnosis <- abs(clinical$patient.days_to_birth)
clinical$smoking_history <- clinical$patient.tobacco_smoking_history
clinical$stopped_smoking_year <- clinical$patient.stopped_smoking_year
## reorder and select columns of interest
clinical1 <- clinical[ , c(1:3, 17, 5:11, 18, 13:14, 19)]
clinical1 <- as_tibble(clinical1)

## save the clinical data
write.csv(clinical1, "../extdata/clinical1.csv", row.names = FALSE)
save(clinical1, file = "../../data/clinical1.rda")

## create the "clinial_table_ex1" object
clinical_table_ex1 <- clinical1 %>%
    select(patientID, gender, age_at_diagnosis, pathologic_stage, vital_status, smoking_history) %>%
    filter(smoking_history == 'current smoker' | smoking_history == 'lifelong non-smoker') %>%
    group_by(smoking_history, gender) %>%
    summarize(n = n()) %>%
    spread(key = smoking_history, value = n)

save(clinical_table_ex1, file = "../../data/clinical_table_ex1.rda")

clinical2 <- clinical1 %>%
  select(patientID, gender, age_at_diagnosis) %>%
  mutate(years_at_diagnosis = age_at_diagnosis / 365) %>%
  select(patientID, gender, years_at_diagnosis)
save(clinical2, file = "../../data/clinical2.rda")

## RNAseq data
RNAseq_full <- assay(LUAD[[1]])

## Reduce the ref (the way it is usually found in TCGA data)
colnames(RNAseq_full) <- substr(colnames(RNAseq_full), 1, 16)

## keep only 10 first genes to reduce the data size and only primary tumors and
## normal matching tissues to simplify
RNAseq <- as_tibble(RNAseq_full[1:10,]) %>%
  mutate(Gene = c(rownames(RNAseq_full)[1:10])) %>%
    select(Gene, ends_with('-01A'), ends_with('-11A'))


expression <- t(RNAseq %>% select(-Gene)) # transpose the data
expression <- data.frame(sampleID = rownames(expression), expression)
colnames(expression) <- c("sampleID", RNAseq$Gene)
## The 3 last characters of the sampleID indicate the type of sample:
## - Samples ending with '-01A' (TCGA-XX-XXXX-01A) correspond to tumors
## - Samples ending with '-11A' (TCGA-XX-XXXX-11A) correspond to normal
## - peritumoral tissues
## Create a column called "type" indicating if samples correspond to tumor or
## normal tissues.
## Add a column patient corresponding to the patient reference (TCGA-XX-XXXX),
## corresponding to the first characters of sampleID
expression <- as_tibble(expression) %>%
  mutate(type = case_when(substr(sampleID,14,16) =="01A" ~ "tumor",
                          substr(sampleID,14,16) =="11A" ~ "normal")) %>%
  mutate(patient = substr(sampleID,1,12)) %>%
  select(sampleID, patient, type, RNAseq$Gene[1:5])

save(expression, file = "../../data/expression.rda")
write.csv(expression, "../extdata/expression.csv", row.names = FALSE)
