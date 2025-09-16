# Load necessary packages
library(dplyr)
library(pwr)

df <- read.csv("demographics.csv")

# Collapse across nudges to get total per touchpoint
agg_df <- df %>%
  group_by(touchpoint) %>%
  summarise(across(where(is.numeric), sum))

# Prepare and run chi-square tests for each demographic dimension

# Only include male and female in gender test
gender_tab_binary <- agg_df %>%
  select(Male,Female) %>%
  as.matrix()
rownames(gender_tab_binary) <- agg_df$touchpoint

# Run Chi-square test
chisq.test(gender_tab_binary)

## Age
age_tab <- agg_df %>%
  select(starts_with("Age")) %>%
  as.matrix()
rownames(age_tab) <- agg_df$touchpoint
chisq.test(age_tab)

## Education
edu_tab <- agg_df %>%
  select(starts_with("Education")) %>%
  as.matrix()
rownames(edu_tab) <- agg_df$touchpoint
chisq.test(edu_tab)

## Prior experience
exp_tab <- agg_df %>%
  select(starts_with("Prior")) %>%
  as.matrix()
rownames(exp_tab) <- agg_df$touchpoint
chisq.test(exp_tab)

# Set wd, load the data
df <- read.csv("data.csv")


# small-to-medium effect size assumption
h <- 0.30

pwr.2p.test(h = h, sig.level = 0.001, power = 0.80, alternative = "two.sided")



## DESCRIPTIVES

df %>%
  mutate(
    interaction_rate = interaction / N,
    adoption_rate = adoption / N,
    success_rate = ifelse(interaction > 0, adoption / interaction, NA_real_)
  ) %>%
  select(group, touchpoint, interaction_rate, adoption_rate, success_rate) %>%
  arrange(touchpoint, group) %>%
  mutate(across(c(interaction_rate, adoption_rate, success_rate), ~ round(.x, 3))) %>%
  as.data.frame() %>%
  print()

## PAIRWISE PROPORTION

# Pairwise proportion test for INTERACTION rate (interaction / N)
cat("=== Pairwise Proportion Tests for INTERACTION Rates ===\n")

df %>%
  group_by(touchpoint) %>%
  group_walk(~ {
    cat("\n--- Touchpoint:", .y$touchpoint, "---\n")
    cat("Nudge numbers:\n")
    print(setNames(as.character(.x$group), seq_along(.x$group)))
    print(pairwise.prop.test(x = .x$interaction, n = .x$N,
                             p.adjust.method = "bonferroni"))
  })

# Pairwise proportion test for ADOPTION rate (adoption / N)
cat("\n\n=== Pairwise Proportion Tests for ADOPTION Rates ===\n")
df %>%
  group_by(touchpoint) %>%
  group_walk(~ {
    cat("\n--- Touchpoint:", .y$touchpoint, "---\n")
    cat("Nudge numbers:\n")
    print(setNames(as.character(.x$group), seq_along(.x$group)))
    print(pairwise.prop.test(x = .x$adoption, n = .x$N,
                             p.adjust.method = "bonferroni"))
  })

# Pairwise proportion test for SUCCESS rate among INTERACTORS (adoption / interaction)
cat("\n\n=== Pairwise Proportion Tests for ADOPTION Success Among Interactors ===\n")

df %>%
  filter(interaction > 0) %>%
  mutate(non_adopted_from_interaction = interaction - adoption) %>%
  group_by(touchpoint) %>%
  group_walk(~ {
    cat("\n--- Touchpoint:", .y$touchpoint, "---\n")
    cat("Nudge numbers:\n")
    print(setNames(as.character(.x$group), seq_along(.x$group)))
    print(pairwise.prop.test(x = .x$adoption,
                             n = .x$interaction,
                             p.adjust.method = "bonferroni"))
  })



## Logistic regression

# Set factor reference levels
df$group <- relevel(factor(df$group), ref = "control")
df$touchpoint <- relevel(factor(df$touchpoint), ref = "activity")


# Remove combinations with no data (i.e., N = 0)
df <- df %>% filter(N > 0)


# Calculate success rate among interactors
df <- df %>%
  mutate(
    adoption_from_interaction = ifelse(interaction > 0, adoption / interaction, NA),
    adoption_from_interaction = round(adoption_from_interaction, 3)
  )



# Filter for interactors (used in Model 3)
df_success <- df %>% filter(interaction > 0)


# ----------------------------
# MODEL 1: Adoption ~ group * touchpoint
# ----------------------------
glm_adoption <- glm(
  cbind(adoption, N - adoption) ~ group * touchpoint,
  data = df,
  family = binomial()
)
cat("\n--- Logistic Regression: Adoption ~ group * touchpoint ---\n")

coef_adopt <- summary(glm_adoption)$coefficients
coef_adopt <- coef_adopt[complete.cases(coef_adopt), ]
printCoefmat(coef_adopt, signif.stars = TRUE)

# ----------------------------
# MODEL 2: Interaction ~ group * touchpoint
# ----------------------------
glm_interaction <- glm(
  cbind(interaction, N - interaction) ~ group * touchpoint,
  data = df,
  family = binomial()
)
cat("\n--- Logistic Regression: Interaction ~ group * touchpoint ---\n")

coef_interaction <- summary(glm_interaction)$coefficients
coef_interaction <- coef_interaction[complete.cases(coef_interaction), ]
printCoefmat(coef_interaction, signif.stars = TRUE)

# ----------------------------
# MODEL 3: Success rate among interactors ~ group * touchpoint
# ----------------------------
glm_success <- glm(
  cbind(adoption, interaction - adoption) ~ group * touchpoint,
  data = df_success,
  family = binomial()
)
cat("\n--- Logistic Regression: Success among Interactors ~ group * touchpoint ---\n")

coef_success <- summary(glm_success)$coefficients
coef_success <- coef_success[complete.cases(coef_success), ]
printCoefmat(coef_success, signif.stars = TRUE)

citation()