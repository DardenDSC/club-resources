
library(tidyverse)


# 1 student test score example -----------------------------------------------

gmat_max_score <- 800
gmat_min_score <- 600
darden_avg_score <- 710
natl_avg_score <- 700
natl_std_score <- 25

potential_scores <- seq(gmat_min_score, gmat_max_score, 1)
prob_density <- dnorm(potential_scores, natl_avg_score, natl_std_score)

chart_xs <- seq(gmat_min_score, gmat_max_score, 0.01)   
ytop <- dnorm(darden_avg_score, natl_avg_score, natl_std_score)

chart_df <- data.frame(x = chart_xs, 
                       y = dnorm(chart_xs, natl_avg_score, natl_std_score))

shade <- rbind(c(darden_avg_score, 0), 
               subset(chart_df, x > darden_avg_score), 
               c(chart_df[nrow(chart_df), "x"], 0))

qplot(x = x, y = y, data = chart_df, geom = "line") +
  geom_segment(aes(x = darden_avg_score, y = 0, xend = darden_avg_score, yend = ytop)) +
  geom_polygon(data = shade, mapping = aes(x = x, y = y, fill="red")) + 
  annotate("text", x = 770, y = .006, 
           label = "Pr(GMAT >= 710) \n = 42%") + 
  scale_fill_discrete(guide = FALSE) + 
  labs(title = "Last Year's GMAT Distribution", 
       subtitle = "Includes One Randomly Selected 2020 Darden Student with GMAT = 710", 
       x = "GMAT Score", 
       y = "Density") + 
  theme_bw()


# 25 student test score example -----------------------------------------------

gmat_max_score <- 4
gmat_min_score <- -4
darden_avg_score <- 2
natl_avg_score <- 0
natl_std_score <- 1

potential_scores <- seq(gmat_min_score, gmat_max_score, .01)
prob_density <- dnorm(potential_scores, natl_avg_score, natl_std_score)

chart_xs <- seq(gmat_min_score, gmat_max_score, 0.01)   
ytop <- dnorm(darden_avg_score, natl_avg_score, natl_std_score)

chart_df <- data.frame(x = chart_xs, 
                       y = dnorm(chart_xs, natl_avg_score, natl_std_score))

shade <- rbind(c(darden_avg_score, 0), 
               subset(chart_df, x > darden_avg_score), 
               c(chart_df[nrow(chart_df), "x"], 0))


qplot(x = x, y = y, data = chart_df, geom = "line") +
  geom_segment(aes(x = darden_avg_score, y = 0, xend = darden_avg_score, yend = ytop)) +
  geom_polygon(data = shade, mapping = aes(x = x, y = y, fill="red")) + 
  annotate("text", x = 3.1, y = .07, 
           label = "italic(p) == .023", parse = TRUE) + 
  scale_fill_discrete(labels = c("P-VALUE!!"),
                      guide = guide_legend(title = NULL,
                                           label.position = "top")) +
  labs(title = "Z-Statistic Distribution", 
       subtitle = "Test Result of 25 Students w/ Avg GMAT = 710", 
       x = "Z-Score", 
       y = "Density") + 
  theme_bw()


# two sample test score example ------------------------------------------------

grp1 <- rnorm(1000, 700, 15)
grp2 <- rnorm(1000, 710, 10)
chart_df <- tibble(group = rep(c('Class of 2019', 'Class of 2020'), each=1000), 
                   score = c(grp1, grp2))
ggplot(chart_df, aes(x = score, fill = group)) +
  #geom_histogram(alpha = 0.4, position = "identity", bins=40) + 
  geom_density(alpha = 0.2, adjust = 2) + 
  scale_fill_discrete(guide = guide_legend(title = "Class Year")) + 
  labs(title = "GMAT Score Distributions", 
       subtitle = "Segmented by Class Year", 
       x = "GMAT Score", 
       y = "Density") + 
  theme_bw()

# formulas for Student's T-Test (unequal variances)
# https://en.wikipedia.org/wiki/Student's_t-test#Independent_two-sample_t-test
t_stat <- (710-700) / (sqrt((10^2 + 15^2)/2) * sqrt(2/25))
t_stat_df <- (2*25) - 2

gmat_max_score <- 4
gmat_min_score <- -4
darden_avg_score <- t_stat
natl_avg_score <- 0
natl_std_score <- 1

potential_scores <- seq(gmat_min_score, gmat_max_score, .01)
prob_density <- dt(potential_scores, t_stat_df)

chart_xs <- seq(gmat_min_score, gmat_max_score, 0.01)   
ytop <- dt(t_stat, t_stat_df)

chart_df <- data.frame(x = chart_xs, 
                       y = dt(chart_xs, t_stat_df))

shade <- rbind(c(darden_avg_score, 0), 
               subset(chart_df, x > darden_avg_score), 
               c(chart_df[nrow(chart_df), "x"], 0))

# the p-value
1 - pt(t_stat, t_stat_df)

qplot(x = x, y = y, data = chart_df, geom = "line") +
  geom_segment(aes(x = darden_avg_score, y = 0, xend = darden_avg_score, yend = ytop)) +
  geom_polygon(data = shade, mapping = aes(x = x, y = y, fill="red")) + 
  annotate("text", x = 3.4, y = .06, 
           label = "italic(p) == .004", parse = TRUE) + 
  scale_fill_discrete(labels = c("P-VALUE!!"),
                      guide = guide_legend(title = NULL,
                                           label.position = "top")) +
  labs(title = "T-Statistic Distribution", 
       subtitle = "The Difference Between Two Groups of 25 Students", 
       x = "T-Score",
       y = "Density") + 
  theme_bw()


# chi-square test example ------------------------------------------------------

chi_test <- chisq.test(x=matrix(c(39, 11, 27, 23), 2, 2, byrow=TRUE))
potential_scores <- seq(0, 8, .01)
prob_density <- dchisq(potential_scores, chi_test$parameter["df"])

chart_xs <- seq(0, 8, .01)
ytop <- dchisq(chi_test$statistic, chi_test$parameter["df"])

chart_df <- data.frame(x = chart_xs, 
                       y = dchisq(chart_xs, chi_test$parameter["df"]))

shade <- rbind(c(chi_test$statistic, 0), 
               subset(chart_df, x > chi_test$statistic), 
               c(chart_df[nrow(chart_df), "x"], 0))

# the p-value
chi_test$p.value

qplot(x = x, y = y, data = chart_df, geom = "line") +
  geom_segment(aes(x = chi_test$statistic, y = 0, xend = chi_test$statistic, yend = ytop)) +
  geom_polygon(data = shade, mapping = aes(x = x, y = y, fill="red")) +
  scale_y_continuous(limits = c(0,1)) + 
  annotate("text", x = 6.7, y = .1, 
           label = "italic(p) == .02", parse = TRUE) + 
  annotate("text", x = 6.7, y = .2, 
           label = "chi^2 == 5.4", parse = TRUE) + 
  scale_fill_discrete(labels = c("P-VALUE!!"),
                      guide = guide_legend(title = NULL,
                                           label.position = "top")) +
  labs(title = expression(paste(chi^2, "-Statistic Distribution")), 
       subtitle = "Testing Relationship Between Smoking and Cancer", 
       x = expression(paste(chi^2, "-Score")),
       y = "Density") + 
  theme_bw()


# regression example -----------------------------------------------------------

reg_dat <- mtcars
reg_dat$wt <- reg_dat$wt*1000
reg <- lm(mpg~wt, data=reg_dat)
fitted <- fitted(reg)
ggplot(reg_dat, aes(x=wt, y=mpg)) + 
  scale_y_continuous(limits = c(5, 35)) + 
  geom_point() + 
  labs(title = "Relationship between Car Weight and MPG", 
       x = "Weight (in lbs)",
       y = "Miles per Gallon (MPG)") + 
  theme_bw()

ggplot(reg_dat, aes(x=wt, y=mpg)) + 
  scale_y_continuous(limits = c(5, 35)) + 
  geom_point(color="red") + 
  geom_smooth(se=FALSE, method = "lm") +
  geom_segment(aes(x = wt, y = mpg,
                   xend = wt, yend = fitted)) +
  labs(title = "Relationship between Car Weight and MPG", 
       x = "Weight (in lbs)",
       y = "Miles per Gallon (MPG)") + 
  theme_bw()

summary(reg)

resid_df <- tibble(wt = reg_dat$wt, 
                   resid = residuals(reg))
ggplot(resid_df, aes(x=wt, y=resid)) + 
  geom_point() + 
  stat_smooth(se=FALSE, method = "lm", formula = y ~ x + I(x^2)) + 
  geom_hline(yintercept = 0, color="red") + 
  labs(title = "Examining Regression Model Errors", 
       x = "Weight (in lbs)",
       y = "Size of Error") + 
  theme_bw()
