setwd(normalizePath(dirname(R.utils::commandArgs(asValues=TRUE)$"f")))
source("../../../scripts/h2o-r-test-setup.R")



# Test RuleFit on titanic.csv
test.rulefit.titanic <- function() {
    
    Log.info("Importing titanic.csv...\n")
    titanic = h2o.uploadFile(locate("smalldata/gbm_test/titanic.csv"))

    response = "survived"
    predictors <- c("age", "sibsp", "parch", "fare", "sex", "pclass")

    titanic[,response] <- as.factor(titanic[,response])
    titanic[,"pclass"] <- as.factor(titanic[,"pclass"])

    # Split the dataset into train and test
    splits <- h2o.splitFrame(data = titanic, ratios = .8, seed = 1234)
    train <- splits[[1]]
    test <- splits[[2]]

    rfit <- h2o.rulefit(y = response, x = predictors, training_frame = train, min_rule_length = 1, max_rule_length = 10, max_num_rules = 100, seed = 1, model_type="rules")

    print(rfit@model$rule_importance)
    expect_true(!is.null(rfit@model$model_summary))
    expect_true(length(rfit@model$model_summary) > 0)

    h2o.predict(rfit, newdata = test)

    expect_that(h2o.auc(h2o.performance(rfit)), equals(h2o.auc(h2o.performance(rfit, newdata =  train))))
    expect_that(h2o.logloss(h2o.performance(rfit)), equals(h2o.logloss(h2o.performance(rfit, newdata =  train))))

    rfit2 <- h2o.rulefit(y = response, x = predictors, training_frame = train, validation_frame = test, min_rule_length = 1, max_rule_length = 10, max_num_rules = 100, seed = 1, model_type="rules", lambda=1e-8)

    expect_true(!is.null(rfit@model$validation_metrics))
    expect_true(length(rfit@model$rule_importance$rule) < length(rfit2@model$rule_importance$rule))

    result = h2o.predict_rules(rfit, train, c("M1T0N7, M1T49N7, M1T16N7", "M1T36N7", "M2T19N19"))
    expect_true(sum(result[2]) ==  210)
    expect_true(sum(result[3]) ==  632)

    rfit <- h2o.rulefit(y = response, x = predictors, training_frame = train, min_rule_length = 1, max_rule_length = 10, max_num_rules = 100, seed = 1, model_type="rules_and_linear")
    print(rfit@model$rule_importance)
    result = h2o.predict_rules(rfit, train, c("M3T19N35", "M4T29N58", "linear.fare"))
    expect_true(sum(result["M3T19N35"]) == 497)
    expect_true(sum(result["M4T29N58"]) == 449)
    expect_true(sum(result["linear.fare"]) == h2o.nrow(train))
    
}

doTest("RuleFit Test: Titanic Data", test.rulefit.titanic)
