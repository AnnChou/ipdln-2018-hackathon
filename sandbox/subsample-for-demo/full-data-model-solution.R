# This script ... (enter functional description)

# Lines before the first chunk are invisible to Rmd/Rnw callers
# Run to stitch a tech report of this script (used only in RStudio)
# knitr::stitch_rmd(
#   script = "./manipulation/0-greeter.R",
#   output = "./manipulation/stitched-output/0-greeter.md" # make sure the folder exists
# )

rm(list=ls(all=TRUE)) #Clear the memory of variables from previous run. 
# This is not called by knitr, because it's above the first chunk.
cat("\f") # clear console when working in RStudio

# ---- load-sources ------------------------------------------------------------
# Call `base::source()` on any repo file that defines functions needed below.  
# Ideally, no real operations are performed.
base::source("./scripts/graphing/graph-logistic.R")
base::source("./scripts/graphing/graph-presets.R") # fonts, colors, themes 
# ---- load-packages -----------------------------------------------------------
# Attach these packages so their functions don't need to be qualified: http://r-pkgs.had.co.nz/namespace.html#search-path
library(ggplot2) #For graphing
library(magrittr) # Pipes
library(dplyr)
requireNamespace("dplyr", quietly=TRUE)
requireNamespace("TabularManifest") # devtools::install_github("Melinae/TabularManifest")
requireNamespace("knitr")
requireNamespace("scales") #For formating values in graphs
requireNamespace("RColorBrewer")

# ---- declare-globals ---------------------------------------------------------
# link to the source of the location mapping
path_input_micro <- "./data-unshared/derived/0-greeted.rds"
path_input_meta  <- "./data-unshared/derived/ls_guide.rds"

# test whether the file exists / the link is good
testit::assert("File does not exist", base::file.exists(path_input_micro))
testit::assert("File does not exist", base::file.exists(path_input_meta))

# declare where you will store the product of this script
# path_save <- "./data-unshared/derived/object.rds"

# See definitions of commonly  used objects in:
source("./manipulation/object-glossary.R")   # object definitions
# ---- load-data ---------------------------------------------------------------
ds0      <- readRDS(path_input_micro) #  product of `./manipulation/0-greeter.R`
ls_guide <- readRDS(path_input_meta) #  product of `./manipulation/0-metador.R`

# ---- tweak-data --------------------------------------------------------------
ds0 %>% dplyr::glimpse()

# create an explicity person identifier
ds0 <-  ds0 %>% 
  tibble::rownames_to_column("person_id") %>% 
  dplyr::mutate( person_id = as.integer(person_id)) %>% 
  dplyr::select(person_id, dplyr::everything())


# ---- inspect-data ----------------------------
ds0 %>% dplyr::glimpse(50)

# ---- define-utility-functions ---------------
# create a function to subset a dataset in this context
# because data is heavy and makes development cumbersome
get_a_subsample <- function(d, sample_size, seed = 42){
  # sample_size <- 20000
  v_sample_ids <- sample(unique(d$person_id), sample_size)
  d1 <- d %>% 
    dplyr::filter(person_id %in% v_sample_ids)
  return(d1)
}
# how to use 
# ds1 <- ds0 %>% get_a_subsample(10000)  

# define a function to print a graph onto disk as an image
# because some aspects of appearances are easier to control during printing, not graphing
quick_save <- function(g,name){
  ggplot2::ggsave(
    filename= paste0(name,".png"), 
    plot=g,
    device = png,
    path = "./reports/coloring-book-mortality/prints/1/", # female marital educ poor_healt
    # path = "./reports/coloring-book-mortality/prints/2/", # educ3 poor_health first conversational
    # path = "./reports/coloring-book-mortality/prints/3/",
    width = 1600,
    height = 1200,
    # units = "cm",
    dpi = 200,
    limitsize = FALSE
  )
}

# ---- define-graph-controls --------------------------------------------
# declare the dependent variable and define descriptive labels
dv_name            <- "S_DEAD"
dv_label_prob      <- "Alive in X years"
dv_label_odds      <- "Odds(Dead)"
# select the predictors to evaluate graphically
covar_order_values <- c("female","marital","educ3","poor_health") # rows in display matrix
# covar_order_values <- c("educ3","poor_health", "FOL","OLN") # rows in display matrix
# covar_order_values <- c("educ5","poor_health", "FOL","OLN") # rows in display matrix


# ---- transform-into-new-variables --------------------------------------
# new variables are 
ds0 %>% group_by(PR)        %>% summarize(n = n())
ds0 %>% group_by(SEX)       %>% summarize(n = n())
ds0 %>% group_by(MARST)     %>% summarize(n = n())
ds0 %>% group_by(HCDD)      %>% summarize(n = n())
ds0 %>% group_by(ADIFCLTY)  %>% summarize(n = n())
ds0 %>% group_by(DISABFL)   %>% summarize(n = n())
ds0 %>% group_by(age_group) %>% summarize(n = n())

# transform the scale of some variable (to be used in the model)
ds0 <- ds0 %>% 
  dplyr::mutate(
    # because `female` is less ambiguous then `sex`
    female = car::recode(
      SEX, "
      'Female' = 'TRUE'
      ;'Male'  = 'FALSE'
      ")
    ,female = factor(female, levels = c("FALSE","TRUE"))
    # because `still legaly married` is more legal than human
    ,marital = car::recode(
      MARST, "
      'Divorced'                              = 'sep_divorced' 
     ;'Legally married (and not separated)'   = 'mar_cohab' 
     ;'Separated, but still legally married'  = 'sep_divorced' 
     ;'Never legally married (single)'        = 'single' 
     ;'Widowed'                               = 'widowed'
    "),
    marital = factor(marital, levels = c(
      "sep_divorced","widowed","single","mar_cohab"))
    # because more than 5 categories is too fragmented
    ,educ5 = car::recode(
     HCDD, "
     'None'                                                                                                          = 'less then high school'
    ;'High school graduation certificate or equivalency certificate'                                                 = 'high school'
    ;'Other trades certificate or diploma'                                                                           = 'high school'
    ;'Registered apprenticeship certificate'                                                                         = 'high school'
    ;'College, CEGEP or other non-university certificate or diploma from a program of 3 months to less than 1 year'  = 'college'
    ;'College, CEGEP or other non-university certificate or diploma from a program of 1 year to 2 years'             = 'college'
    ;'College, CEGEP or other non-university certificate or diploma from a program of more than 2 years'             = 'college'
    ;'University certificate or diploma below bachelor level'                                                        = 'college'
    ;'Bachelors degree'                                                                                              = 'college'
    ;'University certificate or diploma above bachelor level'                                                        = 'graduate'
    ;'Degree in medicine, dentistry, veterinary medicine or optometry'                                               = 'graduate'
    ;'Masters degree'                                                                                                = 'graduate'
    ;'Earned doctorate degree'                                                                                       = 'Dr.'
    ")
    ,educ5 = factor(educ5, levels = c( 
      "less then high school"
      ,"high school"          
      ,"college"             
      ,"graduate"            
      ,"Dr."  
      ) 
    ) 
    # because even only 5 may be too granular for our purposes
    ,educ3 = car::recode(
      HCDD, "
     'None'                                                                                                          = 'less than high school'
    ;'High school graduation certificate or equivalency certificate'                                                 = 'high school'  
    ;'Other trades certificate or diploma'                                                                           = 'high school'  
    ;'Registered apprenticeship certificate'                                                                         = 'more than high school' 
    ;'College, CEGEP or other non-university certificate or diploma from a program of 3 months to less than 1 year'  = 'more than high school' 
    ;'College, CEGEP or other non-university certificate or diploma from a program of 1 year to 2 years'             = 'more than high school' 
    ;'College, CEGEP or other non-university certificate or diploma from a program of more than 2 years'             = 'more than high school' 
    ;'University certificate or diploma below bachelor level'                                                        = 'more than high school' 
    ;'Bachelors degree'                                                                                              = 'more than high school' 
    ;'University certificate or diploma above bachelor level'                                                        = 'more than high school'
    ;'Degree in medicine, dentistry, veterinary medicine or optometry'                                               = 'more than high school'
    ;'Masters degree'                                                                                                = 'more than high school'
    ;'Earned doctorate degree'                                                                                       = 'more than high school'
    ")
    ,educ3 = factor(educ3, levels = c(
       "less than high school"
      , "high school"
      , "more than high school"
      )
    )
    # ADIFCLTY               "Problems with ADL" (physical & cognitive)
    # DISABFL                "Problems with ADL" (physical & social)
   ,poor_health = ifelse(ADIFCLTY %in% c("Yes, often","Yes, sometimes")
                          &
                          DISABFL %in% c("Yes, often","Yes, sometimes"),
                          TRUE, FALSE
                          )
    ,poor_health = factor(poor_health, levels = c("TRUE","FALSE"))
    # because interval floor is easer to display on the graph then `19 to 24`
    ,age_group_low = car::recode(
      age_group, 
      "
      '19 to 24'      = '19'
      ;'25 to 29'     = '25'
      ;'30 to 34'     = '30'
      ;'35 to 39'     = '35'
      ;'40 to 44'     = '40'
      ;'45 to 49'     = '45'
      ;'50 to 54'     = '50'
      ;'55 to 59'     = '55'
      ;'60 to 64'     = '60'
      ;'65 to 69'     = '65'
      ;'70 to 74'     = '70'
      ;'75 to 79'     = '75'
      ;'80 to 84'     = '80'
      ;'85 to 89'     = '85'
      ;'90 and older' = '90'  
      "
    )
  ) %>%  
  # because easier to reference, expressed as interval's floor
  dplyr::mutate(
    age_group = age_group_low
  ) %>% 
  # because we it sorted from lowest to highest ability 
  dplyr::mutate(
    FOL = factor(FOL,levels = c(
       "Neither English nor French"
      ,"French only"
      ,"English only"
      ,"Both English and French"
      )
    )
    ,OLN = factor(FOL,levels = c(
       "Neither English nor French"
      ,"French only"
      ,"English only"
      ,"Both English and French"
      )
    )
  )

ds0 %>% glimpse(50)
# because we want/need to inspect newly created variables
ds0 %>% group_by(educ3) %>% summarize(n = n())
ds0 %>% group_by(educ5) %>% summarize(n = n())
ds0 %>% group_by(FOL) %>% summarize( n = n())

# ---- a-1 ---------------------------------------------------------------
selected_provinces <- c("Alberta","British Columbia", "Ontario", "Quebec")
sample_size = 10000

# because we want to focus on a meaningful sample
# middle aged immigrants in british columbia:
ds1 <- ds0 %>% 
  dplyr::filter(PR %in% selected_provinces) %>% 
  dplyr::filter(IMMDER   == "Immigrants") %>% 
  dplyr::filter(GENSTPOB == "1st generation - Respondent born outside Canada") #%>% 
  # get_a_subsample(sample_size) # representative sample across provinces

#create samples of the same size from each  province
dmls <- list() # dummy list (dmls) to populate during the loop
for(province_i in selected_provinces){
  # province_i = "British Columbia" # for example
  dmls[[province_i]] <-  ds1 %>%
    dplyr::filter(PR == province_i) %>% 
    get_a_subsample(sample_size) # see `define-utility-functions` chunk
}
lapply(dmls, names) # view the contents of the list object
# overwrite, making it a stratified sample across selected provinces (same size in each)
ds1 <- plyr::ldply(dmls,data.frame,.id = "PR")
ds1 %>% dplyr::glimpse(50)
ds1 %>% dplyr::group_by(PR) %>% 
  dplyr::summarise(n_people = length(unique(person_id)))

# ---- assemble ------------------------
# basic counts by province, to inspect subsample
table(ds1$PR, ds1$S_DEAD,  useNA = "ifany" ) #%>% knitr::kable()
table(ds1$PR, ds1$FOL                      ) #%>% knitr::kable()
table(ds1$PR, ds1$female,  useNA = "always") #%>% knitr::kable()
table(ds1$PR, ds1$marital, useNA = "always") #%>% knitr::kable()
table(ds1$PR, ds1$educ3,   useNA = "always") #%>% knitr::kable()
table(ds1$PR, ds1$educ5,   useNA = "always") #%>% knitr::kable()
table(ds1$PR, ds1$FOL,   useNA = "always")   #%>% knitr::kable()
table(ds1$PR, ds1$OLN,   useNA = "always")   #%>% knitr::kable()

# ---- model-specification ----------------------------------------
# because there are too many variables to keep track of, need to focus
ds2 <- ds1 %>% 
  dplyr::select_("person_id", "PR", "S_DEAD"
                 ,"age_group"
                 , "female", "marital", "educ3","poor_health", "FOL","OLN") %>%
                 # , "female", "marital", "educ5","poor_health", "FOL","OLN") %>%
  dplyr::mutate(
    poor_health = factor(poor_health)
  ) %>% 
  na.omit() %>% 
  dplyr::rename_(
    "dv" = dv_name # to ease serialization and string handling
  ) 

# ds2 %>% group_by(educ3) %>% summarize(n = n())

# define the model equation 
eq_global_string <- paste0(
  "dv ~ -1 + PR + age_group + female + marital + educ3 + poor_health + FOL"
  # "dv ~ -1 + PR + age_group + female + marital + educ3 + poor_health + FOL + OLN"
  # "dv ~ -1 + PR + age_group + female + marital + educ5 + poor_health + FOL + OLN"
)
eq_global <- as.formula(eq_global_string)

# model specification for using PROVINCE as a stratum, not a predictor in the model
eq_local_string <- paste0(
  #        + PR  (notice the absence of this term!) 
  "dv ~ -1      + age_group + female + marital + educ3 + poor_health + FOL + OLN"
  # "dv ~ -1      + age_group + female + marital + educ5 + poor_health + FOL + OLN"
)
eq_local <- as.formula(eq_local_string)

# ---- estimate-global-solutions ---------------------------------
# this solution enters PR as one of the predictors


model_global <- glm(
  eq_global,
  data   = ds2, 
  family = binomial(link="logit")
) 
summary(model_global)
coefs <- coefficients(model_global)
# ds2$dv_p <- predict(model_global) # fast check
saveRDS(coefficients(model_global),"./reports/model-solution.rds")

# now we will use this model solution to generate fictional data
coefs



# create levels of the predictors for which we will generate predictions using model solution
ds_predicted_global <- ds2 %>% 
  dplyr::select_(
    "PR",
    "age_group", 
    "female",        
    "educ3",
    # "educ5",       
    "marital" ,
    "poor_health", 
    "FOL",
    "OLN"
  ) %>% 
  dplyr::distinct()

# compute predicted values of the criterion based on model solution and levels of predictors
#logged-odds of probability (ie, linear)
ds_predicted_global$dv_hat    <- as.numeric(predict(model_global, newdata=ds_predicted_global)) 
#probability (ie, s-curve)
ds_predicted_global$dv_hat_p  <- plogis(ds_predicted_global$dv_hat) 




