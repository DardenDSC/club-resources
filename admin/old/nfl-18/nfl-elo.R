library(dplyr)
library(ggplot2)
library(Matrix)
#install.packages("lubridate")
library(lubridate)
#install.packages("rpart")
library(rpart)
#install.packages("rpart.plot")
library(rpart.plot)
#install.packages("randomForest")
library(randomForest)
#install.packages("xgboost")
library(xgboost)
#install.packages("Ckmeans.1d.dp")
library(Ckmeans.1d.dp)
#install.packages("forecast")
library(forecast)
#install.packages("ROCR")
library(ROCR)

# Download the data into a data frame
df.nfl <- read.csv("https://projects.fivethirtyeight.com/nfl-api/nfl_elo.csv")

### DATA CLEANING AND EXPLORATION ###
str(df.nfl)
summary(df.nfl)
head(df.nfl)
tail(df.nfl)

# The date factor isn't ideal, so we'll change that into a date format using the Lubridate package
# Notice the use of "pipe" notation here from dplyr package. Basically, a %>% f(b) is notation for f(a, b).
df.nfl <- df.nfl %>% mutate(date = ymd(date))

# Remove the rows for games that haven't been played yet
df.nfl <- df.nfl %>% filter(!is.na(score1))

# How many teams do we have?
df.nfl$team1 %>% union(df.nfl$team2) %>% unique() %>% length() # 123
df.nfl %>% select(season, team1) %>% distinct() %>% group_by(season) %>% summarise(teams = length(team1)) %>% 
  ggplot(aes(season, teams)) + geom_area() + ggtitle("Number of Teams by Season")

# Have there been scoring trends over time for the winning team?
df.nfl %>% mutate(winning_score = pmax(score1, score2), losing_score = pmin(score1, score2)) %>% group_by(season) %>% 
  summarise(avg_win_score = mean(winning_score), avg_lose_score = mean(losing_score)) %>%
  ggplot(aes(season)) + geom_line(aes(y = avg_win_score), color = "green") + geom_line(aes(y = avg_lose_score), color = "red") +
  ggtitle("Average Winning and Losing Scores by Season") + labs(y = "score")

# Are their forecasts calibrated?
df.nfl %>% group_by(forecast_bin = cut(elo_prob1, breaks = seq(0, 1, by = .05))) %>% 
  summarise(win_rate = sum(score1 > score2)/n(), frequency = n()) %>% 
  ggplot(aes(x = forecast_bin, y = win_rate)) + geom_point(aes(size = frequency, color = frequency)) + 
  geom_abline(aes(slope = 1/18, intercept = -1/19)) + ggtitle("Calibration Plot, 538's Forecasts")
# Yeah, their forecasts are pretty well calibrated, but they're a little overconfident, 
# meaning they may want to hedge all their forecasts slightly towards .5.
# When they say team1 has a 27.5% chance, it should really be more like 32.5% and
# when they say team1 has a 72.5% chance, it should really be more like 70.0%.

# Are they discriminating between wins and losses?
df.nfl %>% group_by(forecast_bin = cut(elo_prob1, breaks = seq(0, 1, by = .05)), win = score1 > score2) %>% 
  summarise(frequency = n()) %>% ggplot(aes(x = forecast_bin, y = frequency, color = win)) + geom_point(size = 3) +
  ggtitle("Discrimination Plot, 538's Forecasts")
# This is saying that in cases where the home team won, they generally gave it a high probability, 
# but in cases where the home team lost, they didn't necessarily see it coming.

# What is the area under the curve for their model?
pr <- prediction(df.nfl$elo_prob1, df.nfl$score1 > df.nfl$score2)
prf <- performance(pr, measure = "tpr", x.measure = "fpr")
# Area under the curve is a great measure of model value
plot(prf)
abline(a=0, b= 1)
auc <- performance(pr, measure = "auc")
auc.538 <- auc@y.values[[1]]
auc.538 # Area under our false positive rate vs true positive rate curve

### FEATURE ENGINEERING ###
# Lets add some useful columns
df.nfl <- df.nfl %>% 
  mutate(team1win = score1 > score2) %>% 
  mutate(tie = score1 == score2) %>% 
  mutate(elo_prob1_calc = 1/(10^(-(elo1_pre - elo2_pre)/400)+1)) %>%
  mutate(point_spread1 = (elo1_pre - elo2_pre)/25) %>%
  mutate(date = ymd(date)) %>%
  mutate(year = year(date)) %>%
  mutate(month = month(date)) %>%
  mutate(day = day(date)) %>%
  mutate(wday = wday(date, label = TRUE))
# What if you included information on 
#  when the two teams last played one another?
#  how recently was their last game?
#  how many days into the season are we?
#  are ELO scores more accurate later into the season?

# Our calculation of the win probability is based only on pre-elo's, without considering home field advantage
ggplot(df.nfl, aes(elo_prob1_calc, elo_prob1)) + geom_point(aes(color = factor(neutral)), alpha = 1/2)
df.nfl <- df.nfl %>% rename(elo_prob1_neutral = elo_prob1_calc)

# Final check before moving on
str(df.nfl)
summary(df.nfl)

### MODEL CREATION ###
# Split the data into testing and training sets
set.seed(1234)
n.train <- (df.nfl %>% nrow() * .75) %>% floor()
vec.rows.train <- sample(1:nrow(df.nfl), size = n.train, replace = FALSE)
df.train <- df.nfl[vec.rows.train,]
df.test <- df.nfl[-vec.rows.train,]
nrow(df.train)
nrow(df.test)

# Which columns will we want to use in creating our models?
col.exclude <- c("date",
                 "team1",
                 "team2",
                 "elo_prob1",
                 "elo_prob2",
                 "point_spread1",
                 "elo1_post",
                 "elo2_post",
                 "score1",
                 "score2",
                 "tie",
                 "year")
col.include <- setdiff(colnames(df.nfl), col.exclude)

# Logistic Regression
lr.model <- glm(team1win ~ . + playoff:elo1_pre, family = "binomial", data = df.train[,col.include])
summary(lr.model)
# Backwards stepwise to eliminate variables
lr.model.step <- step(lr.model, direction = "backward", trace = 0)
summary(lr.model.step)
lr.model.step %>% anova(test = "Chisq")

# Regression Tree
rt.model <- rpart(team1win ~ ., data = df.train[,col.include])
prp(rt.model, type = 1, extra = 1)
rt.model.tuned <- rpart(team1win ~ ., data = df.train[,col.include], control = rpart.control(cp = 0.001))
prp(rt.model.tuned, type = 1, extra = 1)

# Random Forest
set.seed(1234)
ntree = 200
nodesize = 10
rf.model <- randomForest(formula = team1win ~ ., data = df.train[,col.include], ntree = ntree, nodesize = nodesize)
rf.model
plot(rf.model)
# Now we'll tune the random forest by optimizing the mtry variable (discovered this online). Mtry is number of variables randomly chosen at each split.
# This takes about 3 minutes
mtry.min = 1
mtry.max = 10
oob.err=double(mtry.max)
test.err=double(mtry.max)
# This loop takes about 3 minutes
for(mtry in mtry.min:mtry.max) 
{
  rf = randomForest(team1win ~ . , data = df.train[,col.include], mtry=mtry, ntree = ntree, nodesize = nodesize) 
  oob.err[mtry] = rf$mse[ntree] # Error of all Trees fitted
  pred <- predict(rf, df.test[,col.include]) # Predictions on Test Set for each Tree
  test.err[mtry] = with(df.test, mean( (df.test$team1win - pred)^2)) # Mean Squared Test Error
  cat(mtry," ") # Printing the output to the console
}
matplot(mtry.min:mtry.max, cbind(oob.err, test.err)[c(mtry.min:mtry.max),], pch=19 , col=c("red","blue"),
        type="b", ylab="Mean Squared Error", xlab="Number of Predictors Considered at each Split")
legend("bottomright", legend=c("Out of Bag Error", "Test Error"), pch=19, col=c("red","blue"))
mtry.best <- which.min(oob.err[mtry.min:mtry.max]) + mtry.min - 1
rf.model.tuned <- randomForest(formula = team1win ~ ., data = df.train[,col.include], ntree = ntree, 
                               mtry = mtry.best, nodesize = nodesize, 
                               replace = TRUE, importance = TRUE)
rf.importance <- importance(rf.model.tuned)
# Which variables were most important in reducing mean squared error?
round(rf.importance[order(rf.importance[,1], decreasing = TRUE),], 2)

# Boosted Tree
sparse_matrix <- sparse.model.matrix(team1win ~ ., data = df.nfl[,col.include])
dim(sparse_matrix)
colnames(sparse_matrix)
dtrain <- xgb.DMatrix(sparse_matrix[vec.rows.train,], label = df.train$team1win)
dtest <- xgb.DMatrix(sparse_matrix[-vec.rows.train,], label = df.test$team1win)
param <- list(max_depth = 3, eta = 1, verbose = 1, print_every_n = 20, 
              nthread = 8, colsample_bytree = .3, objective = "binary:logistic", 
              num_parallel_tree = 5, subsample = .5, min_child_weight = 10)
watchlist <- list(train = dtrain, eval = dtest)
set.seed(1234)
bt.model <- xgb.train(params = param, data = dtrain, nrounds = 300, 
                      watchlist = watchlist,
                      weight = df.train$last_evaluation,
                      early_stopping_rounds = 30)
xgb.ggplot.importance(importance_matrix = xgb.importance(model = bt.model))

### CROSS VALIDATION ###
# A helpful accuracy function
fun.acc <- function(vec.pred, vec.actual, n.threshold = .5){
  vec.decision <- ifelse(vec.pred > n.threshold, 1, 0)
  vec.misclas.error <- mean(vec.decision != vec.actual)
  print(paste('Accuracy',1 - vec.misclas.error))
}

# Logistic Regression
lr.pred <- predict(lr.model, newdata = df.test, type = 'response')
lr.step.pred <- predict(lr.model.step, newdata = df.test, type = 'response')
fun.acc(vec.pred = lr.pred, vec.actual = df.test$team1win)
fun.acc(vec.pred = lr.step.pred, vec.actual = df.test$team1win)

# Regression Tree
rt.pred <- predict(rt.model, df.test)
rt.tuned.pred <- predict(rt.model.tuned, df.test)
accuracy(rt.pred, df.test$team1win)
fun.acc(rt.pred, df.test$team1win)
accuracy(rt.tuned.pred, df.test$team1win)
fun.acc(rt.tuned.pred, df.test$team1win)

# Random Forest 
rf.pred <- predict(rf.model, df.test)
accuracy(rf.pred, df.test$team1win)
fun.acc(rf.pred, df.test$team1win)
rf.tuned.pred <- predict(rf.model.tuned, df.test)
accuracy(rf.tuned.pred, df.test$team1win)
fun.acc(rf.tuned.pred, df.test$team1win)

# Boosted Tree
bt.pred <- predict(bt.model, sparse_matrix[-vec.rows.train,])
accuracy(bt.pred, df.test$team1win)
fun.acc(bt.pred, df.test$team1win)

# An Averaged Ensemble
en.pred <- rowMeans(cbind(lr.pred, rt.tuned.pred, rf.tuned.pred, bt.pred))
accuracy(en.pred, df.test$team1win)
fun.acc(en.pred, df.test$team1win)
en.pred2 <- rowMeans(cbind(rf.tuned.pred, bt.pred))
accuracy(en.pred2, df.test$team1win)
fun.acc(en.pred2, df.test$team1win)

### ANALYSIS ON OUR BEST MODEL ###
pr <- prediction(lr.step.pred, df.test$team1win)
prf <- performance(pr, measure = "tpr", x.measure = "fpr")

# Area under the curve is a great measure of model value
plot(prf)
abline(a=0, b= 1)
auc <- performance(pr, measure = "auc")
auc <- auc@y.values[[1]]
auc # Area under our false positive rate vs true positive rate curve
# Did we improve on the 538 game predictions?
auc.538
auc > auc.538

# What's the best point (threshold) to say "I'm guessing team 1 will win"?
prf.acc <- performance(pr, measure = "acc")
plot(prf.acc)
ind = which.max( slot(prf.acc, "y.values")[[1]] )
acc = slot(prf.acc, "y.values")[[1]][ind]
cutoff = slot(prf.acc, "x.values")[[1]][ind]
print(c(accuracy= acc, cutoff = cutoff))

# Are our forecasts calibrated?
data.frame(pred = lr.step.pred, result = df.test$team1win) %>% 
  group_by(forecast_bin = cut(pred, breaks = seq(0, 1, by = .05))) %>% 
  summarise(win_rate = sum(result)/n(), frequency = n()) %>% 
  ggplot(aes(x = forecast_bin, y = win_rate)) + geom_point(aes(size = frequency, color = frequency)) + 
  geom_abline(aes(slope = 1/18, intercept = -1/19)) + ggtitle("Calibration Plot, Our Forecasts")

# Are we discriminating between wins and losses?
data.frame(pred = lr.step.pred, result = df.test$team1win) %>% 
  group_by(forecast_bin = cut(pred, breaks = seq(0, 1, by = .05)), result) %>% 
  summarise(frequency = n()) %>% ggplot(aes(x = forecast_bin, y = frequency, color = result)) + geom_point(size = 3) +
  ggtitle("Discrimination Plot, Our Forecasts")