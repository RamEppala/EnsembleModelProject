library('caret')
set.seed(1)
setwd("C:/EnsemblemodelProject")
data<-read.csv("train_data.csv")
data
str(data)
#check missing data
sum(is.na(data))
#Imputing missing values using median
preProcValues<-preProcess(data,method = c("medianImpute","center","scale"))
library('RANN')
data_processed<-predict(preProcValues,data)
sum(is.na(data_processed))
#Spliting training set into two parts based on outcome: 75% and 25%
index<-createDataPartition(data_processed$Loan_Status,p=0.75,list = FALSE)
trainSet<-data_processed[index,]
testSet<-data_processed[-index,]
#Defining the training controls for multiple models
fitcontrol<-trainControl(method = "cv",number = 5,savePredictions = 'final',classProbs = T)
#Defining the predictors and outcome
predictors<-c("Credit_History", "LoanAmount", "Loan_Amount_Term", "ApplicantIncome",
              "CoapplicantIncome")
outcomeName<-'Loan_Status'
#Training the random forest model
model_rf<-train(trainSet[,predictors],trainSet[,outcomeName],method='rf',trControl=fitcontrol,tuneLength=3)
#Predicting using random forest model
testSet$pred_rf<-predict(object = model_rf,testSet[,predictors])
#Checking the accuracy of the random forest model
confusionMatrix(testSet$Loan_Status,testSet$pred_rf)
#Training the knn model
model_knn<-train(trainSet[,predictors],trainSet[,outcomeName],method='knn',trControl=fitcontrol,tuneLength=3)
#Predicting using knn model
testSet$pred_knn<-predict(object = model_knn,testSet[,predictors])
#Checking the accuracy of the random forest model
confusionMatrix(testSet$Loan_Status,testSet$pred_knn)
#Training the Logistic regression model
model_lr<-train(trainSet[,predictors],testSet[,outcomeName],method='glm',trControl=fitcontrol,tuneLength=3)
#Predicting using LR model
testSet$pred_lr<-predict(object = model_lr,testSet[,predictors])
#Checking the accuracy of the LR model
confusionMatrix(testSet$Loan_Status,testSet$pred_lr)
#forming an ensemble(Averaging) with these models
#Predicting the probabilities
testSet$pred_rf_prob<-predict(object = model_rf,testSet[,predictors],type='prob')
testSet$pred_knn_prob<-predict(object=model_knn,testSet[,predictors],type='prob')
testSet$pred_lr_prob<-predict(obect=model_lr,testSet[,predictors],type='prob')
#Taking average of predictions
testSet$pred_avg<-(testSet$pred_rf_prob$Y+testSet$pred_knn_prob$Y+testSet$pred_lr_prob$Y)/3
#Splitting into binary classes at 0.5
testSet$pred_avg<-as.factor(ifelse(testSet$pred_avg>0.5,'Y','N'))
#The majority vote
testSet$pred_majority<-as.factor(ifelse(testSet$pred_rf=='Y' & testSet$pred_knn=='Y','Y',ifelse(testSet$pred_rf=='Y' & testSet$pred_lr=='Y','Y',ifelse(testSet$pred_knn=='Y' & testSet$pred_lr=='Y','Y','N'))))
#Taking weighted average of predictions
testSet$pred_weighted_avg<-(testSet$pred_rf_prob$Y*0.25)+(testSet$pred_knn_prob$Y*0.25)+(testSet$pred_lr_prob$Y*0.5)
#Splitting into binary classes at 0.5
testSet$pred_weighted_avg<-as.factor(ifelse(testSet$pred_weighted_avg>0.5,'Y','N'))
#Train the individual base layer models on training data
#Defining the training control
fitcontrol<-trainControl(method="cv",number=10,savePredictions='final',classProbs=T)
fitcontrol
#Defining the predictors and outcome
predictors<-c("Credit_History", "LoanAmount", "Loan_Amount_Term", "ApplicantIncome",
              "CoapplicantIncome")
outcomeName<-'Loan_Status'
#Training the random forest model
model_rf<-train(trainSet[,predictors],trainset[,outcomeName],method='rf',trControl=fitControl,tuneLength=3)
model_rf
#Training the knn model
model_knn<-train(trainSet[,predictors],trainSet[,outcomeName],method='knn',trControl=fitControl,tuneLength=3)
model_knn
#Training the logistic regression model
model_lr<-train(trainSet[,predictors],trainSet[,outcomeName],method='glm',trControl=fitControl,tuneLength=3)
model_lr
#Predict using each base layer model for training data and test data
#Predicting the out of fold prediction probabilities for training data
trainSet$OOF_pred_rf<-model_rf$pred$Y[order(model_rf$pred$rowIndex)]
trainSet$OOF_pred_knn<-model_knn$pred$Y[order(model_knn$pred$rowIndex)]
trainSet$OOF_pred_lr<-model_lr$pred$Y[order(model_lr$pred$rowIndex)]
#Predicting probabilities for the test data
testSet$OOF_pred_rf<-predict(model_rf,testSet[predictors],type='prob')$Y
testSet$OOF_pred_knn<-predict(model_knn,testSet[predictors],type='prob')$Y
testSet$OOF_pred_lr<-predict(model_lr,testSet[predictors],type='prob')$Y
#Now train the top layer model again on the predictions of the bottom layer models that has been made on the training data
#let’s start with the GBM model as the top layer model.
#Predictors for top layer models 
predictors_top<-c('OOF_pred_rf','OOF_pred_knn','OOF_pred_lr')
#GBM as top layer model 
model_gbm<-train(train(trainSet[,predictors_top],trainSet[,outcomeName],method='gbm',trControl=fitControl,tuneLength=3))

model_gbm
#Similarly, we can create an ensemble with logistic regression as the top layer model as well.
#Logistic regression as top layer model
model_glm<-train(trainSet[,predictors_top],trainSet[,outcomeName],method='glm',trControl=fitControl,tuneLength=3)
#Step 4: Finally, predict using the top layer model with the predictions of bottom layer models that has been made for testing data
#predict using GBM top layer model
testSet$gbm_stacked<-predict(model_gbm,testSet[,predictors_top])

#predict using logictic regression top layer model
testSet$glm_stacked<-predict(model_glm,testSet[,predictors_top])


